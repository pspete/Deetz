---
external help file: Deetz-help.xml
Module Name: Deetz
online version:
schema: 2.0.0
---

# Compare-TierZeroAccount

## SYNOPSIS
Marks which Tier Zero accounts are held in a PAM tool

## SYNTAX

```
Compare-TierZeroAccount [-InputObject] <PSObject> [-PAMAccount] <PSObject[]> [[-UserNameProperty] <String>]
 [[-AddressProperty] <String>] [<CommonParameters>]
```

## DESCRIPTION
Outputs a copy of each Tier Zero account with an InPAM property, set to True where a PAM account matches it.

A PAM account matches when its user name and address match the SamAccountName and the DNS or NetBIOS domain name of the Tier Zero account.
A user name in DOMAIN\user or user@domain form matches on the domain in the user name, whatever the address.
A user name in user@domain form also matches the UserPrincipalName of the Tier Zero account.
Matching is case insensitive.

PAM accounts can come from any source, such as a CSV export or the psPAS Get-PASAccount command.

## EXAMPLES

### Example 1
```
PS C:\> $PAMAccounts = Get-PASAccount
PS C:\> Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount $PAMAccounts | Where-Object { -not $_.InPAM }
```

Lists the Tier Zero accounts not held in CyberArk, using psPAS

### Example 2
```
PS C:\> $PAMAccounts = Import-Csv -Path .\PAMExport.csv
PS C:\> Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount $PAMAccounts -UserNameProperty Account -AddressProperty Domain | Export-Csv -Path .\Coverage.csv -NoTypeInformation
```

Writes the PAM coverage of each Tier Zero account to a CSV file, matching against an export with Account and Domain columns

### Example 3
```
PS C:\> Import-Csv -Path .\TierZero.csv | Compare-TierZeroAccount -PAMAccount $PAMAccounts
```

Checks a previously saved Tier Zero account list

## PARAMETERS

### -AddressProperty
Name of the PAM account property holding the domain of the account.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: address
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
Tier Zero account, as output by Get-TierZeroAccount or read from a CSV file it was exported to.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -PAMAccount
Accounts held in the PAM tool.
An empty list marks every account as not held.

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserNameProperty
Name of the PAM account property holding the user name of the account.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: userName
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.PSObject
## OUTPUTS

### System.Management.Automation.PSObject
## NOTES
Each input object is output as a copy with the InPAM property added, replacing any existing InPAM property; the input objects are not changed, so the same accounts can be compared more than once.

The defaults for -UserNameProperty and -AddressProperty match the account objects returned by psPAS.

## RELATED LINKS
