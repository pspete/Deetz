function Expand-GroupMember {
	<#
	.SYNOPSIS
	Recursively expands the membership of a group

	.DESCRIPTION
	Outputs every direct and nested member of a group, including groups, as an object holding the member
	and the chain of group names, from the outermost group down, through which it is a member.
	Members which hold the group as their primary group are included for domain groups.
	Groups already expanded in the same call are not expanded again, so circular nesting terminates.
	Foreign security principals for groups in a trusted domain are expanded in that domain when Forest is supplied,
	and the trusted domain group is output after the foreign security principal.

	.PARAMETER Group
	The group directory object, with member and objectSid properties

	.PARAMETER Path
	The chain of group names leading to this group

	.PARAMETER Visited
	Distinguished names of groups already expanded

	.PARAMETER Forest
	Forest details, as returned by Get-ForestInfo, used to find the trusted domain of a foreign security principal

	.EXAMPLE
	Expand-GroupMember -Group $Group -Path 'Administrators'
	#>
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true
		)]
		[psobject]$Group,

		[Parameter(
			Mandatory = $true
		)]
		[string[]]$Path,

		[Parameter(
			Mandatory = $false
		)]
		[System.Collections.Generic.HashSet[string]]$Visited = (New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)),

		[Parameter(
			Mandatory = $false
		)]
		[psobject]$Forest
	)

	if (-not $Visited.Add($Group.DistinguishedName)) {
		return
	}

	$GroupSid = "$($Group.objectSid)"

	$Members = @(
		foreach ($MemberDN in $Group.member) {
			Get-DirectoryObject -Identity $MemberDN
		}

		if ($GroupSid -match '^S-1-5-21-.+-(\d+)$') {
			Get-DirectoryObject -LDAPFilter "(primaryGroupID=$($Matches[1]))" -Server (Get-DomainName -DistinguishedName $Group.DistinguishedName)
		}
	)

	foreach ($Member in $Members) {

		[pscustomobject]@{
			Object = $Member
			Path   = $Path
		}

		$NestedGroup = $null

		if ($Member.ObjectClass -eq 'group') {
			$NestedGroup = $Member
		} elseif ($Member.ObjectClass -eq 'foreignSecurityPrincipal' -and $Forest) {

			$MemberSid = "$($Member.objectSid)"
			$TrustedDomain = Get-SidDomain -SID $MemberSid -Forest $Forest -TrustOnly

			if ($TrustedDomain) {
				$Foreign = Get-DirectoryObject -LDAPFilter "(objectSid=$MemberSid)" -Server $TrustedDomain.DNSRoot | Select-Object -First 1
				if ($Foreign.ObjectClass -eq 'group') {
					$NestedGroup = $Foreign
					[pscustomobject]@{
						Object = $Foreign
						Path   = $Path
					}
				}
			}

		}

		if ($NestedGroup) {
			Write-Verbose "`tChecking Nested Group: $($NestedGroup.'msDS-PrincipalName')"
			Expand-GroupMember -Group $NestedGroup -Path (@($Path) + $NestedGroup.'msDS-PrincipalName') -Visited $Visited -Forest $Forest
		}

	}

}
