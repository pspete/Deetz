function Get-TierZeroGroupSeed {
	<#
	.SYNOPSIS
	Returns the SIDs of the default Tier Zero groups

	.DESCRIPTION
	Returns the SID of each default Tier Zero group, with the domain to query it from.
	The groups are those rated Tier Zero by the SpecterOps Tier Zero Table which can be identified by SID.
	Builtin and domain groups come from the target domain, forest groups from the forest root domain.

	.PARAMETER Forest
	Forest details, as returned by Get-ForestInfo

	.EXAMPLE
	Get-ForestInfo | Get-TierZeroGroupSeed
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[psobject]$Forest
	)

	process {

		$Domain = $Forest.Domain

		$BuiltinRid = @(
			544, # Administrators
			548, # Account Operators
			549, # Server Operators
			550, # Print Operators
			551, # Backup Operators
			557, # Incoming Forest Trust Builders
			559, # Performance Log Users
			562, # Distributed COM Users
			569  # Cryptographic Operators
		)

		$DomainRid = @(
			512, # Domain Admins
			516, # Domain Controllers
			517, # Cert Publishers
			526  # Key Admins
		)

		$ForestRid = @(
			518, # Schema Admins
			519, # Enterprise Admins
			527  # Enterprise Key Admins
		)

		foreach ($Rid in $BuiltinRid) {
			[pscustomobject]@{ SID = "S-1-5-32-$Rid"; Server = $Domain.DNSRoot }
		}

		foreach ($Rid in $DomainRid) {
			[pscustomobject]@{ SID = "$($Domain.DomainSID)-$Rid"; Server = $Domain.DNSRoot }
		}

		if ($Forest.ForestRoot) {
			foreach ($Rid in $ForestRid) {
				[pscustomobject]@{ SID = "$($Forest.ForestRoot.DomainSID)-$Rid"; Server = $Forest.ForestRoot.DNSRoot }
			}
		}

	}

}
