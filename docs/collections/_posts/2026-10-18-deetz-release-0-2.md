---
title: "Deetz Release 0.2"
date: 2026-10-18 00:00:00
version: 0.2.1
tags:
  - Release Notes
  - Get-TierZeroGroup
  - Get-TierZeroAccount
  - ConvertTo-PAMAccount
  - Compare-TierZeroAccount
---

## [0.2.1]

### Fixed

- Users and computers from a trusted domain that are members of a Tier Zero group through a foreign security principal are reported as the trusted domain account, with its `ObjectClass`, instead of as the foreign security principal, so `ConvertTo-PAMAccount` includes them. Foreign security principals for trusted domain groups are no longer reported as accounts; the group is reported by `Get-TierZeroGroup` and its members by `Get-TierZeroAccount`. Foreign security principals which cannot be read in the trusted domain are still reported.
- `Compare-TierZeroAccount` outputs copies of the input accounts instead of adding `InPAM` to them, so comparing the same accounts again no longer changes earlier results.

## [0.2.0]

### Added

- `Get-TierZeroGroup`: lists the Tier Zero groups found by the same discovery as `Get-TierZeroAccount`, with a `Reason` entry for each way the group was found: default group, additional group, nesting in a Tier Zero group, or control by container or object ACL. Groups in a trusted domain reached through a foreign security principal are included.
- ObjectACL: principals allowed to delegate to a Tier Zero object (`msDS-AllowedToActOnBehalfOfOtherIdentity`, `Right` `AllowedToAct`) and principals allowed to retrieve the password of a Tier Zero group managed service account (`msDS-GroupMSAMembership`, `Right` `ReadGMSAPassword`) are Tier Zero.
