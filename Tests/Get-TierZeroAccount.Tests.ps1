Describe $($PSCommandPath -Replace '.Tests.ps1') {

	BeforeAll {
		#Get Current Directory
		$Here = Split-Path -Parent $PSCommandPath

		#Assume ModuleName from Repository Root folder
		$ModuleName = Split-Path (Split-Path $Here -Parent) -Leaf

		#Resolve Path to Module Directory
		$ModulePath = Resolve-Path "$Here\..\$ModuleName"

		#Define Path to Module Manifest
		$ManifestPath = Join-Path "$ModulePath" "$ModuleName.psd1"

		if ( -not (Get-Module -Name $ModuleName -All)) {

			Import-Module -Name "$ManifestPath" -ArgumentList $true -Force -ErrorAction Stop

		}

		#Stub ActiveDirectory commands where the module is not installed
		foreach ($Command in 'Get-ADObject', 'Get-ADDomain', 'Get-ADForest', 'Get-ADGroup') {
			if (-not (Get-Command -Name $Command -ErrorAction SilentlyContinue)) {
				New-Item -Path "Function:\global:$Command" -Value {
					param($Identity, $LDAPFilter, $Server, $Properties, $Credential)
				} | Out-Null
			}
		}

	}

	InModuleScope $(Split-Path (Split-Path (Split-Path -Parent $PSCommandPath) -Parent) -Leaf ) {

		BeforeAll {

			. (Join-Path (Split-Path -Parent $PSCommandPath) 'TestDirectory.ps1')

			Mock Get-ForestInfo -MockWith { $TestForest }
			Mock Get-DirectoryObject -MockWith { Find-TestDirectoryObject -Identity $Identity -LDAPFilter $LDAPFilter -Properties $Properties -Server $Server }
			Mock Get-ADGroup -MockWith { [pscustomobject]@{ DistinguishedName = "CN=Helpdesk,OU=Admins,DC=corp,DC=local" } }

		}

		Context 'Default discovery' {

			BeforeAll {

				$Result = Get-TierZeroAccount -WarningVariable Warnings -WarningAction SilentlyContinue

			}

			It 'outputs objects of type Deetz.TierZeroAccount' {
				$Result | ForEach-Object { $PSItem.PSObject.TypeNames[0] } | Select-Object -Unique | Should -Be 'Deetz.TierZeroAccount'
			}

			It 'does not output groups' {
				$Result | Where-Object { $PSItem.ObjectClass -eq 'group' } | Should -BeNullOrEmpty
			}

			It 'outputs each account once' {
				$Result.SID | Group-Object | Where-Object { $PSItem.Count -gt 1 } | Should -BeNullOrEmpty
			}

			It 'attributes nested members to every Tier Zero group' {
				$Alice = $Result | Where-Object { $PSItem.SamAccountName -eq 'alice' }
				$Alice.TierZeroGroup | Should -Be @('BUILTIN\Administrators', 'CORP\Domain Admins')
				($Alice.Reason | ForEach-Object { $PSItem.Path -join ' > ' }) | Should -Be @('BUILTIN\Administrators > CORP\Domain Admins', 'CORP\Domain Admins')
				$Alice.Source | Should -Be 'GroupMembership'
			}

			It 'finds primary group members' {
				$DC = $Result | Where-Object { $PSItem.SamAccountName -eq 'DC01' }
				$DC.TierZeroGroup | Should -Be 'CORP\Domain Controllers'
				$DC.ObjectClass | Should -Be 'computer'
			}

			It 'finds well known accounts' {
				$Krbtgt = $Result | Where-Object { $PSItem.SamAccountName -eq 'krbtgt' }
				$Krbtgt.Source | Should -Be 'WellKnownAccount'
				$Krbtgt.Enabled | Should -BeFalse
				($Result | Where-Object { $PSItem.SamAccountName -eq 'Administrator' }).Source | Should -Be @('GroupMembership', 'WellKnownAccount')
			}

			It 'finds read-only domain controller accounts' {
				$RODC = $Result | Where-Object { $PSItem.SamAccountName -eq 'RODC01' }
				$RODC.Source | Should -Be 'WellKnownAccount'
				$RODC.TierZeroGroup | Should -BeNullOrEmpty
			}

			It 'finds members of groups with control of a Tier Zero container' {
				$Bob = $Result | Where-Object { $PSItem.SamAccountName -eq 'bob' }
				$Bob.Source | Should -Be 'ContainerACL'
				$Bob.TierZeroGroup | Should -Be 'CORP\Helpdesk'
				$Bob.Reason.Path | Should -Be 'CORP\Helpdesk'
				$Bob.Reason.Right | Should -Be 'GenericAll'
				$Bob.Reason.ObjectType | Should -Be 'All'
				$Bob.Reason.Target | Should -Be 'OU=Admins,DC=corp,DC=local'
			}

			It 'warns about broad principals with control of a Tier Zero container' {
				$Warnings.Message | Should -Contain 'Broad principal S-1-5-21-1-2-3-513 has WriteDacl (All) on OU=Admins,DC=corp,DC=local'
			}

			It 'names broad principals in warnings where the SID translates' {
				$Warnings.Message | Should -Contain 'Broad principal NT AUTHORITY\Authenticated Users (S-1-5-11) has GenericWrite (All) on OU=Admins,DC=corp,DC=local'
			}

			It 'outputs domain details' {
				$Alice = $Result | Where-Object { $PSItem.SamAccountName -eq 'alice' }
				$Alice.Domain | Should -Be 'corp.local'
				$Alice.NetBIOSDomain | Should -Be 'CORP'
				$Alice.UserPrincipalName | Should -Be 'alice@corp.local'
			}

			It 'expands groups from a trusted domain' {
				$Carol = $Result | Where-Object { $PSItem.SamAccountName -eq 'carol' }
				$Carol.Domain | Should -Be 'partner.local'
				$Carol.NetBIOSDomain | Should -Be 'PARTNER'
				$Carol.Reason.Path | Should -Be @('BUILTIN\Administrators', 'PARTNER\Partner Admins')
			}

			It 'does not report foreign security principals for trusted domain groups as accounts' {
				$Result | Where-Object { $PSItem.SID -eq "$PartnerSID-1110" } | Should -BeNullOrEmpty
			}

			It 'finds trusted domain principals with control of a Tier Zero container' {
				$Dave = $Result | Where-Object { $PSItem.SamAccountName -eq 'dave' }
				$Dave.Source | Should -Be 'ContainerACL'
				$Dave.Domain | Should -Be 'partner.local'
				$Dave.Reason.Right | Should -Be 'GenericAll'
				$Dave.Reason.Target | Should -Be 'OU=Admins,DC=corp,DC=local'
				$Dave.TierZeroGroup | Should -BeNullOrEmpty
			}

			It 'finds owners of Tier Zero accounts' {
				$Eve = $Result | Where-Object { $PSItem.SamAccountName -eq 'eve' }
				$Eve.Source | Should -Be 'ObjectACL'
				$Eve.Reason.Right | Should -Be 'Owner'
				$Eve.Reason.Target | Should -Be 'CN=alice,OU=Admins,DC=corp,DC=local'
			}

			It 'finds members of groups with control of a Tier Zero group' {
				$Frank = $Result | Where-Object { $PSItem.SamAccountName -eq 'frank' }
				$Frank.Source | Should -Be 'ObjectACL'
				$Frank.TierZeroGroup | Should -Be 'CORP\Server Team'
				$Frank.Reason.Right | Should -Be 'WriteProperty'
				$Frank.Reason.ObjectType | Should -Be 'member'
				$Frank.Reason.Target | Should -Be 'CN=Domain Admins,CN=Users,DC=corp,DC=local'
			}

			It 'finds principals with control of accounts found through control' {
				$Grace = $Result | Where-Object { $PSItem.SamAccountName -eq 'grace' }
				$Grace.Source | Should -Be 'ObjectACL'
				$Grace.Reason.Right | Should -Be 'GenericAll'
				$Grace.Reason.Target | Should -Be 'CN=eve,OU=Staff,DC=corp,DC=local'
			}

			It 'finds the manager of a read-only domain controller' {
				$Manager = $Result | Where-Object { $PSItem.SamAccountName -eq 'rodcadmin' }
				$Manager.Source | Should -Be 'ObjectACL'
				$Manager.Reason.Right | Should -Be 'managedBy'
				$Manager.Reason.Target | Should -Be 'CN=RODC01,OU=Domain Controllers,DC=corp,DC=local'
			}

			It 'finds principals allowed to delegate to a Tier Zero computer' {
				$Web = $Result | Where-Object { $PSItem.SamAccountName -eq 'WEB01' }
				$Web.Source | Should -Be 'ObjectACL'
				$Web.Reason.Right | Should -Be 'AllowedToAct'
				$Web.Reason.ObjectType | Should -BeNullOrEmpty
				$Web.Reason.Target | Should -Be 'CN=DC01,OU=Domain Controllers,DC=corp,DC=local'
			}

			It 'finds members of groups allowed to retrieve the password of a Tier Zero gMSA' {
				$App = $Result | Where-Object { $PSItem.SamAccountName -eq 'APP01' }
				$App.Source | Should -Be 'ObjectACL'
				$App.TierZeroGroup | Should -Be 'CORP\Tier0 Hosts'
				$App.Reason.Right | Should -Be 'ReadGMSAPassword'
				$App.Reason.Target | Should -Be 'CN=svc-t0,CN=Managed Service Accounts,DC=corp,DC=local'
			}

			It 'warns about broad principals allowed to retrieve the password of a Tier Zero gMSA' {
				$Warnings.Message | Should -Contain 'Broad principal S-1-5-21-1-2-3-515 has ReadGMSAPassword on CN=svc-t0,CN=Managed Service Accounts,DC=corp,DC=local'
			}

			It 'ignores inherited entries on Tier Zero objects' {
				$Result.SamAccountName | Should -Not -Contain 'heidi'
			}

		}

		Context 'Parameters' {

			It 'skips ACL analysis' {
				$Result = Get-TierZeroAccount -SkipAclAnalysis
				$Result.SamAccountName | Should -Not -Contain 'bob'
				Should -Invoke Get-DirectoryObject -ParameterFilter { $Properties -contains 'nTSecurityDescriptor' } -Times 0 -Exactly -Scope It
			}

			It 'expands additional groups' {
				$Result = Get-TierZeroAccount -AdditionalGroup Helpdesk -SkipAclAnalysis
				($Result | Where-Object { $PSItem.SamAccountName -eq 'bob' }).Source | Should -Be 'GroupMembership'
				Should -Invoke Get-ADGroup -ParameterFilter { $Server -eq 'corp.local' } -Times 1 -Exactly -Scope It
			}

			It 'warns when an additional group is not found' {
				Mock Get-ADGroup -MockWith { throw 'Cannot find an object' }
				Get-TierZeroAccount -AdditionalGroup Missing -SkipAclAnalysis -WarningVariable Warnings -WarningAction SilentlyContinue
				$Warnings | Should -Match 'Unable to find group Missing'
			}

			It 'warns when the permissions of an object cannot be read' {
				Mock Get-DirectoryObject -ParameterFilter { $Properties -contains 'nTSecurityDescriptor' } -MockWith {
					[pscustomobject]@{ DistinguishedName = $Identity; nTSecurityDescriptor = $null }
				}
				$null = Get-TierZeroAccount -WarningVariable Warnings -WarningAction SilentlyContinue
				$Warnings.Message | Should -Contain 'Unable to read permissions of OU=Domain Controllers,DC=corp,DC=local'
			}

			It 'sets the session credential' {
				$Credential = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'x' -AsPlainText -Force))
				$null = Get-TierZeroAccount -Credential $Credential -SkipAclAnalysis
				$Script:DeetzSession.Credential.UserName | Should -Be 'user'
				$Script:DeetzSession.Credential = $null
			}

		}

	}

}
