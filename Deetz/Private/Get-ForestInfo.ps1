function Get-ForestInfo {
	<#
	.SYNOPSIS
	Gets details of the target domain and the domains of its forest

	.DESCRIPTION
	Returns the target domain, the forest root domain and every reachable domain of the forest,
	each with DNSRoot, NetBIOSName, DistinguishedName and DomainSID.
	Throws when the target domain or its forest cannot be queried.
	A forest domain which cannot be queried is reported with a warning and left out.
	Domains outside the forest which any forest domain trusts are returned as Trusts, with the same properties.

	.PARAMETER Domain
	The target domain. Defaults to the domain of the current computer.

	.EXAMPLE
	Get-ForestInfo -Domain corp.local
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $false
		)]
		[string]$Domain
	)

	$Credential = Get-CredentialParameter
	$DomainParameter = @{} + $Credential

	if ($Domain) {
		$DomainParameter['Server'] = $Domain
	}

	try {
		$TargetDomain = Get-ADDomain @DomainParameter -ErrorAction Stop
		$Forest = Get-ADForest -Identity $TargetDomain.Forest -Server $TargetDomain.DNSRoot @Credential -ErrorAction Stop
	} catch {
		throw "Unable to query domain $Domain`: $($PSItem.Exception.Message)"
	}

	$Domains = @(
		foreach ($ForestDomain in $Forest.Domains) {

			try {
				Get-ADDomain -Identity $ForestDomain -Server $ForestDomain @Credential -ErrorAction Stop |
					Select-Object -Property DNSRoot, NetBIOSName, DistinguishedName, @{Name = 'DomainSID'; Expression = { "$($PSItem.DomainSID)" } }
			} catch {
				Write-Warning "Unable to query domain $ForestDomain`: $($PSItem.Exception.Message)"
			}

		}
	)

	$ForestRoot = $Domains | Where-Object { $PSItem.DNSRoot -eq $Forest.RootDomain }

	if (-not $ForestRoot) {
		Write-Warning "Forest root domain $($Forest.RootDomain) unavailable; forest level groups will not be checked"
	}

	$ForestSid = @($Domains | ForEach-Object { $PSItem.DomainSID })
	$Trusts = [ordered]@{}

	foreach ($ForestDomain in $Domains) {

		try {
			$TrustedDomain = Get-ADObject -LDAPFilter '(objectClass=trustedDomain)' -Server $ForestDomain.DNSRoot `
				-Properties trustPartner, flatName, securityIdentifier @Credential -ErrorAction Stop
		} catch {
			Write-Warning "Unable to query trusts of $($ForestDomain.DNSRoot): $($PSItem.Exception.Message)"
			continue
		}

		foreach ($Trust in $TrustedDomain) {

			if (-not $Trust.securityIdentifier) {
				continue
			}

			$TrustSid = if ($Trust.securityIdentifier -is [byte[]]) {
				"$(New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $Trust.securityIdentifier, 0)"
			} else {
				"$($Trust.securityIdentifier)"
			}

			if ($ForestSid -contains $TrustSid -or $Trusts.Contains($TrustSid)) {
				continue
			}

			$Trusts[$TrustSid] = [pscustomobject]@{
				DNSRoot           = $Trust.trustPartner
				NetBIOSName       = $Trust.flatName
				DistinguishedName = 'DC=' + ($Trust.trustPartner -replace '\.', ',DC=')
				DomainSID         = $TrustSid
			}

		}

	}

	[pscustomobject]@{
		Domain     = $Domains | Where-Object { $PSItem.DNSRoot -eq $TargetDomain.DNSRoot }
		ForestRoot = $ForestRoot
		Domains    = $Domains
		Trusts     = @($Trusts.Values)
	}

}
