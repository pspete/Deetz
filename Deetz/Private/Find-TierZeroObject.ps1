function Find-TierZeroObject {
	<#
	.SYNOPSIS
	Finds the Tier Zero accounts and groups of a domain

	.DESCRIPTION
	Runs Tier Zero discovery by group membership, well known account, container ACL and object ACL,
	returning the forest details with separate registries of the accounts and groups found.
	Each registry is keyed on SID, with entries created by Register-TierZeroAccount.
	Default Tier Zero groups are not given ContainerACL or ObjectACL reasons, as they hold rights over most containers by default.

	.PARAMETER Domain
	DNS name of the domain to check

	.PARAMETER Credential
	Credential used for all directory queries

	.PARAMETER AdditionalGroup
	Names of further groups whose members are Tier Zero

	.PARAMETER SkipAclAnalysis
	Find accounts and groups by group membership and well known account only

	.EXAMPLE
	$Result = Find-TierZeroObject -Domain corp.local
	#>
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
	$GroupRegistry = [ordered]@{}
	$Groups = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
	$DefaultGroups = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)

	$AddGroup = {
		param($Group, $Source, $Grant)

		$TierZeroGroup = $Group.'msDS-PrincipalName'
		$null = $Groups.Add($Group.DistinguishedName)
		Write-Verbose "Checking Group: $TierZeroGroup"

		foreach ($Item in (Expand-GroupMember -Group $Group -Path $TierZeroGroup -Forest $Forest)) {

			if ($Item.Object.ObjectClass -eq 'group') {
				$null = $Groups.Add($Item.Object.DistinguishedName)
				$Target = $GroupRegistry
			} else {
				$Target = $Registry
			}

			Register-TierZeroAccount -Registry $Target -Object $Item.Object -Source $Source -TierZeroGroup $TierZeroGroup -Path $Item.Path @Grant

		}

	}

	#Default Tier Zero groups
	$SeedGroups = @(
		foreach ($Seed in (Get-TierZeroGroupSeed -Forest $Forest)) {

			$Group = Get-DirectoryObject -LDAPFilter "(objectSid=$($Seed.SID))" -Server $Seed.Server | Select-Object -First 1

			if (-not $Group) {
				Write-Verbose "Group $($Seed.SID) not found in $($Seed.Server)"
				continue
			}

			$null = $DefaultGroups.Add($Group.DistinguishedName)
			Register-TierZeroAccount -Registry $GroupRegistry -Object $Group -Source DefaultGroup -TierZeroGroup $Group.'msDS-PrincipalName'
			$Group

		}
	)

	foreach ($Group in $SeedGroups) {
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
			Register-TierZeroAccount -Registry $GroupRegistry -Object $Group -Source AdditionalGroup -TierZeroGroup $Group.'msDS-PrincipalName'
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

			if (-not $Principal) {
				return
			}

			if ($Principal.ObjectClass -eq 'group') {

				if (-not $DefaultGroups.Contains($Principal.DistinguishedName)) {
					Register-TierZeroAccount -Registry $GroupRegistry -Object $Principal -Source $Source @Grant
				}

				if (-not $Groups.Contains($Principal.DistinguishedName)) {
					& $AddGroup $Principal $Source $Grant
				}

			} else {
				Register-TierZeroAccount -Registry $Registry -Object $Principal -Source $Source @Grant
			}

		}

		$AddSid = {
			param($SID, $Source, $Grant)

			$Right = $Grant.Right
			if ($Grant.ObjectType) {
				$Right = "$Right ($($Grant.ObjectType))"
			}

			if ($SID -match '^(S-1-1-0|S-1-5-7|S-1-5-11|S-1-5-21-.+-(513|515)|S-1-5-32-(545|546|554))$') {
				$Principal = $SID
				try {
					$Principal = "$(([System.Security.Principal.SecurityIdentifier]$SID).Translate([System.Security.Principal.NTAccount]).Value) ($SID)"
				} catch {
					Write-Verbose "Unable to translate $SID"
				}
				Write-Warning "Broad principal $Principal has $Right on $($Grant.Target)"
				return
			}

			if ($SID -match '^S-1-5-32-') {
				$Server = Get-DomainName -DistinguishedName $Grant.Target
			} elseif ($SID -match '^S-1-5-21-') {
				$Server = (Get-SidDomain -SID $SID -Forest $Forest).DNSRoot
			} else {
				return
			}

			if (-not $Server) {
				Write-Verbose "No reachable domain for $SID on $($Grant.Target)"
				return
			}

			$Principal = Get-DirectoryObject -LDAPFilter "(objectSid=$SID)" -Server $Server | Select-Object -First 1

			& $AddPrincipal $Principal $Source $Grant

		}

		$CheckAcl = {
			param($Target, $Source)

			Write-Verbose "Checking ACL: $Target"

			$Properties = 'nTSecurityDescriptor', 'managedBy', 'userAccountControl', 'msDS-AllowedToActOnBehalfOfOtherIdentity', 'msDS-GroupMSAMembership'
			$TargetObject = Get-DirectoryObject -Identity $Target -Properties $Properties | Select-Object -First 1

			#The managedBy principal of a read-only domain controller is a local administrator of it
			if ($TargetObject.managedBy -and ($TargetObject.userAccountControl -band 67108864)) {
				$Manager = Get-DirectoryObject -Identity $TargetObject.managedBy | Select-Object -First 1
				& $AddPrincipal $Manager $Source @{ Right = 'managedBy'; Target = $Target }
			}

			#Principals allowed to delegate to the object can impersonate any user to it
			if ($TargetObject.'msDS-AllowedToActOnBehalfOfOtherIdentity') {
				foreach ($SID in (Get-AllowedPrincipal -SecurityDescriptor $TargetObject.'msDS-AllowedToActOnBehalfOfOtherIdentity')) {
					& $AddSid $SID $Source @{ Right = 'AllowedToAct'; Target = $Target }
				}
			}

			#Principals allowed to retrieve the password of a group managed service account control it
			if ($TargetObject.'msDS-GroupMSAMembership') {
				foreach ($SID in (Get-AllowedPrincipal -SecurityDescriptor $TargetObject.'msDS-GroupMSAMembership')) {
					& $AddSid $SID $Source @{ Right = 'ReadGMSAPassword'; Target = $Target }
				}
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
				& $AddSid $Ace.SID $Source @{ Right = $Ace.Rights; ObjectType = $Ace.ObjectType; Target = $Target }
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

	[pscustomobject]@{
		Forest  = $Forest
		Account = $Registry
		Group   = $GroupRegistry
	}

}
