function ConvertTo-TierZeroGroup {
	<#
	.SYNOPSIS
	Formats a registry entry as a Tier Zero group output object

	.DESCRIPTION
	Returns a Deetz.TierZeroGroup object holding every Deetz.TierZeroReason recorded for the group,
	with the distinct sources and Tier Zero groups of those reasons.

	.PARAMETER Entry
	A registry entry created by Register-TierZeroAccount

	.PARAMETER Forest
	Forest details, as returned by Get-ForestInfo

	.EXAMPLE
	ConvertTo-TierZeroGroup -Entry $Entry -Forest $Forest
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[psobject]$Entry,

		[Parameter(
			Mandatory = $true
		)]
		[psobject]$Forest
	)

	$Object = $Entry.Object
	$DomainName = Get-DomainName -DistinguishedName $Object.DistinguishedName

	[pscustomobject]@{
		SamAccountName    = $Object.sAMAccountName
		Domain            = $DomainName
		NetBIOSDomain     = (@($Forest.Domains) + @($Forest.Trusts) | Where-Object { $PSItem.DNSRoot -eq $DomainName } | Select-Object -First 1).NetBIOSName
		AdminCount        = $Object.adminCount
		MemberCount       = @($Object.member | Where-Object { $PSItem }).Count
		Source            = [string[]]@($Entry.Reason.Source | Select-Object -Unique)
		TierZeroGroup     = [string[]]@($Entry.Reason.TierZeroGroup | Where-Object { $PSItem } | Select-Object -Unique)
		Reason            = [psobject[]]@($Entry.Reason)
		SID               = "$($Object.objectSid)"
		DistinguishedName = $Object.DistinguishedName
	} | Add-CustomType -Type 'Deetz.TierZeroGroup'

}
