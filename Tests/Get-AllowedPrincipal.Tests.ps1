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

		It 'returns the SIDs of Allow entries' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @(
				@{ SID = 'S-1-5-21-1-2-3-1105'; Rights = 'GenericAll' },
				@{ SID = 'S-1-5-21-1-2-3-1106'; Rights = 'GenericAll'; Type = 'Deny' }
			)
			Get-AllowedPrincipal -SecurityDescriptor $SecurityDescriptor | Should -Be 'S-1-5-21-1-2-3-1105'
		}

		It 'returns each SID once' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @(
				@{ SID = 'S-1-5-21-1-2-3-1105'; Rights = 'GenericAll' },
				@{ SID = 'S-1-5-21-1-2-3-1105'; Rights = 'ReadProperty'; ObjectType = 'bf9679c0-0de6-11d0-a285-00aa003049e2' }
			)
			Get-AllowedPrincipal -SecurityDescriptor $SecurityDescriptor | Should -HaveCount 1
		}

		It 'accepts the binary form' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @{ SID = 'S-1-5-21-1-2-3-1105'; Rights = 'GenericAll' }
			Get-AllowedPrincipal -SecurityDescriptor $SecurityDescriptor.GetSecurityDescriptorBinaryForm() | Should -Be 'S-1-5-21-1-2-3-1105'
		}

	}

}
