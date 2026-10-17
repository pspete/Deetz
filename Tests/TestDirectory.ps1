#Fake corp.local directory used by the Get-DirectoryObject mocks
$DomainDN = 'DC=corp,DC=local'
$DomainSID = 'S-1-5-21-1-2-3'

$TestDomain = [pscustomobject]@{
	DNSRoot           = 'corp.local'
	NetBIOSName       = 'CORP'
	DistinguishedName = $DomainDN
	DomainSID         = $DomainSID
}

#Domain in a trusted forest
$PartnerDN = 'DC=partner,DC=local'
$PartnerSID = 'S-1-5-21-9-8-7'

$TestTrust = [pscustomobject]@{
	DNSRoot           = 'partner.local'
	NetBIOSName       = 'PARTNER'
	DistinguishedName = $PartnerDN
	DomainSID         = $PartnerSID
}

$TestForest = [pscustomobject]@{
	Domain     = $TestDomain
	ForestRoot = $TestDomain
	Domains    = @($TestDomain)
	Trusts     = @($TestTrust)
}

function New-TestObject {
	param($Name, $Class, $Parent, $Rid, $Member, $PrimaryGroupID, $UserAccountControl = 512, $NetBIOS = 'CORP', $ManagedBy)

	$SID = if ($Rid -match '^S-') { $Rid } else { "$DomainSID-$Rid" }

	[pscustomobject]@{
		DistinguishedName    = "CN=$Name,$Parent"
		ObjectClass          = $Class
		objectSid            = $SID
		'msDS-PrincipalName' = "$NetBIOS\$Name"
		sAMAccountName       = $Name
		userPrincipalName    = $(if ($Class -eq 'user') { "$Name@corp.local" })
		member               = @($Member | Where-Object { $PSItem })
		primaryGroupID       = $PrimaryGroupID
		userAccountControl   = $(if ($Class -ne 'group') { $UserAccountControl })
		pwdLastSet           = 0
		lastLogonTimestamp   = 0
		servicePrincipalName = @()
		adminCount           = $(if ($Class -ne 'computer') { 1 })
		managedBy            = $ManagedBy
	}
}

$Users = "CN=Users,$DomainDN"
$Admins = "OU=Admins,$DomainDN"
$ForeignPrincipals = "CN=ForeignSecurityPrincipals,$DomainDN"

$TestDirectory = @(
	New-TestObject -Name 'Administrators' -Class group -Parent "CN=Builtin,$DomainDN" -Rid 'S-1-5-32-544' -NetBIOS 'BUILTIN' -Member @(
		"CN=Domain Admins,$Users", "CN=Enterprise Admins,$Users", "CN=Administrator,$Users", "CN=$PartnerSID-1110,$ForeignPrincipals"
	)
	New-TestObject -Name 'Domain Admins' -Class group -Parent $Users -Rid 512 -Member @("CN=alice,$Admins", "CN=Administrator,$Users")
	New-TestObject -Name 'Enterprise Admins' -Class group -Parent $Users -Rid 519 -Member @("CN=Administrator,$Users")
	New-TestObject -Name 'Domain Controllers' -Class group -Parent $Users -Rid 516
	New-TestObject -Name 'Helpdesk' -Class group -Parent $Admins -Rid 1105 -Member @("CN=bob,OU=Staff,$DomainDN")
	New-TestObject -Name 'Administrator' -Class user -Parent $Users -Rid 500 -PrimaryGroupID 513
	New-TestObject -Name 'krbtgt' -Class user -Parent $Users -Rid 502 -PrimaryGroupID 513 -UserAccountControl 514
	New-TestObject -Name 'alice' -Class user -Parent $Admins -Rid 1101 -PrimaryGroupID 513
	New-TestObject -Name 'bob' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1106 -PrimaryGroupID 513
	New-TestObject -Name 'DC01' -Class computer -Parent "OU=Domain Controllers,$DomainDN" -Rid 1000 -PrimaryGroupID 516 -UserAccountControl 532480
	New-TestObject -Name 'RODC01' -Class computer -Parent "OU=Domain Controllers,$DomainDN" -Rid 1001 -PrimaryGroupID 521 -UserAccountControl 83890176 -ManagedBy "CN=rodcadmin,OU=Staff,$DomainDN"
	New-TestObject -Name 'eve' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1108 -PrimaryGroupID 513
	New-TestObject -Name 'grace' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1109 -PrimaryGroupID 513
	New-TestObject -Name 'Server Team' -Class group -Parent "OU=Staff,$DomainDN" -Rid 1110 -Member @("CN=frank,OU=Staff,$DomainDN")
	New-TestObject -Name 'frank' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1111 -PrimaryGroupID 513
	New-TestObject -Name 'heidi' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1112 -PrimaryGroupID 513
	New-TestObject -Name 'rodcadmin' -Class user -Parent "OU=Staff,$DomainDN" -Rid 1113 -PrimaryGroupID 513
	New-TestObject -Name "$PartnerSID-1110" -Class foreignSecurityPrincipal -Parent $ForeignPrincipals -Rid "$PartnerSID-1110" -UserAccountControl $null
	New-TestObject -Name 'Partner Admins' -Class group -Parent "CN=Users,$PartnerDN" -Rid "$PartnerSID-1110" -NetBIOS 'PARTNER' -Member @("CN=carol,CN=Users,$PartnerDN")
	New-TestObject -Name 'carol' -Class user -Parent "CN=Users,$PartnerDN" -Rid "$PartnerSID-1111" -NetBIOS 'PARTNER' -PrimaryGroupID 513
	New-TestObject -Name 'dave' -Class user -Parent "CN=Users,$PartnerDN" -Rid "$PartnerSID-1112" -NetBIOS 'PARTNER' -PrimaryGroupID 513
)

function New-TestSecurityDescriptor {
	param([object[]]$Rule, $Owner, $Sddl)

	$SecurityDescriptor = New-Object -TypeName System.DirectoryServices.ActiveDirectorySecurity

	if ($Sddl) {
		$SecurityDescriptor.SetSecurityDescriptorSddlForm($Sddl)
	}

	if ($Owner) {
		$SecurityDescriptor.SetOwner([System.Security.Principal.SecurityIdentifier]$Owner)
	}

	foreach ($Item in $Rule) {
		$Arguments = @(
			[System.Security.Principal.SecurityIdentifier]$Item.SID,
			[System.DirectoryServices.ActiveDirectoryRights]$Item.Rights,
			[System.Security.AccessControl.AccessControlType]$(if ($Item.Type) { $Item.Type } else { 'Allow' })
		)
		if ($Item.ObjectType) {
			$Arguments += [guid]$Item.ObjectType
		}
		$SecurityDescriptor.AddAccessRule((New-Object -TypeName System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Arguments))
	}

	$SecurityDescriptor
}

$TestAcl = @{
	$Admins = New-TestSecurityDescriptor -Rule @(
		@{ SID = "$DomainSID-1105"; Rights = 'GenericAll' },
		@{ SID = "$DomainSID-1107"; Rights = 'ReadProperty' },
		@{ SID = "$DomainSID-513"; Rights = 'WriteDacl' },
		@{ SID = 'S-1-5-11'; Rights = 'GenericWrite' },
		@{ SID = "$PartnerSID-1112"; Rights = 'GenericAll' }
	)
	"CN=alice,$Admins"            = New-TestSecurityDescriptor -Owner "$DomainSID-1108" -Sddl "D:(A;ID;0xf01ff;;;$DomainSID-1112)"
	"CN=Domain Admins,$Users"     = New-TestSecurityDescriptor -Owner "$DomainSID-512" -Rule @(
		@{ SID = "$DomainSID-1110"; Rights = 'WriteProperty'; ObjectType = 'bf9679c0-0de6-11d0-a285-00aa003049e2' }
	)
	"CN=eve,OU=Staff,$DomainDN"   = New-TestSecurityDescriptor -Rule @{ SID = "$DomainSID-1109"; Rights = 'GenericAll' }
}

#Emulates Get-DirectoryObject against the fake directory
function Find-TestDirectoryObject {
	param($Identity, $LDAPFilter, $Properties, $Server)

	if ($Properties -contains 'nTSecurityDescriptor') {
		$SecurityDescriptor = if ($TestAcl.ContainsKey($Identity)) { $TestAcl[$Identity] } else { New-TestSecurityDescriptor }
		$Object = $TestDirectory | Where-Object { $PSItem.DistinguishedName -eq $Identity }
		return [pscustomobject]@{
			DistinguishedName    = $Identity
			nTSecurityDescriptor = $SecurityDescriptor
			managedBy            = $Object.managedBy
			userAccountControl   = $Object.userAccountControl
		}
	}

	switch -Regex ($LDAPFilter) {
		'^$' { $TestDirectory | Where-Object { $PSItem.DistinguishedName -eq $Identity } }
		'\(objectSid=(?<SID>[^)]+)\)' {
			$SID = $Matches.SID
			$TestDirectory | Where-Object { $PSItem.objectSid -eq $SID -and (-not $Server -or $PSItem.DistinguishedName -like "*,DC=$($Server -replace '\.', ',DC=')") }
		}
		'\(primaryGroupID=(?<Rid>\d+)\)' { $Rid = $Matches.Rid; $TestDirectory | Where-Object { "$($PSItem.primaryGroupID)" -eq $Rid } }
		'sAMAccountName=krbtgt' { $TestDirectory | Where-Object { $PSItem.sAMAccountName -like 'krbtgt*' } }
		'userAccountControl:1\.2\.840\.113556\.1\.4\.803:=67108864' { $TestDirectory | Where-Object { $PSItem.ObjectClass -eq 'computer' -and $PSItem.userAccountControl -band 67108864 } }
	}
}
