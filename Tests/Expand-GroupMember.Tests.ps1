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
			$Administrators = $TestDirectory | Where-Object { $PSItem.sAMAccountName -eq 'Administrators' }
		}

		BeforeEach {
			Mock Get-DirectoryObject -MockWith { Find-TestDirectoryObject -Identity $Identity -LDAPFilter $LDAPFilter -Properties $Properties -Server $Server }
		}

		It 'returns nested members with their membership path' {
			$Result = Expand-GroupMember -Group $Administrators -Path 'BUILTIN\Administrators'
			($Result | Where-Object { $PSItem.Object.sAMAccountName -eq 'alice' }).Path | Should -Be @('BUILTIN\Administrators', 'CORP\Domain Admins')
		}

		It 'returns nested groups' {
			$Result = Expand-GroupMember -Group $Administrators -Path 'BUILTIN\Administrators'
			$Result.Object.sAMAccountName | Should -Contain 'Domain Admins'
		}

		It 'returns primary group members' {
			$Group = $TestDirectory | Where-Object { $PSItem.sAMAccountName -eq 'Domain Controllers' }
			(Expand-GroupMember -Group $Group -Path 'x').Object.sAMAccountName | Should -Be 'DC01'
		}

		It 'does not query primary group members of builtin groups' {
			$null = Expand-GroupMember -Group $Administrators -Path 'x'
			Should -Invoke Get-DirectoryObject -ParameterFilter { $LDAPFilter -eq '(primaryGroupID=544)' } -Times 0 -Exactly -Scope It
		}

		It 'expands groups from a trusted domain' {
			$Result = Expand-GroupMember -Group $Administrators -Path 'BUILTIN\Administrators' -Forest $TestForest
			($Result | Where-Object { $PSItem.Object.sAMAccountName -eq 'carol' }).Path | Should -Be @('BUILTIN\Administrators', 'PARTNER\Partner Admins')
			$Result.Object.ObjectClass | Should -Not -Contain 'foreignSecurityPrincipal'
			($Result | Where-Object { $PSItem.Object.sAMAccountName -eq 'Partner Admins' }).Path | Should -Be 'BUILTIN\Administrators'
			Should -Invoke Get-DirectoryObject -ParameterFilter { $Server -eq 'partner.local' -and $LDAPFilter -eq "(objectSid=$PartnerSID-1110)" } -Times 1 -Exactly -Scope It
		}

		It 'does not expand foreign security principals without forest details' {
			$Result = Expand-GroupMember -Group $Administrators -Path 'BUILTIN\Administrators'
			$Result.Object.sAMAccountName | Should -Not -Contain 'carol'
		}

		It 'outputs foreign security principals for users as the trusted domain user' {
			$Fsp = [pscustomobject]@{ DistinguishedName = "CN=$PartnerSID-1111,$ForeignPrincipals"; ObjectClass = 'foreignSecurityPrincipal'; objectSid = "$PartnerSID-1111" }
			$Group = [pscustomobject]@{ DistinguishedName = 'CN=G,DC=corp,DC=local'; ObjectClass = 'group'; objectSid = 'S-1-5-32-2003'; 'msDS-PrincipalName' = 'CORP\G'; member = @($Fsp.DistinguishedName) }
			Mock Get-DirectoryObject -MockWith { if ($Identity) { $Fsp } else { Find-TestDirectoryObject -LDAPFilter $LDAPFilter -Server $Server } }
			$Result = Expand-GroupMember -Group $Group -Path 'CORP\G' -Forest $TestForest
			$Result | Should -HaveCount 1
			$Result.Object.objectSid | Should -Be "$PartnerSID-1111"
			$Result.Object.ObjectClass | Should -Be 'user'
			$Result.Object.sAMAccountName | Should -Be 'carol'
			$Result.Path | Should -Be 'CORP\G'
		}

		It 'outputs foreign security principals not found in the trusted domain' {
			$Fsp = [pscustomobject]@{ DistinguishedName = "CN=$PartnerSID-1999,$ForeignPrincipals"; ObjectClass = 'foreignSecurityPrincipal'; objectSid = "$PartnerSID-1999" }
			$Group = [pscustomobject]@{ DistinguishedName = 'CN=G,DC=corp,DC=local'; ObjectClass = 'group'; objectSid = 'S-1-5-32-2003'; 'msDS-PrincipalName' = 'CORP\G'; member = @($Fsp.DistinguishedName) }
			Mock Get-DirectoryObject -MockWith { if ($Identity) { $Fsp } else { Find-TestDirectoryObject -LDAPFilter $LDAPFilter -Server $Server } }
			$Result = Expand-GroupMember -Group $Group -Path 'CORP\G' -Forest $TestForest
			$Result | Should -HaveCount 1
			$Result.Object.ObjectClass | Should -Be 'foreignSecurityPrincipal'
		}

		It 'stops on circular nesting' {
			$A = [pscustomobject]@{ DistinguishedName = 'CN=A,DC=corp,DC=local'; ObjectClass = 'group'; objectSid = 'S-1-5-32-2001'; 'msDS-PrincipalName' = 'CORP\A'; member = @('CN=B,DC=corp,DC=local') }
			$B = [pscustomobject]@{ DistinguishedName = 'CN=B,DC=corp,DC=local'; ObjectClass = 'group'; objectSid = 'S-1-5-32-2002'; 'msDS-PrincipalName' = 'CORP\B'; member = @('CN=A,DC=corp,DC=local') }
			Mock Get-DirectoryObject -MockWith { @($A, $B) | Where-Object { $PSItem.DistinguishedName -eq $Identity } }
			$Result = Expand-GroupMember -Group $A -Path 'CORP\A'
			$Result | Should -HaveCount 2
		}

	}

}
