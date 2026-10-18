---
external help file: Deetz-help.xml
Module Name: Deetz
online version:
schema: 2.0.0
---

# Get-TierZeroAccount

## SYNOPSIS
Lists the Tier Zero accounts of an Active Directory domain

## SYNTAX

```
Get-TierZeroAccount [[-Domain] <String>] [[-Credential] <PSCredential>] [[-AdditionalGroup] <String[]>]
 [-SkipAclAnalysis] [<CommonParameters>]
```

## DESCRIPTION
Lists every account with Tier Zero access to a domain, with the reasons it was found.

Accounts are found three ways:

- GroupMembership: direct, nested and primary group members of the default Tier Zero groups and of any additional groups.
The default groups are those rated Tier Zero by the SpecterOps Tier Zero Table (https://specterops.github.io/TierZeroTable/) which can be identified by SID: Administrators, Account Operators, Server Operators, Print Operators, Backup Operators, Incoming Forest Trust Builders, Performance Log Users, Distributed COM Users, Cryptographic Operators, Domain Admins, Domain Controllers, Cert Publishers, Key Admins, plus the forest root groups Enterprise Admins, Schema Admins and Enterprise Key Admins.
- WellKnownAccount: the built-in Administrator account, the krbtgt accounts, and read-only domain controller computer accounts.
- ContainerACL: principals granted control (GenericAll, GenericWrite, WriteDacl, WriteOwner, or a write or extended right which allows takeover) of the domain root, CN=Users, AdminSDHolder, the Domain Controllers OU, and every container holding a Tier Zero account or group.
- ObjectACL: principals granted the same control of a Tier Zero account or group object itself, by an entry set on the object or by owning it, the managedBy principal of a read-only domain controller, principals listed in msDS-AllowedToActOnBehalfOfOtherIdentity (resource-based constrained delegation) of a Tier Zero object, and principals listed in msDS-GroupMSAMembership of a Tier Zero group managed service account.
Owners are treated as having full control, as an owner can always change the permissions.
Groups found by ContainerACL or ObjectACL are expanded, and the accounts and groups found are checked in turn until no new principal is found.

Each account is listed once, with a Reason property holding a Deetz.TierZeroReason object for every way it was found:

- Source: GroupMembership, WellKnownAccount, ContainerACL or ObjectACL.
- TierZeroGroup: the Tier Zero group, or the group granted a right, through which the account was found.
- Path: the chain of groups from TierZeroGroup down to the group holding the account.
- Right and ObjectType: the right held, such as GenericAll (All), WriteProperty (member), Owner (All), managedBy, AllowedToAct or ReadGMSAPassword.
- Target: the container or object the right is held over.

The Source and TierZeroGroup properties of the account list the distinct values of its reasons.
The table view summarises the reasons by source, such as GroupMembership (2), ObjectACL (1).
Use ConvertTo-TierZeroReport to output one row per account per reason, for CSV export.
Groups are not listed; their members are.
Use Get-TierZeroGroup to list the Tier Zero groups.

## EXAMPLES

### Example 1
```
PS C:\> Get-TierZeroAccount
```

Lists the Tier Zero accounts of the current domain

### Example 2
```
PS C:\> Get-TierZeroAccount -Domain child.corp.local -Credential (Get-Credential) | ConvertTo-TierZeroReport | Export-Csv -Path .\TierZero.csv -NoTypeInformation
```

Writes the Tier Zero accounts of the child.corp.local domain, and every reason each was found, to a CSV file

### Example 3
```
PS C:\> Get-TierZeroAccount -AdditionalGroup DnsAdmins, 'Exchange Trusted Subsystem'
```

Lists the Tier Zero accounts of the current domain, treating members of DnsAdmins and Exchange Trusted Subsystem as Tier Zero

### Example 4
```
PS C:\> Get-TierZeroAccount -SkipAclAnalysis -Verbose
```

Lists the Tier Zero accounts found by group membership only, reporting each group as it is checked

### Example 5
```
PS C:\> (Get-TierZeroAccount | Where-Object SamAccountName -eq 'alice').Reason
```

Lists every reason the alice account was found

## PARAMETERS

### -AdditionalGroup
Names of further groups whose members are Tier Zero, such as DnsAdmins or groups which administer Tier Zero systems.
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
Find accounts by group membership and well known account only, without reading container or object security descriptors.

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

### Deetz.TierZeroAccount
## NOTES
Requires the ActiveDirectory module and read access to the domains of the forest.

Forest level groups are read from the forest root domain.
A forest domain which cannot be queried is reported with a warning, and principals from it are not resolved.

Everyone, Anonymous Logon, Authenticated Users, Domain Users, Domain Computers, Users, Guests and Pre-Windows 2000 Compatible Access are not expanded when found in an ACL; a warning is written instead, since every account would be Tier Zero.

Only entries set directly on a Tier Zero account or group object are reported as ObjectACL; inherited entries are found through the container they are set on.
The ACLs of Group Policy objects are not analysed.
Access control entries scoped to a specific child object type are treated as applying to all objects.

Foreign security principals are listed, translated to DOMAIN\name where the SID resolves.
Foreign security principals for groups in a trusted domain are expanded in that domain where it can be read.

## RELATED LINKS
