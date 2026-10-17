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

		It 'returns <Rights> on <ObjectType>' -TestCases @(
			@{ Rights = 'GenericAll'; ObjectType = $null; Expected = 'All' }
			@{ Rights = 'GenericWrite'; ObjectType = $null; Expected = 'All' }
			@{ Rights = 'WriteDacl'; ObjectType = $null; Expected = 'All' }
			@{ Rights = 'WriteOwner'; ObjectType = $null; Expected = 'All' }
			@{ Rights = 'ExtendedRight'; ObjectType = $null; Expected = 'All' }
			@{ Rights = 'ExtendedRight'; ObjectType = '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'; Expected = 'DS-Replication-Get-Changes-All' }
			@{ Rights = 'ExtendedRight'; ObjectType = '00299570-246d-11d0-a768-00aa006e0529'; Expected = 'User-Force-Change-Password' }
			@{ Rights = 'WriteProperty'; ObjectType = 'bf9679c0-0de6-11d0-a285-00aa003049e2'; Expected = 'member' }
			@{ Rights = 'WriteProperty'; ObjectType = '5b47d60f-6090-40b2-9f37-2a4de88f3063'; Expected = 'msDS-KeyCredentialLink' }
		) {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @{ SID = 'S-1-5-21-1-2-3-1105'; Rights = $Rights; ObjectType = $ObjectType }
			$Result = Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor
			$Result.SID | Should -Be 'S-1-5-21-1-2-3-1105'
			$Result.ObjectType | Should -Be $Expected
		}

		It 'ignores <Rights> on <ObjectType>' -TestCases @(
			@{ Rights = 'ReadProperty'; ObjectType = $null }
			@{ Rights = 'GenericRead'; ObjectType = $null }
			@{ Rights = 'WriteProperty'; ObjectType = 'bf967950-0de6-11d0-a285-00aa003049e2' }
			@{ Rights = 'ExtendedRight'; ObjectType = 'ab721a53-1e2f-11d0-9819-00aa0040529b' }
		) {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @{ SID = 'S-1-5-21-1-2-3-1105'; Rights = $Rights; ObjectType = $ObjectType }
			Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor | Should -BeNullOrEmpty
		}

		It 'ignores deny entries' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Rule @{ SID = 'S-1-5-21-1-2-3-1105'; Rights = 'GenericAll'; Type = 'Deny' }
			Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor | Should -BeNullOrEmpty
		}

		It 'returns the owner' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Owner 'S-1-5-21-1-2-3-1108'
			$Result = Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor
			$Result.SID | Should -Be 'S-1-5-21-1-2-3-1108'
			$Result.Rights | Should -Be 'Owner'
			$Result.ObjectType | Should -Be 'All'
		}

		It 'returns inherited entries' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Sddl 'D:(A;ID;0xf01ff;;;S-1-5-21-1-2-3-1105)'
			(Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor).SID | Should -Be 'S-1-5-21-1-2-3-1105'
		}

		It 'excludes inherited entries' {
			$SecurityDescriptor = New-TestSecurityDescriptor -Sddl 'D:(A;ID;0xf01ff;;;S-1-5-21-1-2-3-1105)' -Rule @{ SID = 'S-1-5-21-1-2-3-1106'; Rights = 'GenericAll' }
			(Get-PrivilegedAce -SecurityDescriptor $SecurityDescriptor -ExcludeInherited).SID | Should -Be 'S-1-5-21-1-2-3-1106'
		}

	}

}
