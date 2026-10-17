function Get-CredentialParameter {
	<#
	.SYNOPSIS
	Returns a splattable hashtable holding the session credential

	.DESCRIPTION
	Returns @{ Credential = <credential> } when a credential is held in the module session, otherwise an empty hashtable.

	.EXAMPLE
	$Credential = Get-CredentialParameter
	Get-ADDomain @Credential
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param()

	$Parameter = @{}

	if ($Script:DeetzSession.Credential) {
		$Parameter['Credential'] = $Script:DeetzSession.Credential
	}

	$Parameter

}
