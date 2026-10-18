# .ExternalHelp Deetz-help.xml
function Get-TierZeroAccount {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $false
		)]
		[string]$Domain,

		[Parameter(
			Mandatory = $false
		)]
		[pscredential]$Credential,

		[Parameter(
			Mandatory = $false
		)]
		[string[]]$AdditionalGroup,

		[Parameter(
			Mandatory = $false
		)]
		[switch]$SkipAclAnalysis
	)

	$Result = Find-TierZeroObject @PSBoundParameters

	foreach ($Entry in $Result.Account.Values) {
		ConvertTo-TierZeroAccount -Entry $Entry -Forest $Result.Forest
	}

}
