---
external help file: Deetz-help.xml
Module Name: Deetz
online version:
schema: 2.0.0
---

# ConvertTo-PAMAccount

## SYNOPSIS
Formats Tier Zero accounts for onboarding to a PAM tool

## SYNTAX

```
ConvertTo-PAMAccount [-SamAccountName] <String> [-Domain] <String> [-ObjectClass] <String> [-SafeName] <String>
 [-PlatformID] <String> [<CommonParameters>]
```

## DESCRIPTION
Outputs an onboarding record for each Tier Zero user account, with userName, address, platformID and SafeName properties.

The output can be exported to CSV for bulk onboarding, or piped to the psPAS Add-PASAccount command.

Accounts which are not user objects, such as computers, managed service accounts and foreign security principals, are skipped.

## EXAMPLES

### Example 1
```
PS C:\> Get-TierZeroAccount | ConvertTo-PAMAccount -SafeName T0-Accounts -PlatformID WinDomain | Export-Csv -Path .\Onboard.csv -NoTypeInformation
```

Writes an onboarding file for every Tier Zero user account

### Example 2
```
PS C:\> Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount (Get-PASAccount) |
    Where-Object { -not $_.InPAM -and $_.Enabled } |
    ConvertTo-PAMAccount -SafeName T0-Accounts -PlatformID WinDomain |
    Add-PASAccount
```

Onboards every enabled Tier Zero user account not already held in CyberArk, using psPAS

## PARAMETERS

### -Domain
DNS domain name of the account, used as the address.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ObjectClass
Directory object class of the account.
Only user accounts are output.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PlatformID
ID of the PAM platform to assign to the accounts.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafeName
Name of the safe to onboard the accounts to.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SamAccountName
Logon name of the account, used as the user name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### System.Management.Automation.PSObject
## NOTES
No password is set; the PAM tool must reconcile or change the password after onboarding.

The built-in krbtgt accounts are user accounts and are output; exclude them where the PAM tool should not manage them.

## RELATED LINKS
