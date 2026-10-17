function Get-PrivilegedAce {
	<#
	.SYNOPSIS
	Returns the access control entries of a security descriptor which grant control of an object

	.DESCRIPTION
	Returns each Allow entry granting GenericAll, GenericWrite, WriteDacl or WriteOwner, and each Allow entry granting
	WriteProperty, Self or ExtendedRight either on all properties and rights or on one which allows takeover of the
	object or its domain (replication, password reset, group membership, key credentials, delegation, logon script).
	The owner of the object is returned with Rights Owner, as the owner can always change the permissions.

	.PARAMETER SecurityDescriptor
	The nTSecurityDescriptor of a directory object

	.PARAMETER ExcludeInherited
	Only return entries set on the object itself, not those inherited from its parent containers

	.EXAMPLE
	Get-PrivilegedAce -SecurityDescriptor $Object.nTSecurityDescriptor

	.EXAMPLE
	Get-PrivilegedAce -SecurityDescriptor $Object.nTSecurityDescriptor -ExcludeInherited
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[psobject]$SecurityDescriptor,

		[Parameter(
			Mandatory = $false
		)]
		[switch]$ExcludeInherited
	)

	$ObjectType = @{
		'00000000-0000-0000-0000-000000000000' = 'All'
		'1131f6aa-9c07-11d1-f79f-00c04fc2dcd2' = 'DS-Replication-Get-Changes'
		'1131f6ad-9c07-11d1-f79f-00c04fc2dcd2' = 'DS-Replication-Get-Changes-All'
		'89e95b76-444d-4c62-991a-0facbeda640c' = 'DS-Replication-Get-Changes-In-Filtered-Set'
		'00299570-246d-11d0-a768-00aa006e0529' = 'User-Force-Change-Password'
		'bf9679c0-0de6-11d0-a285-00aa003049e2' = 'member'
		'5b47d60f-6090-40b2-9f37-2a4de88f3063' = 'msDS-KeyCredentialLink'
		'f3a64788-5306-11d1-a9c5-0000f80367c1' = 'servicePrincipalName'
		'f30e3bbe-9ff0-11d1-b603-0000f80367c1' = 'gPLink'
		'3f78c3e5-f79a-46bd-a0b8-9d18116ddc79' = 'msDS-AllowedToActOnBehalfOfOtherIdentity'
		'bf9679a8-0de6-11d0-a285-00aa003049e2' = 'scriptPath'
		'bf967a68-0de6-11d0-a285-00aa003049e2' = 'userAccountControl'
	}

	$Owner = $SecurityDescriptor.GetOwner([System.Security.Principal.SecurityIdentifier])

	if ($Owner) {
		[pscustomobject]@{
			SID        = "$Owner"
			Rights     = 'Owner'
			ObjectType = 'All'
		}
	}

	$AccessRules = $SecurityDescriptor.GetAccessRules($true, -not $ExcludeInherited, [System.Security.Principal.SecurityIdentifier])

	foreach ($Ace in $AccessRules) {

		if ("$($Ace.AccessControlType)" -ne 'Allow') {
			continue
		}

		$Rights = "$($Ace.ActiveDirectoryRights)"
		$AceObjectType = "$($Ace.ObjectType)"

		if ($Rights -match 'GenericAll|GenericWrite|WriteDacl|WriteOwner') {
			$Target = 'All'
		} elseif (($Rights -match 'WriteProperty|Self|ExtendedRight') -and $ObjectType.ContainsKey($AceObjectType)) {
			$Target = $ObjectType[$AceObjectType]
		} else {
			continue
		}

		[pscustomobject]@{
			SID        = "$($Ace.IdentityReference)"
			Rights     = $Rights
			ObjectType = $Target
		}

	}

}
