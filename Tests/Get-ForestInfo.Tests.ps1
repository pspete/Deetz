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

		BeforeEach {
			Mock Get-ADDomain -MockWith {
				$Name = if ($Identity) { "$Identity" } else { 'child.corp.local' }
				if ($Name -eq 'broken.corp.local') { throw 'Unavailable' }
				[pscustomobject]@{
					DNSRoot           = $Name
					NetBIOSName       = ($Name -split '\.')[0].ToUpper()
					DistinguishedName = 'DC=' + ($Name -replace '\.', ',DC=')
					DomainSID         = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-21-1-2-$($Name.Length)")
					Forest            = 'corp.local'
				}
			}
			Mock Get-ADForest -MockWith {
				[pscustomobject]@{ RootDomain = 'corp.local'; Domains = @('corp.local', 'child.corp.local', 'broken.corp.local') }
			}
			Mock Get-ADObject -MockWith {
				$Binary = {
					param($Value)
					$Sid = New-Object System.Security.Principal.SecurityIdentifier($Value)
					$Bytes = New-Object byte[] $Sid.BinaryLength
					$Sid.GetBinaryForm($Bytes, 0)
					, $Bytes
				}
				$Parent = if ($Server -eq 'corp.local') { 'child.corp.local' } else { 'corp.local' }
				[pscustomobject]@{ trustPartner = $Parent; flatName = $Parent.Split('.')[0].ToUpper(); securityIdentifier = & $Binary "S-1-5-21-1-2-$($Parent.Length)" }
				[pscustomobject]@{ trustPartner = 'partner.local'; flatName = 'PARTNER'; securityIdentifier = & $Binary 'S-1-5-21-9-8-7' }
				[pscustomobject]@{ trustPartner = 'realm.local'; flatName = 'REALM'; securityIdentifier = $null }
				[pscustomobject]@{ trustPartner = 'legacy.local'; flatName = 'LEGACY'; securityIdentifier = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-21-4-5-6') }
			}
			$Result = Get-ForestInfo -WarningVariable Warnings -WarningAction SilentlyContinue
		}

		It 'returns the target domain' {
			$Result.Domain.DNSRoot | Should -Be 'child.corp.local'
			$Result.Domain.NetBIOSName | Should -Be 'CHILD'
		}

		It 'returns the forest root domain' {
			$Result.ForestRoot.DNSRoot | Should -Be 'corp.local'
		}

		It 'returns the domain SID as a string' {
			$Result.Domain.DomainSID | Should -BeOfType [string]
			$Result.Domain.DomainSID | Should -Be 'S-1-5-21-1-2-16'
		}

		It 'warns about unavailable domains' {
			$Result.Domains | Should -HaveCount 2
			$Warnings | Should -Match 'broken.corp.local'
		}

		It 'returns domains trusted from outside the forest' {
			$Result.Trusts | Should -HaveCount 2
			$Result.Trusts[0].DNSRoot | Should -Be 'partner.local'
			$Result.Trusts[0].NetBIOSName | Should -Be 'PARTNER'
			$Result.Trusts[0].DistinguishedName | Should -Be 'DC=partner,DC=local'
			$Result.Trusts[0].DomainSID | Should -BeOfType [string]
			$Result.Trusts[0].DomainSID | Should -Be 'S-1-5-21-9-8-7'
		}

		It 'accepts trust SIDs already converted by the ActiveDirectory module' {
			$Result.Trusts[1].DNSRoot | Should -Be 'legacy.local'
			$Result.Trusts[1].DomainSID | Should -BeOfType [string]
			$Result.Trusts[1].DomainSID | Should -Be 'S-1-5-21-4-5-6'
		}

		It 'queries the trusts of each available forest domain' {
			Should -Invoke Get-ADObject -ParameterFilter { $LDAPFilter -eq '(objectClass=trustedDomain)' } -Times 2 -Exactly -Scope It
		}

		It 'warns when trusts cannot be queried' {
			Mock Get-ADObject -MockWith { throw 'Denied' }
			$Trusted = Get-ForestInfo -WarningVariable TrustWarnings -WarningAction SilentlyContinue
			$Trusted.Trusts | Should -HaveCount 0
			$TrustWarnings -match 'Unable to query trusts of' | Should -HaveCount 2
		}

		It 'throws when the target domain cannot be queried' {
			Mock Get-ADDomain -MockWith { throw 'Rejected' }
			{ Get-ForestInfo -Domain 'broken.corp.local' } | Should -Throw 'Unable to query domain broken.corp.local: Rejected'
		}

		It 'throws when the forest cannot be queried' {
			Mock Get-ADForest -MockWith { throw 'Denied' }
			{ Get-ForestInfo } | Should -Throw 'Unable to query domain *Denied'
		}

		It 'queries the specified domain' {
			$null = Get-ForestInfo -Domain 'corp.local' -WarningAction SilentlyContinue
			Should -Invoke Get-ADDomain -ParameterFilter { $Server -eq 'corp.local' -and -not $Identity } -Times 1 -Exactly -Scope It
		}

	}

}
