---
external help file: Deetz-help.xml
Module Name: Deetz
online version:
schema: 2.0.0
---

# ConvertTo-TierZeroReport

## SYNOPSIS
Outputs one row per Tier Zero account per reason

## SYNTAX

```
ConvertTo-TierZeroReport [-InputObject] <PSObject> [<CommonParameters>]
```

## DESCRIPTION
Flattens Tier Zero accounts into one row for each reason the account was found, for CSV export or review in a spreadsheet.

Each row holds the properties of the account, with multi-valued properties joined by '; ', followed by the Source, TierZeroGroup, Path, Right, ObjectType and Target of the reason.
Path is the chain of groups joined by ' > '.

Properties added to the account by other commands, such as InPAM from Compare-TierZeroAccount, are kept.

## EXAMPLES

### Example 1
```
PS C:\> Get-TierZeroAccount | ConvertTo-TierZeroReport | Export-Csv -Path .\TierZero.csv -NoTypeInformation
```

Writes every Tier Zero account, and every reason each was found, to a CSV file

### Example 2
```
PS C:\> Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount (Get-PASAccount) | ConvertTo-TierZeroReport | Export-Csv -Path .\Coverage.csv -NoTypeInformation
```

Writes the Tier Zero accounts, their reasons and whether each is held in CyberArk to a CSV file

## PARAMETERS

### -InputObject
A Tier Zero account, as output by Get-TierZeroAccount.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Deetz.TierZeroAccount
## OUTPUTS

### System.Management.Automation.PSObject
## NOTES

## RELATED LINKS
