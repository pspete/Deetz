# .ExternalHelp Deetz-help.xml
function Compare-TierZeroAccount {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[psobject]$InputObject,

		[Parameter(
			Mandatory = $true
		)]
		[AllowEmptyCollection()]
		[psobject[]]$PAMAccount,

		[Parameter(
			Mandatory = $false
		)]
		[string]$UserNameProperty = 'userName',

		[Parameter(
			Mandatory = $false
		)]
		[string]$AddressProperty = 'address'
	)

	begin {

		$Keys = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)

		foreach ($Account in $PAMAccount) {

			$UserName = "$($Account.$UserNameProperty)"
			$Address = "$($Account.$AddressProperty)"

			if ($UserName -match '^(?<Domain>[^\\]+)\\(?<User>.+)$') {
				$null = $Keys.Add("$($Matches.User)|$($Matches.Domain)")
			} elseif ($UserName -match '^(?<User>[^@]+)@(?<Domain>.+)$') {
				$null = $Keys.Add("upn|$UserName")
				$null = $Keys.Add("$($Matches.User)|$($Matches.Domain)")
			} else {
				$null = $Keys.Add("$UserName|$Address")
			}

		}

	}

	process {

		$InPAM = $false

		foreach ($Key in @(
				"$($InputObject.SamAccountName)|$($InputObject.Domain)",
				"$($InputObject.SamAccountName)|$($InputObject.NetBIOSDomain)",
				"upn|$($InputObject.UserPrincipalName)"
			)) {

			if ($Key -notmatch '^\|' -and $Key -notmatch '\|$' -and $Keys.Contains($Key)) {
				$InPAM = $true
				break
			}

		}

		$InputObject | Add-Member -MemberType NoteProperty -Name InPAM -Value $InPAM -Force -PassThru

	}

}
