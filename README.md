# Deetz

![Deetz: Tier Zero](media/Deetz-logo.svg)

**Deetz** is a PowerShell module that enumerates the Tier Zero accounts of an Active Directory domain, so they can be checked against, or onboarded to, a privileged access management (PAM) tool.

Deetz is inspired by the [SpecterOps Tier Zero Table](https://specterops.github.io/TierZeroTable/), the community catalogue of which Active Directory assets are Tier Zero, and why. The groups the Table rates Tier Zero are where Deetz starts, and the Table's principle that anything with control of a Tier Zero asset is itself Tier Zero drives its ACL analysis. Deetz takes the Table from reference to inventory: the accounts in a real domain, each with the reason it is Tier Zero.

| Main Branch              | CodeFactor                 | Coverage                     | PowerShell Gallery        | License                      |
| ------------------------ | -------------------------- | ---------------------------- | ------------------------- | ---------------------------- |
| [![build][]][build-site] | [![codefactor][]][cf-site] | [![codecov][]][codecov-link] | [![psgallery][]][ps-site] | [![license][]][license-link] |

[build]: https://github.com/pspete/Deetz/actions/workflows/ci.yml/badge.svg?branch=main&event=push
[build-site]: https://github.com/pspete/Deetz/actions/workflows/ci.yml?query=branch%3Amain
[psgallery]: https://img.shields.io/powershellgallery/v/Deetz.svg
[ps-site]: https://www.powershellgallery.com/packages/Deetz
[downloads]: https://img.shields.io/powershellgallery/dt/Deetz.svg?color=blue
[cf-site]: https://www.codefactor.io/repository/github/pspete/Deetz
[codefactor]: https://www.codefactor.io/repository/github/pspete/Deetz/badge
[codecov]: https://codecov.io/gh/pspete/Deetz/branch/main/graph/badge.svg
[codecov-link]: https://codecov.io/gh/pspete/Deetz
[license]: https://img.shields.io/github/license/pspete/Deetz.svg
[license-link]: https://github.com/pspete/Deetz/blob/main/LICENSE

## Using the Module

### Discover Tier Zero Accounts

`Get-TierZeroAccount` lists every account with Tier Zero access to a domain, and why it was found.

```powershell
Get-TierZeroAccount

Get-TierZeroAccount -Domain child.corp.local -Credential (Get-Credential)

Get-TierZeroAccount -AdditionalGroup DnsAdmins, 'Exchange Trusted Subsystem'
```

Accounts are found by:

- **GroupMembership**: direct, nested and primary group members of the groups the [Tier Zero Table](https://specterops.github.io/TierZeroTable/) rates Tier Zero, in the domain and forest root, plus any `-AdditionalGroup`.
- **WellKnownAccount**: the built-in Administrator and krbtgt accounts, and read-only domain controller computer accounts.
- **ContainerACL**: following the Tier Zero Table's control principle, principals with control of the domain root, `CN=Users`, `AdminSDHolder`, the `Domain Controllers` OU, and every container holding a Tier Zero account or group.
- **ObjectACL**: principals with control, or ownership, of a Tier Zero account or group object, and managers of read-only domain controllers. Principals found by ACL are checked in turn until nothing new is found.

Use `-SkipAclAnalysis` for group membership and well known accounts only.

Each account is listed once. Its `Reason` property holds one entry for every way it was found, with `Source`, `TierZeroGroup`, `Path` (the chain of groups), `Right`, `ObjectType` and `Target` (the container or object the right is held over). The table view summarises reasons by source:

```powershell
(Get-TierZeroAccount | Where-Object SamAccountName -eq 'alice').Reason
```

### Export the Account List

`ConvertTo-TierZeroReport` outputs one row per account per reason:

```powershell
Get-TierZeroAccount | ConvertTo-TierZeroReport | Export-Csv -Path .\TierZero.csv -NoTypeInformation
```

### Check PAM Coverage

`Compare-TierZeroAccount` adds an `InPAM` property to each Tier Zero account.

PAM accounts can come from any source. The defaults match psPAS account objects:

```powershell
$PAMAccounts = Get-PASAccount
Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount $PAMAccounts | Where-Object { -not $_.InPAM }
```

For an export from any other PAM tool, name the user name and address columns:

```powershell
$PAMAccounts = Import-Csv -Path .\PAMExport.csv
Get-TierZeroAccount |
    Compare-TierZeroAccount -PAMAccount $PAMAccounts -UserNameProperty Account -AddressProperty Domain |
    ConvertTo-TierZeroReport |
    Export-Csv -Path .\Coverage.csv -NoTypeInformation
```

### Onboard to PAM

`ConvertTo-PAMAccount` outputs `userName`, `address`, `platformID` and `SafeName` for each Tier Zero user account.

Write an onboarding file:

```powershell
Get-TierZeroAccount |
    ConvertTo-PAMAccount -SafeName T0-Accounts -PlatformID WinDomain |
    Export-Csv -Path .\Onboard.csv -NoTypeInformation
```

Onboard missing accounts directly with psPAS:

```powershell
Get-TierZeroAccount | Compare-TierZeroAccount -PAMAccount (Get-PASAccount) |
    Where-Object { -not $_.InPAM -and $_.Enabled } |
    ConvertTo-PAMAccount -SafeName T0-Accounts -PlatformID WinDomain |
    Add-PASAccount
```

No password is set; the PAM tool must reconcile or change the password after onboarding.

## Module Commands

| Command                    | Description                                           |
| -------------------------- | ----------------------------------------------------- |
| `Get-TierZeroAccount`      | Lists the Tier Zero accounts of an AD domain          |
| `ConvertTo-TierZeroReport` | Outputs one row per Tier Zero account per reason      |
| `Compare-TierZeroAccount`  | Marks which Tier Zero accounts are held in a PAM tool |
| `ConvertTo-PAMAccount`     | Formats Tier Zero accounts for onboarding to PAM      |

## Installation

### Prerequisites

- Requires Powershell Core (recommended), or Windows PowerShell (version 5.1)
- The ActiveDirectory module (RSAT)
- Read access to the domains of the forest: any domain user account has this by default, and no administrative rights are needed
  - Trusted domains outside the forest are read only where they accept the account; a domain trusted one way only (this domain trusts it, it does not trust this domain) needs a run with a credential from that domain
  - Where read access has been restricted, objects whose permissions cannot be read are reported with a warning
- [psPAS](https://github.com/pspete/psPAS) (optional), for CyberArk coverage checks and onboarding

### Install Options

Users can install Deetz from GitHub or the PowerShell Gallery.

Choose any of the following ways to download the module and install it:

#### Option 1: Install from PowerShell Gallery

This is the easiest and most popular way to install the module:

1. Open a PowerShell prompt

2. Run the following command:

```powershell
Install-Module -Name Deetz -Scope CurrentUser
```

#### Option 2: Manual Install

The module files can be manually copied to one of your PowerShell module directories.

Use the following command to get the paths to your local PowerShell module folders:

```powershell

$env:PSModulePath.split(';')

```

The module files must be placed in one of the listed directories, in a folder called `Deetz`.

More: [about_PSModulePath](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath)

The module files are available to download using a variety of methods:

##### PowerShell Gallery

- Download from the module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Deetz/):
  - Run the PowerShell command `Save-Module -Name Deetz -Path C:\temp`
  - Copy the `C:\temp\Deetz` folder to your "Powershell Modules" directory of choice.

##### Deetz Release

- [Download the latest GitHub release](https://github.com/pspete/Deetz/releases/latest)
  - Unblock & Extract the archive
  - Rename the extracted `Deetz-v#.#.#` folder to `Deetz`
  - Copy the `Deetz` folder to your "Powershell Modules" directory of choice.

##### Deetz Branch

- [Download the `main` branch](https://github.com/pspete/Deetz/archive/refs/heads/main.zip)
  - Unblock & Extract the archive
  - Copy the `Deetz` (`\<Archive Root>\Deetz-main\Deetz`) folder to your "Powershell Modules" directory of choice.

#### Verification

Validate Install:

```powershell

Get-Module -ListAvailable Deetz

```

Import the module:

```powershell

Import-Module Deetz

```

List Module Commands:

```powershell

Get-Command -Module Deetz

```

Get detailed information on specific commands:

```powershell

Get-Help Get-TierZeroAccount -Full

```

## Sponsorship

Please support continued development; consider sponsoring <a href="https://github.com/sponsors/pspete"> @pspete on GitHub Sponsors</a>

## Changelog

All notable changes to this project will be documented in the [Changelog](CHANGELOG.md)

## Author

- **Pete Maan** - [pspete](https://github.com/pspete)

## License

This project is [licensed under the MIT License](LICENSE).

## Contributing

Any and all contributions to this project are appreciated.

See the [CONTRIBUTING.md](CONTRIBUTING.md) for a few more details.

## References

- [Appendix B: Privileged Accounts and Groups in Active Directory](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory)
- [What is Tier Zero, Part 1](https://posts.specterops.io/what-is-tier-zero-part-1-e0da9b7cdfca) / [Part 2](https://posts.specterops.io/what-is-tier-zero-part-2-6e1d14fddcaf)
- [SpecterOps Tier Zero Table](https://specterops.github.io/TierZeroTable/): the inspiration for Deetz, and the source of its default Tier Zero groups
- A Hitch-hacker's Guide to DACL-Based Detections: [Part 1A](https://trustedsec.com/blog/a-hitchhackers-guide-to-dacl-based-detections-part-1-a), [Part 1B](https://trustedsec.com/blog/a-hitch-hackers-guide-to-dacl-based-detections-part-1b), [Part 2](https://trustedsec.com/blog/a-hitch-hackers-guide-to-dacl-based-detections-part-2), [Part 3](https://trustedsec.com/blog/a-hitch-hackers-guide-to-dacl-based-detections-part-3)
- [The Hacker Recipes: DACL abuse](https://www.thehacker.recipes/ad/movement/dacl)
