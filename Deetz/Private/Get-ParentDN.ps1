function Get-ParentDN {
	<#
	.SYNOPSIS
	Returns the distinguished name of the parent container of a directory object

	.DESCRIPTION
	Removes the first relative distinguished name from a distinguished name, honouring escaped commas.

	.PARAMETER DistinguishedName
	The distinguished name of a directory object

	.EXAMPLE
	Get-ParentDN -DistinguishedName 'CN=Smith\, John,OU=Admins,DC=corp,DC=local'

	Returns OU=Admins,DC=corp,DC=local
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[string]$DistinguishedName
	)

	process {

		$DistinguishedName -replace '^.+?(?<!\\),'

	}

}
