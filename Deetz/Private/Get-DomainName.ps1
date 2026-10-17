function Get-DomainName {
	<#
	.SYNOPSIS
	Returns the DNS domain name of a distinguished name

	.DESCRIPTION
	Joins the DC= components of a distinguished name into a DNS domain name.

	.PARAMETER DistinguishedName
	The distinguished name of a directory object

	.EXAMPLE
	Get-DomainName -DistinguishedName 'CN=Administrator,CN=Users,DC=corp,DC=local'

	Returns corp.local
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

		(($DistinguishedName -split '(?<!\\),' | Where-Object { $PSItem -match '^DC=' }) -replace '^DC=') -join '.'

	}

}
