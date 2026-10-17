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
			$Script:DeetzSession.Cache = @{}
			Mock Get-ADObject -MockWith { [pscustomobject]@{ DistinguishedName = 'CN=alice,DC=corp,DC=local' } }
		}

		It 'queries the domain named in the distinguished name' {
			Get-DirectoryObject -Identity 'CN=alice,OU=Admins,DC=child,DC=corp,DC=local'
			Should -Invoke Get-ADObject -ParameterFilter { $Server -eq 'child.corp.local' } -Times 1 -Exactly -Scope It
		}

		It 'queries the specified server with an LDAP filter' {
			Get-DirectoryObject -LDAPFilter '(objectSid=S-1-5-32-544)' -Server 'corp.local'
			Should -Invoke Get-ADObject -ParameterFilter { $Server -eq 'corp.local' -and $LDAPFilter -eq '(objectSid=S-1-5-32-544)' } -Times 1 -Exactly -Scope It
		}

		It 'caches results' {
			$null = Get-DirectoryObject -Identity 'CN=alice,DC=corp,DC=local'
			$Result = Get-DirectoryObject -Identity 'CN=alice,DC=corp,DC=local'
			$Result.DistinguishedName | Should -Be 'CN=alice,DC=corp,DC=local'
			Should -Invoke Get-ADObject -Times 1 -Exactly -Scope It
		}

		It 'requests the specified properties' {
			Get-DirectoryObject -Identity 'CN=alice,DC=corp,DC=local' -Properties nTSecurityDescriptor
			Should -Invoke Get-ADObject -ParameterFilter { $Properties -contains 'nTSecurityDescriptor' } -Times 1 -Exactly -Scope It
		}

		It 'passes the session credential' {
			$Script:DeetzSession.Credential = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'x' -AsPlainText -Force))
			Get-DirectoryObject -Identity 'CN=alice,DC=corp,DC=local'
			$Script:DeetzSession.Credential = $null
			Should -Invoke Get-ADObject -ParameterFilter { $Credential.UserName -eq 'user' } -Times 1 -Exactly -Scope It
		}

		It 'warns and returns nothing on failure' {
			Mock Get-ADObject -MockWith { throw 'Server down' }
			$Result = Get-DirectoryObject -Identity 'CN=alice,DC=corp,DC=local' -WarningVariable Warnings -WarningAction SilentlyContinue
			$Result | Should -BeNullOrEmpty
			$Warnings | Should -Match 'Server down'
		}

	}

}
