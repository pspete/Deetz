function Get-DirectoryObject {
	<#
	.SYNOPSIS
	Gets directory objects, caching results for the current discovery run

	.DESCRIPTION
	Wraps Get-ADObject. An Identity lookup targets the domain named by the DC= components of the distinguished name.
	Results are cached in the module session, keyed on server, query and properties.
	Lookups of an identity which does not exist return nothing and write a warning.

	.PARAMETER Identity
	The distinguished name of the object to get

	.PARAMETER LDAPFilter
	An LDAP filter to search with

	.PARAMETER Server
	The domain to search with the LDAP filter

	.PARAMETER Properties
	The properties to return

	.EXAMPLE
	Get-DirectoryObject -Identity 'CN=Domain Admins,CN=Users,DC=corp,DC=local'

	.EXAMPLE
	Get-DirectoryObject -LDAPFilter '(objectSid=S-1-5-32-544)' -Server corp.local
	#>
	[CmdletBinding(DefaultParameterSetName = 'Identity')]
	param(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = 'Identity'
		)]
		[string]$Identity,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = 'LDAPFilter'
		)]
		[string]$LDAPFilter,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = 'LDAPFilter'
		)]
		[string]$Server,

		[Parameter(
			Mandatory = $false
		)]
		[string[]]$Properties = @(
			'msDS-PrincipalName',
			'sAMAccountName',
			'userPrincipalName',
			'objectSid',
			'userAccountControl',
			'pwdLastSet',
			'lastLogonTimestamp',
			'servicePrincipalName',
			'adminCount',
			'member'
		)
	)

	$Parameter = @{ Properties = $Properties } + (Get-CredentialParameter)

	switch ($PSCmdlet.ParameterSetName) {

		'Identity' {
			$Parameter['Identity'] = $Identity
			$Parameter['Server'] = Get-DomainName -DistinguishedName $Identity
		}

		'LDAPFilter' {
			$Parameter['LDAPFilter'] = $LDAPFilter
			$Parameter['Server'] = $Server
		}

	}

	$Key = '{0}|{1}{2}|{3}' -f $Parameter['Server'], $Identity, $LDAPFilter, ($Properties -join ',')

	if (-not $Script:DeetzSession.Cache.ContainsKey($Key)) {

		try {
			$Script:DeetzSession.Cache[$Key] = @(Get-ADObject @Parameter -ErrorAction Stop)
		} catch {
			Write-Warning "Unable to get directory object $Identity$LDAPFilter from $($Parameter['Server']): $($PSItem.Exception.Message)"
			$Script:DeetzSession.Cache[$Key] = @()
		}

	}

	$Script:DeetzSession.Cache[$Key]

}
