# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [1.1.0] - 17-11-2026

### Added
- Permission scripts for `JobCategories`: retrieve, grant, revoke and import (`permissions/jobCategories`).
- README section about permissions and the required setting of 1 concurrent action.
- Field mappings `phoneNumber1` (business mobile) and `phoneNumber2` (business fixed), each with `countryCode` and `number`. Create and update now support filling phone numbers; the account import also returns them.
- Configuration setting `DefaultJobCategoryId`. This job category is always set on create and is excluded from the permissions and the permission import, so it cannot be selected in a business rule.

### Changed
- Update now supports changing `rolName` instead of throwing an error. An invalid role is reported by the MultiBel API.

## [1.0.1] - 17-06-2026

### Added
- Field mapping `otherInfo`. If not sent when creating an account, MultiBel returns a 500 error. A note has also been added to the README.
- Field mapping `multibelPersonId` to store the account reference. A minor update to `update.ps1` was required to support this.
- Default value for `BaseUrl` in the configuration.

### Changed
- Field mapping `lastName`. It now also uses prefix, partner name, partner prefix, and convention.

## [1.0.0] - 08-04-2026

This is the first official release of _HelloID-Conn-Prov-Target-MultiBel_. This release is based on template version _v4.1.1_.

### Added

### Changed

### Deprecated

### Removed