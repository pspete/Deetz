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
				[pscustomobject]@{ SamAccountName = 'alice'; Domain = 'corp.local'; NetBIOSDomain = 'CORP'; UserPrincipalName = 'alice@corp.local' }
				[pscustomobject]@{ SamAccountName = 'bob'; Domain = 'corp.local'; NetBIOSDomain = 'CORP'; UserPrincipalName = 'bob@corp.local' }
				[pscustomobject]@{ SamAccountName = 'carol'; Domain = 'corp.local'; NetBIOSDomain = 'CORP'; UserPrincipalName = 'cz@corp.local' }
				[pscustomobject]@{ SamAccountName = 'dave'; Domain = 'corp.local'; NetBIOSDomain = 'CORP'; UserPrincipalName = $null }
				[pscustomobject]@{ SamAccountName = 'erin'; Domain = $null; NetBIOSDomain = $null; UserPrincipalName = $null }
			)

		}

		Context 'Matching' {

			It 'matches on user name and DNS domain address' {
				$Result = $Accounts[0] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'Alice'; address = 'CORP.local' })
				$Result.InPAM | Should -BeTrue
			}

			It 'matches on DOMAIN\user names' {
				$Result = $Accounts[1] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'CORP\bob'; address = 'dc01' })
				$Result.InPAM | Should -BeTrue
			}

			It 'matches on user principal names' {
				$Result = $Accounts[2] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'cz@corp.local'; address = 'x' })
				$Result.InPAM | Should -BeTrue
			}

			It 'matches on user@domain names' {
				$Result = $Accounts[3] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'dave@corp.local'; address = 'x' })
				$Result.InPAM | Should -BeTrue
			}

			It 'does not match a different domain' {
				$Result = $Accounts[0] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'alice'; address = 'other.local' })
				$Result.InPAM | Should -BeFalse
			}

			It 'does not match accounts without a domain' {
				$Result = $Accounts[4] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'erin'; address = '' })
				$Result.InPAM | Should -BeFalse
			}

			It 'uses the specified property names' {
				$Result = $Accounts[0] | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ User = 'alice'; Target = 'corp.local' }) -UserNameProperty User -AddressProperty Target
				$Result.InPAM | Should -BeTrue
			}

			It 'outputs every input object' {
				$Result = $Accounts | Compare-TierZeroAccount -PAMAccount @()
				$Result | Should -HaveCount 5
				$Result.InPAM | Should -Not -Contain $true
			}

			It 'does not change the input objects' {
				$Account = [pscustomobject]@{ SamAccountName = 'alice'; Domain = 'corp.local'; NetBIOSDomain = 'CORP'; UserPrincipalName = 'alice@corp.local' }
				$Account.PSObject.TypeNames.Insert(0, 'Deetz.TierZeroAccount')
				$Before = $Account | Compare-TierZeroAccount -PAMAccount @()
				$After = $Account | Compare-TierZeroAccount -PAMAccount @([pscustomobject]@{ userName = 'alice'; address = 'corp.local' })
				$Before.InPAM | Should -BeFalse
				$After.InPAM | Should -BeTrue
				$Account.PSObject.Properties.Name | Should -Not -Contain 'InPAM'
				$After.PSObject.TypeNames[0] | Should -Be 'Deetz.TierZeroAccount'
			}

		}

	}

}
