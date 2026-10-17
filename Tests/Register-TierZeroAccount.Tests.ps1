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
			$Registry = [ordered]@{}
			$Object = [pscustomobject]@{ DistinguishedName = 'CN=alice,DC=corp,DC=local'; objectSid = 'S-1-5-21-1-2-3-1101' }
		}

		It 'adds an account keyed on SID' {
			Register-TierZeroAccount -Registry $Registry -Object $Object -TierZeroGroup 'CORP\Domain Admins' -Source GroupMembership -Path 'CORP\Domain Admins'
			$Registry.Keys | Should -Be 'S-1-5-21-1-2-3-1101'
		}

		It 'keys accounts without a SID on distinguished name' {
			$Object.objectSid = $null
			Register-TierZeroAccount -Registry $Registry -Object $Object -Source WellKnownAccount
			$Registry.Keys | Should -Be 'CN=alice,DC=corp,DC=local'
		}

		It 'combines reasons without duplicates' {
			Register-TierZeroAccount -Registry $Registry -Object $Object -TierZeroGroup 'CORP\Domain Admins' -Source GroupMembership -Path 'CORP\Domain Admins'
			Register-TierZeroAccount -Registry $Registry -Object $Object -TierZeroGroup 'CORP\Domain Admins' -Source GroupMembership -Path 'CORP\Domain Admins'
			Register-TierZeroAccount -Registry $Registry -Object $Object -TierZeroGroup 'BUILTIN\Administrators' -Source GroupMembership -Path 'BUILTIN\Administrators', 'CORP\Domain Admins'
			Register-TierZeroAccount -Registry $Registry -Object $Object -Source WellKnownAccount
			$Reason = $Registry['S-1-5-21-1-2-3-1101'].Reason
			$Reason | Should -HaveCount 3
			$Reason.Source | Should -Be @('GroupMembership', 'GroupMembership', 'WellKnownAccount')
			$Reason[1].Path | Should -Be @('BUILTIN\Administrators', 'CORP\Domain Admins')
		}

		It 'records rights as Deetz.TierZeroReason objects' {
			Register-TierZeroAccount -Registry $Registry -Object $Object -Source ObjectACL -Right Owner -ObjectType All -Target 'CN=bob,DC=corp,DC=local'
			$Reason = $Registry['S-1-5-21-1-2-3-1101'].Reason[0]
			$Reason.PSObject.TypeNames[0] | Should -Be 'Deetz.TierZeroReason'
			$Reason.Right | Should -Be 'Owner'
			$Reason.ObjectType | Should -Be 'All'
			$Reason.Target | Should -Be 'CN=bob,DC=corp,DC=local'
			$Reason.Path | Should -BeNullOrEmpty
		}

		It 'keeps the same right on different targets' {
			Register-TierZeroAccount -Registry $Registry -Object $Object -Source ObjectACL -Right Owner -ObjectType All -Target 'CN=bob,DC=corp,DC=local'
			Register-TierZeroAccount -Registry $Registry -Object $Object -Source ObjectACL -Right Owner -ObjectType All -Target 'CN=eve,DC=corp,DC=local'
			$Registry['S-1-5-21-1-2-3-1101'].Reason | Should -HaveCount 2
		}

	}

}
