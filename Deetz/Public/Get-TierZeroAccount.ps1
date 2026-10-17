# .ExternalHelp Deetz-help.xml
function Get-TierZeroAccount {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $false
		)]
		[string]$Domain,

		[Parameter(
			Mandatory = $false
		)]
		[pscredential]$Credential,

		[Parameter(
			Mandatory = $false
		)]
		[string[]]$AdditionalGroup,

		[Parameter(
			Mandatory = $false
		)]
		[switch]$SkipAclAnalysis
	)

	$Script:DeetzSession.Credential = $Credential
	$Script:DeetzSession.Cache = @{}

	$Forest = Get-ForestInfo -Domain $Domain
	$TargetDomain = $Forest.Domain.DNSRoot

	$Registry = [ordered]@{}
	$Groups = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)

	$AddGroup = {
		param($Group, $Source, $Grant)

		$TierZeroGroup = $Group.'msDS-PrincipalName'
		$null = $Groups.Add($Group.DistinguishedName)
		Write-Verbose "Checking Group: $TierZeroGroup"

		foreach ($Item in (Expand-GroupMember -Group $Group -Path $TierZeroGroup -Forest $Forest)) {

			if ($Item.Object.ObjectClass -eq 'group') {
				$null = $Groups.Add($Item.Object.DistinguishedName)
			} else {
				Register-TierZeroAccount -Registry $Registry -Object $Item.Object -Source $Source -TierZeroGroup $TierZeroGroup -Path $Item.Path @Grant
			}

		}

	}

	#Default Tier Zero groups
	foreach ($Seed in (Get-TierZeroGroupSeed -Forest $Forest)) {

		$Group = Get-DirectoryObject -LDAPFilter "(objectSid=$($Seed.SID))" -Server $Seed.Server | Select-Object -First 1

		if (-not $Group) {
			Write-Verbose "Group $($Seed.SID) not found in $($Seed.Server)"
			continue
		}

		& $AddGroup $Group GroupMembership @{}

	}

	#Groups named by the caller
	$GroupParameter = @{ Server = $TargetDomain } + (Get-CredentialParameter)

	foreach ($Name in $AdditionalGroup) {

		try {
			$ADGroup = Get-ADGroup -Identity $Name @GroupParameter -ErrorAction Stop
		} catch {
			Write-Warning "Unable to find group $Name`: $($PSItem.Exception.Message)"
			continue
		}

		$Group = Get-DirectoryObject -Identity $ADGroup.DistinguishedName | Select-Object -First 1

		if ($Group) {
			& $AddGroup $Group GroupMembership @{}
		}

	}

	#Built-in Administrator, krbtgt and read-only domain controller accounts
	foreach ($Filter in @(
			"(objectSid=$($Forest.Domain.DomainSID)-500)",
			'(&(objectClass=user)(sAMAccountName=krbtgt*))',
			'(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))'
		)) {

		foreach ($Account in (Get-DirectoryObject -LDAPFilter $Filter -Server $TargetDomain)) {
			Register-TierZeroAccount -Registry $Registry -Object $Account -Source WellKnownAccount
		}

	}

	if (-not $SkipAclAnalysis) {

		$AddPrincipal = {
			param($Principal, $Source, $Grant)

			if (-not $Principal -or $Groups.Contains($Principal.DistinguishedName)) {
				return
			}

			if ($Principal.ObjectClass -eq 'group') {
				& $AddGroup $Principal $Source $Grant
			} else {
				Register-TierZeroAccount -Registry $Registry -Object $Principal -Source $Source @Grant
			}

		}

		$CheckAcl = {
			param($Target, $Source)

			Write-Verbose "Checking ACL: $Target"

			$TargetObject = Get-DirectoryObject -Identity $Target -Properties nTSecurityDescriptor, managedBy, userAccountControl | Select-Object -First 1

			#The managedBy principal of a read-only domain controller is a local administrator of it
			if ($TargetObject.managedBy -and ($TargetObject.userAccountControl -band 67108864)) {
				$Manager = Get-DirectoryObject -Identity $TargetObject.managedBy | Select-Object -First 1
				& $AddPrincipal $Manager $Source @{ Right = 'managedBy'; Target = $Target }
			}

			if (-not $TargetObject.nTSecurityDescriptor) {
				if ($TargetObject) {
					Write-Warning "Unable to read permissions of $Target"
				}
				return
			}

			$AceParameter = @{
				SecurityDescriptor = $TargetObject.nTSecurityDescriptor
				ExcludeInherited   = $Source -eq 'ObjectACL'
			}

			foreach ($Ace in (Get-PrivilegedAce @AceParameter)) {

				if ($Ace.SID -match '^(S-1-1-0|S-1-5-7|S-1-5-11|S-1-5-21-.+-(513|515)|S-1-5-32-(545|546|554))$') {
					$Principal = $Ace.SID
					try {
						$Principal = "$(([System.Security.Principal.SecurityIdentifier]$Ace.SID).Translate([System.Security.Principal.NTAccount]).Value) ($($Ace.SID))"
					} catch {
						Write-Verbose "Unable to translate $($Ace.SID)"
					}
					Write-Warning "Broad principal $Principal has $($Ace.Rights) ($($Ace.ObjectType)) on $Target"
					continue
				}

				if ($Ace.SID -match '^S-1-5-32-') {
					$Server = Get-DomainName -DistinguishedName $Target
				} elseif ($Ace.SID -match '^S-1-5-21-') {
					$Server = (Get-SidDomain -SID $Ace.SID -Forest $Forest).DNSRoot
				} else {
					continue
				}

				if (-not $Server) {
					Write-Verbose "No reachable domain for $($Ace.SID) on $Target"
					continue
				}

				$Principal = Get-DirectoryObject -LDAPFilter "(objectSid=$($Ace.SID))" -Server $Server | Select-Object -First 1

				& $AddPrincipal $Principal $Source @{ Right = $Ace.Rights; ObjectType = $Ace.ObjectType; Target = $Target }

			}

		}

		#Principals with control of a Tier Zero object are Tier Zero in turn, so repeat until nothing new is found
		$Checked = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)

		do {

			$Accounts = @(
				$Registry.Values | Where-Object { $PSItem.Object.ObjectClass -ne 'foreignSecurityPrincipal' } |
					ForEach-Object { $PSItem.Object.DistinguishedName }
			)

			$Containers = @(
				@(
					$Forest.Domain.DistinguishedName,
					"CN=Users,$($Forest.Domain.DistinguishedName)",
					"CN=AdminSDHolder,CN=System,$($Forest.Domain.DistinguishedName)",
					"OU=Domain Controllers,$($Forest.Domain.DistinguishedName)"
					@($Groups) | Get-ParentDN
					$Registry.Values | ForEach-Object { $PSItem.Object.DistinguishedName } | Get-ParentDN
				) | Sort-Object -Unique | Where-Object { $Checked.Add($PSItem) }
			)

			$Objects = @(
				@(@($Groups) + $Accounts) | Sort-Object -Unique | Where-Object { $PSItem -and $Checked.Add($PSItem) }
			)

			foreach ($Container in $Containers) {
				& $CheckAcl $Container ContainerACL
			}

			foreach ($Object in $Objects) {
				& $CheckAcl $Object ObjectACL
			}

		} while ($Containers -or $Objects)

	}

	foreach ($Entry in $Registry.Values) {
		ConvertTo-TierZeroAccount -Entry $Entry -Forest $Forest
	}

}
