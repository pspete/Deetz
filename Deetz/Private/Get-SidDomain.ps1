function Get-SidDomain {
	<#
	.SYNOPSIS
	Returns the forest or trusted domain which issued a SID

	.DESCRIPTION
	Matches the SID against the domain SIDs of the forest domains and the
	trusted domains returned by Get-ForestInfo; with TrustOnly, only the trusted domains. Returns nothing for builtin, well-known or unknown SIDs.

	.PARAMETER SID
	The security identifier to look up

	.PARAMETER Forest
	Forest details, as returned by Get-ForestInfo

	.PARAMETER TrustOnly
	Only match trusted domains outside the forest

	.EXAMPLE
	Get-SidDomain -SID 'S-1-5-21-1-2-3-1105' -Forest $Forest
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[string]$SID,

		[Parameter(
			Mandatory = $true
		)]
		[psobject]$Forest,

		[Parameter(
			Mandatory = $false
		)]
		[switch]$TrustOnly
	)

	$Candidates = @(
		if (-not $TrustOnly) { $Forest.Domains }
		$Forest.Trusts
	)

	$Candidates | Where-Object { $PSItem.DomainSID -and $SID -like "$($PSItem.DomainSID)-*" } | Select-Object -First 1

}
