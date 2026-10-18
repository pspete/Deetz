---
title: "Deetz Release 0.2"
date: 2026-10-18 00:00:00
version: 0.2.0
tags:
  - Release Notes
  - Get-TierZeroGroup
  - Get-TierZeroAccount
---

## [0.2.0]

### Added

- `Get-TierZeroGroup`: lists the Tier Zero groups found by the same discovery as `Get-TierZeroAccount`, with a `Reason` entry for each way the group was found: default group, additional group, nesting in a Tier Zero group, or control by container or object ACL. Groups in a trusted domain reached through a foreign security principal are included.
- ObjectACL: principals allowed to delegate to a Tier Zero object (`msDS-AllowedToActOnBehalfOfOtherIdentity`, `Right` `AllowedToAct`) and principals allowed to retrieve the password of a Tier Zero group managed service account (`msDS-GroupMSAMembership`, `Right` `ReadGMSAPassword`) are Tier Zero.
