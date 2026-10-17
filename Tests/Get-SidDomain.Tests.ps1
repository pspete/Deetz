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
			$Forest = [pscustomobject]@{
				Domains = @(
					[pscustomobject]@{ DNSRoot = 'corp.local'; DomainSID = 'S-1-5-21-1-2-3' }
					[pscustomobject]@{ DNSRoot = 'child.corp.local'; DomainSID = 'S-1-5-21-1-2-33' }
				)
				Trusts  = @(
					[pscustomobject]@{ DNSRoot = 'partner.local'; DomainSID = 'S-1-5-21-9-8-7' }
				)
			}
		}

		It 'returns the forest domain which issued the SID' {
			(Get-SidDomain -SID 'S-1-5-21-1-2-3-1105' -Forest $Forest).DNSRoot | Should -Be 'corp.local'
			(Get-SidDomain -SID 'S-1-5-21-1-2-33-1105' -Forest $Forest).DNSRoot | Should -Be 'child.corp.local'
		}

		It 'returns the trusted domain which issued the SID' {
			(Get-SidDomain -SID 'S-1-5-21-9-8-7-1110' -Forest $Forest).DNSRoot | Should -Be 'partner.local'
		}

		It 'only matches trusted domains with TrustOnly' {
			Get-SidDomain -SID 'S-1-5-21-1-2-3-1105' -Forest $Forest -TrustOnly | Should -BeNullOrEmpty
			(Get-SidDomain -SID 'S-1-5-21-9-8-7-1110' -Forest $Forest -TrustOnly).DNSRoot | Should -Be 'partner.local'
		}

		It 'returns nothing for builtin or unknown SIDs' {
			Get-SidDomain -SID 'S-1-5-32-544' -Forest $Forest | Should -BeNullOrEmpty
			Get-SidDomain -SID 'S-1-5-21-4-5-6-500' -Forest $Forest | Should -BeNullOrEmpty
		}

		It 'returns nothing when the forest has no trusts' {
			$Local = [pscustomobject]@{ Domains = $Forest.Domains; Trusts = @() }
			Get-SidDomain -SID 'S-1-5-21-9-8-7-1110' -Forest $Local | Should -BeNullOrEmpty
		}

	}

}
