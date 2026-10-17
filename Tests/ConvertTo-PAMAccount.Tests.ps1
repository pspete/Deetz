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

			$Accounts = @(
				[pscustomobject]@{ SamAccountName = 'alice'; Domain = 'corp.local'; ObjectClass = 'user' }
				[pscustomobject]@{ SamAccountName = 'DC01$'; Domain = 'corp.local'; ObjectClass = 'computer' }
				[pscustomobject]@{ SamAccountName = 'erin'; Domain = ''; ObjectClass = 'foreignSecurityPrincipal' }
				[pscustomobject]@{ SamAccountName = 'svc'; Domain = 'corp.local'; ObjectClass = 'msDS-GroupManagedServiceAccount' }
			)

			$Result = $Accounts | ConvertTo-PAMAccount -SafeName T0-Accounts -PlatformID WinDomain

		}

		Context 'Output' {

			It 'outputs user accounts only' {
				$Result | Should -HaveCount 1
			}

			It 'outputs the properties expected by Add-PASAccount' {
				$Result.userName | Should -Be 'alice'
				$Result.address | Should -Be 'corp.local'
				$Result.platformID | Should -Be 'WinDomain'
				$Result.SafeName | Should -Be 'T0-Accounts'
			}

			It 'outputs properties in a fixed order' {
				$Result.PSObject.Properties.Name | Should -Be @('userName', 'address', 'platformID', 'SafeName')
			}

		}

	}

}
