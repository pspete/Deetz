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
			$Forest = [pscustomobject]@{
				Domain     = [pscustomobject]@{ DNSRoot = 'child.corp.local'; DomainSID = 'S-1-5-21-2' }
				ForestRoot = [pscustomobject]@{ DNSRoot = 'corp.local'; DomainSID = 'S-1-5-21-1' }
			}
			$Result = Get-TierZeroGroupSeed -Forest $Forest
		}

		It 'returns builtin groups from the target domain' {
			($Result | Where-Object { $PSItem.SID -eq 'S-1-5-32-544' }).Server | Should -Be 'child.corp.local'
		}

		It 'returns domain groups from the target domain' {
			($Result | Where-Object { $PSItem.SID -eq 'S-1-5-21-2-512' }).Server | Should -Be 'child.corp.local'
		}

		It 'returns forest groups from the forest root domain' {
			($Result | Where-Object { $PSItem.SID -eq 'S-1-5-21-1-519' }).Server | Should -Be 'corp.local'
		}

		It 'returns the groups rated Tier Zero by the Tier Zero Table' {
			$Result.SID | Should -Contain 'S-1-5-32-557'
			$Result.SID | Should -Contain 'S-1-5-32-559'
			$Result.SID | Should -Contain 'S-1-5-21-2-517'
		}

		It 'returns no groups rated not Tier Zero by the Tier Zero Table' {
			foreach ($SID in 'S-1-5-21-2-520', 'S-1-5-21-2-521', 'S-1-5-21-2-571', 'S-1-5-21-2-572', 'S-1-5-21-1-498') {
				$Result.SID | Should -Not -Contain $SID
			}
		}

		It 'returns no forest groups without a forest root domain' {
			$Forest.ForestRoot = $null
			Get-TierZeroGroupSeed -Forest $Forest | Where-Object { $PSItem.SID -like 'S-1-5-21-1-*' } | Should -BeNullOrEmpty
		}

	}

}
