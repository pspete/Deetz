# .ExternalHelp Deetz-help.xml
function Get-TierZeroGroup {
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

	foreach ($Entry in $Result.Group.Values) {
		ConvertTo-TierZeroGroup -Entry $Entry -Forest $Result.Forest
	}

}
