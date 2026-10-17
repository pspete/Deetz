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
		}

		It 'outputs a flat Deetz.TierZeroAccount object' {
			$Object = $TestDirectory | Where-Object { $PSItem.sAMAccountName -eq 'alice' }
			$Object.pwdLastSet = 133000000000000000
			$Object.servicePrincipalName = @('http/a', 'http/b')
			$Entry = [pscustomobject]@{ Object = $Object; Reason = @(
					[pscustomobject]@{ Source = 'GroupMembership'; TierZeroGroup = 'A'; Path = @('A') }
					[pscustomobject]@{ Source = 'GroupMembership'; TierZeroGroup = 'B'; Path = @('B', 'A') }
					[pscustomobject]@{ Source = 'WellKnownAccount'; TierZeroGroup = $null; Path = @() }
				)
			}
			$Result = ConvertTo-TierZeroAccount -Entry $Entry -Forest $TestForest
			$Result.PSObject.TypeNames[0] | Should -Be 'Deetz.TierZeroAccount'
			$Result.Domain | Should -Be 'corp.local'
			$Result.NetBIOSDomain | Should -Be 'CORP'
			$Result.Enabled | Should -BeTrue
			$Result.PasswordLastSet | Should -BeOfType [datetime]
			$Result.LastLogonDate | Should -BeNullOrEmpty
			$Result.ServicePrincipalName | Should -Be @('http/a', 'http/b')
			$Result.TierZeroGroup | Should -Be @('A', 'B')
			$Result.Source | Should -Be @('GroupMembership', 'WellKnownAccount')
			$Result.Reason | Should -HaveCount 3
		}

		It 'reports disabled accounts' {
			$Object = $TestDirectory | Where-Object { $PSItem.sAMAccountName -eq 'krbtgt' }
			$Entry = [pscustomobject]@{ Object = $Object; Reason = @([pscustomobject]@{ Source = 'WellKnownAccount' }) }
			(ConvertTo-TierZeroAccount -Entry $Entry -Forest $TestForest).Enabled | Should -BeFalse
		}

		It 'translates foreign security principals' {
			$Object = [pscustomobject]@{ DistinguishedName = 'CN=S-1-5-32-544,CN=ForeignSecurityPrincipals,DC=corp,DC=local'; ObjectClass = 'foreignSecurityPrincipal'; objectSid = 'S-1-5-32-544' }
			$Entry = [pscustomobject]@{ Object = $Object; Reason = @([pscustomobject]@{ Source = 'GroupMembership' }) }
			$Result = ConvertTo-TierZeroAccount -Entry $Entry -Forest $TestForest
			$Result.SamAccountName | Should -Be 'Administrators'
			$Result.NetBIOSDomain | Should -Be 'BUILTIN'
			$Result.Domain | Should -BeNullOrEmpty
		}

		It 'reports the trusted domain of foreign security principals' {
			$Object = $TestDirectory | Where-Object { $PSItem.ObjectClass -eq 'foreignSecurityPrincipal' }
			$Entry = [pscustomobject]@{ Object = $Object; Reason = @([pscustomobject]@{ Source = 'GroupMembership' }) }
			$Result = ConvertTo-TierZeroAccount -Entry $Entry -Forest $TestForest
			$Result.Domain | Should -Be 'partner.local'
			$Result.NetBIOSDomain | Should -Be 'PARTNER'
			$Result.SID | Should -Be "$PartnerSID-1110"
		}

		It 'reports the NetBIOS name of trusted domain objects' {
			$Object = $TestDirectory | Where-Object { $PSItem.sAMAccountName -eq 'carol' }
			$Entry = [pscustomobject]@{ Object = $Object; Reason = @([pscustomobject]@{ Source = 'GroupMembership' }) }
			$Result = ConvertTo-TierZeroAccount -Entry $Entry -Forest $TestForest
			$Result.Domain | Should -Be 'partner.local'
			$Result.NetBIOSDomain | Should -Be 'PARTNER'
		}

	}

}
