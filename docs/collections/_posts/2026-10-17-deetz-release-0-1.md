---
title: "Deetz Release 0.1"
date: 2026-10-17 00:00:00
version: 0.1.0
tags:
  - Release Notes
  - Get-TierZeroAccount
  - Compare-TierZeroAccount
  - ConvertTo-PAMAccount
  - ConvertTo-TierZeroReport
---

## [0.1.0]

### Added

- `Get-TierZeroAccount`: lists Tier Zero accounts found by group membership, well known account and container ACL, with a `Reason` entry (source, group path, right and target) for each way it was found. Default groups follow the SpecterOps Tier Zero Table; read-only domain controller computer accounts are reported as well known accounts. Principals with control or ownership of a Tier Zero account or group object, and managers of read-only domain controllers, are found by ObjectACL, repeating until no new principal is found. Groups and ACEs from trusted domains outside the forest are followed into those domains.
- `Compare-TierZeroAccount`: marks which Tier Zero accounts are held in a PAM tool.
- `ConvertTo-PAMAccount`: formats Tier Zero user accounts for PAM onboarding, by CSV or psPAS `Add-PASAccount`.
- `ConvertTo-TierZeroReport`: outputs one row per Tier Zero account per reason, for CSV export.
