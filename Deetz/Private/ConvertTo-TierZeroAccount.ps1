function ConvertTo-TierZeroAccount {
	<#
	.SYNOPSIS
	Formats a registry entry as a Tier Zero account output object

	.DESCRIPTION
	Returns a Deetz.TierZeroAccount object holding every Deetz.TierZeroReason recorded for the account,
	with the distinct sources and Tier Zero groups of those reasons.
	Foreign security principals are translated to DOMAIN\name where the SID resolves,
	and given the DNS and NetBIOS names of the trusted domain which issued the SID.

	.PARAMETER Entry
	A registry entry created by Register-TierZeroAccount

	.PARAMETER Forest
	Forest details, as returned by Get-ForestInfo

	.EXAMPLE
	ConvertTo-TierZeroAccount -Entry $Entry -Forest $Forest
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
	$SID = "$($Object.objectSid)"
	$SamAccountName = $Object.sAMAccountName
	$DomainName = $null
	$NetBIOSDomain = $null

	if ($Object.ObjectClass -eq 'foreignSecurityPrincipal') {

		$TrustedDomain = Get-SidDomain -SID $SID -Forest $Forest -TrustOnly
		$DomainName = $TrustedDomain.DNSRoot
		$NetBIOSDomain = $TrustedDomain.NetBIOSName

		try {
			$NTAccount = ([System.Security.Principal.SecurityIdentifier]$SID).Translate([System.Security.Principal.NTAccount]).Value
			$NetBIOSDomain, $SamAccountName = $NTAccount -split '\\', 2
		} catch {
			Write-Verbose "Unable to translate foreign security principal $SID"
		}

	} else {

		$DomainName = Get-DomainName -DistinguishedName $Object.DistinguishedName
		$NetBIOSDomain = (@($Forest.Domains) + @($Forest.Trusts) | Where-Object { $PSItem.DNSRoot -eq $DomainName } | Select-Object -First 1).NetBIOSName

	}

	$UserAccountControl = $Object.userAccountControl

	[pscustomobject]@{
		SamAccountName       = $SamAccountName
		Domain               = $DomainName
		NetBIOSDomain        = $NetBIOSDomain
		UserPrincipalName    = $Object.userPrincipalName
		ObjectClass          = $Object.ObjectClass
		Enabled              = $(if ($null -ne $UserAccountControl) { -not ($UserAccountControl -band 2) })
		AdminCount           = $Object.adminCount
		PasswordLastSet      = $(if ($Object.pwdLastSet -gt 0) { [datetime]::FromFileTime($Object.pwdLastSet) })
		LastLogonDate        = $(if ($Object.lastLogonTimestamp -gt 0) { [datetime]::FromFileTime($Object.lastLogonTimestamp) })
		ServicePrincipalName = [string[]]@($Object.servicePrincipalName | Where-Object { $PSItem })
		Source               = [string[]]@($Entry.Reason.Source | Select-Object -Unique)
		TierZeroGroup        = [string[]]@($Entry.Reason.TierZeroGroup | Where-Object { $PSItem } | Select-Object -Unique)
		Reason               = [psobject[]]@($Entry.Reason)
		SID                  = $SID
		DistinguishedName    = $Object.DistinguishedName
	} | Add-CustomType -Type 'Deetz.TierZeroAccount'

}
