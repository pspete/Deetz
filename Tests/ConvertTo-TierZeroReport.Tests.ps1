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

	}

	InModuleScope $(Split-Path (Split-Path (Split-Path -Parent $PSCommandPath) -Parent) -Leaf ) {

		BeforeAll {

			$Account = [pscustomobject]@{
				SamAccountName       = 'alice'
				Domain               = 'corp.local'
				ServicePrincipalName = [string[]]@('http/a', 'http/b')
				Source               = [string[]]@('GroupMembership', 'ObjectACL')
				TierZeroGroup        = [string[]]@('BUILTIN\Administrators')
				Reason               = @(
					[pscustomobject]@{ Source = 'GroupMembership'; TierZeroGroup = 'BUILTIN\Administrators'; Path = @('BUILTIN\Administrators', 'CORP\Domain Admins'); Right = $null; ObjectType = $null; Target = $null }
					[pscustomobject]@{ Source = 'ObjectACL'; TierZeroGroup = $null; Path = @(); Right = 'Owner'; ObjectType = 'All'; Target = 'CN=bob,DC=corp,DC=local' }
				)
				InPAM                = $true
			}

			$Result = @($Account | ConvertTo-TierZeroReport)

		}

		It 'outputs a row for each reason' {
			$Result | Should -HaveCount 2
		}

		It 'outputs the reason of each row' {
			$Result[0].Source | Should -Be 'GroupMembership'
			$Result[0].TierZeroGroup | Should -Be 'BUILTIN\Administrators'
			$Result[0].Path | Should -Be 'BUILTIN\Administrators > CORP\Domain Admins'
			$Result[1].Source | Should -Be 'ObjectACL'
			$Result[1].Right | Should -Be 'Owner'
			$Result[1].ObjectType | Should -Be 'All'
			$Result[1].Target | Should -Be 'CN=bob,DC=corp,DC=local'
		}

		It 'joins multi-valued account properties' {
			$Result[0].ServicePrincipalName | Should -Be 'http/a; http/b'
		}

		It 'keeps properties added to the account' {
			$Result.InPAM | Should -Be @($true, $true)
			$Result[0].SamAccountName | Should -Be 'alice'
		}

		It 'does not output the Reason property' {
			$Result[0].PSObject.Properties.Name | Should -Not -Contain 'Reason'
		}

	}

}
