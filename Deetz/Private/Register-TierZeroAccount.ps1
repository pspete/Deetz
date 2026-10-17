function Register-TierZeroAccount {
	<#
	.SYNOPSIS
	Records a Tier Zero account and the reason it was found

	.DESCRIPTION
	Adds the account to the registry keyed on its SID (or distinguished name, where it has no SID),
	then adds a Deetz.TierZeroReason object describing how it was found to its entry, ignoring duplicate reasons.

	.PARAMETER Registry
	The dictionary of accounts found so far

	.PARAMETER Object
	The account directory object

	.PARAMETER Source
	How the account was found: GroupMembership, WellKnownAccount, ContainerACL or ObjectACL

	.PARAMETER TierZeroGroup
	The Tier Zero group, or group holding Tier Zero rights, through which the account was found

	.PARAMETER Path
	The chain of groups, from TierZeroGroup down to the group holding the account

	.PARAMETER Right
	The right held over the Target, such as GenericAll, Owner or managedBy

	.PARAMETER ObjectType
	The property, property set or extended right the Right applies to

	.PARAMETER Target
	Distinguished name of the Tier Zero container or object the Right is held over

	.EXAMPLE
	Register-TierZeroAccount -Registry $Registry -Object $User -Source GroupMembership -TierZeroGroup 'CORP\Domain Admins' -Path 'CORP\Domain Admins'

	.EXAMPLE
	Register-TierZeroAccount -Registry $Registry -Object $User -Source ContainerACL -Right GenericAll -ObjectType All -Target 'OU=Admins,DC=corp,DC=local'
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[System.Collections.IDictionary]$Registry,

		[Parameter(
			Mandatory = $true
		)]
		[psobject]$Object,

		[Parameter(
			Mandatory = $true
		)]
		[ValidateSet('GroupMembership', 'WellKnownAccount', 'ContainerACL', 'ObjectACL')]
		[string]$Source,

		[Parameter(
			Mandatory = $false
		)]
		[string]$TierZeroGroup,

		[Parameter(
			Mandatory = $false
		)]
		[string[]]$Path,

		[Parameter(
			Mandatory = $false
		)]
		[string]$Right,

		[Parameter(
			Mandatory = $false
		)]
		[string]$ObjectType,

		[Parameter(
			Mandatory = $false
		)]
		[string]$Target
	)

	$Key = "$($Object.objectSid)"

	if (-not $Key) {
		$Key = $Object.DistinguishedName
	}

	if (-not $Registry.Contains($Key)) {
		$Registry[$Key] = [pscustomobject]@{
			Object    = $Object
			Reason    = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
			ReasonKey = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
		}
	}

	$Entry = $Registry[$Key]

	if ($Entry.ReasonKey.Add(($Source, $TierZeroGroup, ($Path -join ' > '), $Right, $ObjectType, $Target) -join '|')) {
		$Entry.Reason.Add(
			([pscustomobject]@{
				Source        = $Source
				TierZeroGroup = $TierZeroGroup
				Path          = [string[]]@($Path | Where-Object { $PSItem })
				Right         = $Right
				ObjectType    = $ObjectType
				Target        = $Target
			} | Add-CustomType -Type 'Deetz.TierZeroReason')
		)
	}

}
