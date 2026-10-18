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

				$Result = Get-TierZeroGroup -WarningAction SilentlyContinue

			}

			It 'outputs objects of type Deetz.TierZeroGroup' {
				$Result | ForEach-Object { $PSItem.PSObject.TypeNames[0] } | Select-Object -Unique | Should -Be 'Deetz.TierZeroGroup'
			}

			It 'outputs each group once' {
				$Result.SID | Group-Object | Where-Object { $PSItem.Count -gt 1 } | Should -BeNullOrEmpty
			}

			It 'outputs default groups' {
				$Group = $Result | Where-Object { $PSItem.SamAccountName -eq 'Domain Controllers' }
				$Group.Source | Should -Be 'DefaultGroup'
				$Group.TierZeroGroup | Should -Be 'CORP\Domain Controllers'
				$Group.Domain | Should -Be 'corp.local'
				$Group.NetBIOSDomain | Should -Be 'CORP'
			}

			It 'records nesting of default groups' {
				$Group = $Result | Where-Object { $PSItem.SamAccountName -eq 'Domain Admins' }
				$Group.Source | Should -Be @('DefaultGroup', 'GroupMembership')
				($Group.Reason | Where-Object { $PSItem.Source -eq 'GroupMembership' }).Path | Should -Be 'BUILTIN\Administrators'
				$Group.MemberCount | Should -Be 2
			}

			It 'does not record ACL reasons for default groups' {
				($Result | Where-Object { $PSItem.SamAccountName -eq 'Domain Admins' }).Source | Should -Not -Contain 'ObjectACL'
			}

			It 'outputs groups from a trusted domain' {
				$Group = $Result | Where-Object { $PSItem.SamAccountName -eq 'Partner Admins' }
				$Group.Source | Should -Be 'GroupMembership'
				$Group.Domain | Should -Be 'partner.local'
				$Group.NetBIOSDomain | Should -Be 'PARTNER'
			}

			It 'outputs groups with control of a Tier Zero container' {
				$Group = $Result | Where-Object { $PSItem.SamAccountName -eq 'Helpdesk' }
				$Group.Source | Should -Be 'ContainerACL'
				$Group.TierZeroGroup | Should -BeNullOrEmpty
				$Group.Reason.Right | Should -Be 'GenericAll'
				$Group.Reason.Target | Should -Be 'OU=Admins,DC=corp,DC=local'
			}

			It 'outputs groups with control of a Tier Zero group' {
				$Group = $Result | Where-Object { $PSItem.SamAccountName -eq 'Server Team' }
				$Group.Source | Should -Be 'ObjectACL'
				$Group.Reason.ObjectType | Should -Be 'member'
				$Group.Reason.Target | Should -Be 'CN=Domain Admins,CN=Users,DC=corp,DC=local'
			}

			It 'does not output accounts' {
				$Result.SamAccountName | Should -Not -Contain 'alice'
			}

		}

		Context 'Parameters' {

			It 'skips ACL analysis' {
				$Result = Get-TierZeroGroup -SkipAclAnalysis
				$Result.SamAccountName | Should -Not -Contain 'Helpdesk'
				Should -Invoke Get-DirectoryObject -ParameterFilter { $Properties -contains 'nTSecurityDescriptor' } -Times 0 -Exactly -Scope It
			}

			It 'outputs additional groups' {
				$Result = Get-TierZeroGroup -AdditionalGroup Helpdesk -SkipAclAnalysis
				($Result | Where-Object { $PSItem.SamAccountName -eq 'Helpdesk' }).Source | Should -Be 'AdditionalGroup'
			}

			It 'records ACL reasons for additional groups' {
				$Result = Get-TierZeroGroup -AdditionalGroup Helpdesk -WarningAction SilentlyContinue
				($Result | Where-Object { $PSItem.SamAccountName -eq 'Helpdesk' }).Source | Should -Be @('AdditionalGroup', 'ContainerACL')
			}

		}

	}

}
