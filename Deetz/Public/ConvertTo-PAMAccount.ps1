# .ExternalHelp Deetz-help.xml
function ConvertTo-PAMAccount {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[AllowEmptyString()]
		[string]$SamAccountName,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[AllowEmptyString()]
		[string]$Domain,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[AllowEmptyString()]
		[string]$ObjectClass,

		[Parameter(
			Mandatory = $true
		)]
		[string]$SafeName,

		[Parameter(
			Mandatory = $true
		)]
		[string]$PlatformID
	)

	process {

		if ($ObjectClass -ne 'user' -or -not $Domain -or -not $SamAccountName) {
			Write-Verbose "Skipping $ObjectClass $Domain\$SamAccountName"
			return
		}

		[pscustomobject]@{
			userName   = $SamAccountName
			address    = $Domain
			platformID = $PlatformID
			SafeName   = $SafeName
		}

	}

}
