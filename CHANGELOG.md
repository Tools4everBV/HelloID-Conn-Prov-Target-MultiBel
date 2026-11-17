# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [1.1.0] - 17-11-2026

### Added
- Permission scripts for `JobCategories`: retrieve, grant, revoke and import (`permissions/jobCategories`).
- README section about permissions and the required setting of 1 concurrent action.
- Field mappings `phoneNumber1` (business mobile) and `phoneNumber2` (business fixed), each with `countryCode` and `number`. More phone numbers (up to `phoneNumber10`) can be added with the same naming, without changes to the scripts.
- Complex mapping for the phone number. It converts the phone number from HelloID to the format MultiBel expects: only digits, without country code and without leading `0` (for example `06-12345678` becomes `612345678`). The `countryCode` is a fixed value (`31`).
- Create: a phone number is only sent when `number` has a value. When `number` has a value and `countryCode` is empty, the action fails with a clear error.
- Update: phone numbers are compared separately on `countryCode` and `number` and are always kept in line with HelloID. When `number` is empty in HelloID, the phone number is cleared in MultiBel by sending both `countryCode` and `number` empty.
- Account import now returns the phone numbers (`countryCode` and `number`) and supports nested import fields.
- README section about phone numbers.
- Configuration setting `DefaultJobCategoryId`. This job category is always set on create and is excluded from the permissions and the permission import, so it cannot be selected in a business rule.

### Changed
- Update now supports changing `rolName` instead of throwing an error. An invalid role is reported by the MultiBel API.
- Update no longer removes empty phone numbers from the `PUT` body. MultiBel accepts an empty phone number when the `countryCode` is also empty.

### Removed
- Field mapping `jobCategories`. The default job category is set from the configuration setting `DefaultJobCategoryId`.
- README section `API Limitation` about phone numbers not being supported.

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