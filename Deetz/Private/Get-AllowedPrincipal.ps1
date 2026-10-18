function Get-AllowedPrincipal {
	<#
	.SYNOPSIS
	Returns the SIDs granted access by a security descriptor attribute

	.DESCRIPTION
	Returns the distinct SIDs of the Allow entries of a security descriptor stored in an attribute,
	such as msDS-AllowedToActOnBehalfOfOtherIdentity or msDS-GroupMSAMembership.
	Accepts the attribute as returned by Get-ADObject, or in binary form.

	.PARAMETER SecurityDescriptor
	The attribute value

	.EXAMPLE
	Get-AllowedPrincipal -SecurityDescriptor $Computer.'msDS-AllowedToActOnBehalfOfOtherIdentity'
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[psobject]$SecurityDescriptor
	)

	$Descriptor = $SecurityDescriptor

	if ($Descriptor -is [byte[]]) {
		$Descriptor = New-Object -TypeName System.DirectoryServices.ActiveDirectorySecurity
		$Descriptor.SetSecurityDescriptorBinaryForm([byte[]]$SecurityDescriptor)
	}

	$Descriptor.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
		Where-Object { "$($PSItem.AccessControlType)" -eq 'Allow' } |
		ForEach-Object { "$($PSItem.IdentityReference)" } |
		Select-Object -Unique

}
