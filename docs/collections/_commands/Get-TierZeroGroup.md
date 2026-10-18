---
external help file: Deetz-help.xml
Module Name: Deetz
online version:
schema: 2.0.0
---

# Get-TierZeroGroup

## SYNOPSIS
Lists the Tier Zero groups of an Active Directory domain

## SYNTAX

```
Get-TierZeroGroup [[-Domain] <String>] [[-Credential] <PSCredential>] [[-AdditionalGroup] <String[]>]
 [-SkipAclAnalysis] [<CommonParameters>]
```

## DESCRIPTION
Lists every group with Tier Zero access to a domain, with the reasons it was found.

Discovery is the same as Get-TierZeroAccount; this command outputs the groups found instead of their member accounts.

Groups are found five ways:

- DefaultGroup: the groups rated Tier Zero by the SpecterOps Tier Zero Table (https://specterops.github.io/TierZeroTable/) which can be identified by SID, in the domain and forest root.
- AdditionalGroup: groups named by the AdditionalGroup parameter.
- GroupMembership: groups nested, directly or through other groups, in a Tier Zero group, including groups in a trusted domain added through a foreign security principal.
- ContainerACL: groups granted control of the domain root, CN=Users, AdminSDHolder, the Domain Controllers OU, or a container holding a Tier Zero account or group.
- ObjectACL: groups granted control, or ownership, of a Tier Zero account or group object, groups managing a read-only domain controller, groups allowed to delegate to a Tier Zero computer, and groups allowed to retrieve the password of a Tier Zero group managed service account.

Default groups are not given ContainerACL or ObjectACL reasons, as they hold rights over most containers by default.

Each group is listed once, with a Reason property holding a Deetz.TierZeroReason object for every way it was found.
For GroupMembership reasons, Path is the chain of groups from TierZeroGroup down to the group holding this group.
For ContainerACL and ObjectACL reasons, Right, ObjectType and Target describe the right held; reasons from a group nested in a group holding the right also carry its TierZeroGroup and Path.

MemberCount is the number of direct members in the member attribute; it excludes members holding the group as their primary group.
Use ConvertTo-TierZeroReport to output one row per group per reason, for CSV export.

## EXAMPLES

### Example 1
```
PS C:\> Get-TierZeroGroup
```

Lists the Tier Zero groups of the current domain

### Example 2
```
PS C:\> Get-TierZeroGroup | Where-Object { $PSItem.Source -notcontains 'DefaultGroup' }
```

Lists the groups which are Tier Zero through nesting or rights, rather than by default

### Example 3
```
PS C:\> Get-TierZeroGroup | Where-Object { -not $PSItem.AdminCount }
```

Lists Tier Zero groups whose adminCount is not set, as they are not protected by AdminSDHolder

### Example 4
```
PS C:\> Get-TierZeroGroup -Domain child.corp.local | ConvertTo-TierZeroReport | Export-Csv -Path .\TierZeroGroups.csv -NoTypeInformation
```

Writes the Tier Zero groups of the child.corp.local domain, and every reason each was found, to a CSV file

## PARAMETERS

### -AdditionalGroup
Names of further groups to treat as Tier Zero, such as DnsAdmins or groups which administer Tier Zero systems.
Accepts any identity Get-ADGroup accepts in the target domain.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Credential used for all directory queries.
Defaults to the current user.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Domain
DNS name of the domain to check.
Defaults to the domain of the current computer.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipAclAnalysis
Find groups by default, additional and nested group only, without reading container or object security descriptors.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### Deetz.TierZeroGroup
## NOTES
Requires the ActiveDirectory module and read access to the domains of the forest.

The notes of Get-TierZeroAccount on broad principals, inherited entries, Group Policy objects and trusted domains apply.

## RELATED LINKS
