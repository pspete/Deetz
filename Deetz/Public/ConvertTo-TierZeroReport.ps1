# .ExternalHelp Deetz-help.xml
function ConvertTo-TierZeroReport {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[psobject]$InputObject
	)

	process {

		$Account = [ordered]@{}

		foreach ($Property in $InputObject.PSObject.Properties) {
			if ($Property.Name -notin 'Reason', 'Source', 'TierZeroGroup') {
				$Account[$Property.Name] = $(if ($Property.Value -is [array]) { $Property.Value -join '; ' } else { $Property.Value })
			}
		}

		foreach ($Reason in $InputObject.Reason) {

			$Row = [ordered]@{} + $Account
			$Row['Source'] = $Reason.Source
			$Row['TierZeroGroup'] = $Reason.TierZeroGroup
			$Row['Path'] = @($Reason.Path) -join ' > '
			$Row['Right'] = $Reason.Right
			$Row['ObjectType'] = $Reason.ObjectType
			$Row['Target'] = $Reason.Target

			[pscustomobject]$Row

		}

	}

}
