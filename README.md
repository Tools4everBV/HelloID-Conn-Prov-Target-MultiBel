# HelloID-Conn-Prov-Target-MultiBel

<!--
** for extra information about alert syntax please refer to [Alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
-->

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-MultiBel/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-MultiBel](#helloid-conn-prov-target-multibel)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
    - [Permissions](#permissions)
    - [Concurrent actions](#concurrent-actions)
  - [Remarks](#remarks)
    - [FieldMapping](#fieldmapping)
    - [Retrieve roles from MultiBel](#retrieve-roles-from-multibel)
    - [JobCategories as permissions](#jobcategories-as-permissions)
    - [API Limitation](#api-limitation)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-MultiBel_ is a _target_ connector. _MultiBel_ provides a set of REST APIs that allow you to programmatically interact with its data.

## Supported features

The following features are available:

| Feature                                   | Supported | Actions                                 | Remarks       |
| ----------------------------------------- | --------- | --------------------------------------- | ------------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable, Delete |               |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke                 | JobCategories |
| **Resources**                             | ❌         | -                                       |               |
| **Entitlement Import: Accounts**          | ✅         | -                                       |               |
| **Entitlement Import: Permissions**       | ✅         | -                                       | JobCategories |
| **Governance Reconciliation Resolutions** | ✅         | -                                       |               |


## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.
```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-MultiBel/refs/heads/main/Icon.png
```

### Requirements
- Connection settings: API Key, Base URL

### Connection settings

The following settings are required to connect to the API.

| Setting | Description                        | Mandatory |
| ------- | ---------------------------------- | --------- |
| API Key | The API-Key  to connect to the API | Yes       |
| BaseUrl | The URL to the API                 | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _MultiBel_ to a person in _HelloID_.

| Setting                   | Value                             |
| ------------------------- | --------------------------------- |
| Enable correlation        | `True`                            |
| Person correlation field  | `PersonContext.Person.ExternalId` |
| Account correlation field | `personId`                        |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Account Reference

The account reference is populated with the property `multibelPersonId` property from _MultiBel_

### Permissions

The connector supports _JobCategories_ as permissions. The scripts are located in the folder `permissions/jobCategories`.

| Script                 | Description                                                         |
| ---------------------- | ------------------------------------------------------------------- |
| `permissions.ps1`      | Retrieves all job categories from MultiBel                          |
| `grantPermission.ps1`  | Adds a job category to the account                                  |
| `revokePermission.ps1` | Removes a job category from the account                             |
| `import.ps1`           | Imports the job categories with their accounts (entitlement import) |

The permission reference is the `id` of the job category in MultiBel.

### Concurrent actions

> [!IMPORTANT]
> The number of concurrent actions (_Concurrent sessions_) must be set to **1**.

MultiBel has no separate API endpoints to add or remove a single job category. The job categories are part of the person object, and the `PUT /api/v2/Persons/Person` call overwrites the complete person. Grant and revoke therefore read the person, change the list of job categories and write back the full person. When multiple actions run at the same time for the same person, one action can overwrite the changes of another, causing granted job categories to be lost or revoked ones to come back. With concurrent actions set to 1, every action works on the latest state of the person.

## Remarks
### FieldMapping
- **JobCategories**: In MultiBel, a user can have multiple job categories. The job categories are managed as permissions, see [Permissions](#permissions). The field mapping `jobCategories` is only used on create, because MultiBel (most likely) requires at least one job category when creating an account. It is not used in the update action. In the account import script the job categories are listed comma separated.
  <!-- TODO: Verify whether an account can be created with an empty jobCategories list. Expected: not allowed. If it is allowed, the default job category in the field mapping can be removed. -->
- **Values must exist**: The Field `JobCategories` and `rolName` must be configured with existing values in MultiBel.
- **rolName**: The `rolName` can be updated. To do so, add the `Update` action to the `rolName` field mapping. If the role does not exist in MultiBel, the MultiBel API returns an error and the action fails. See [Retrieve roles from MultiBel](#retrieve-roles-from-multibel) for the available roles.
- **OtherInfo** must be included in the body when creating an account. The API returns a `500` error if this field is not present in the body.

### Retrieve roles from MultiBel
The field `rolName` must contain the exact name of an existing role in MultiBel. The available roles can be retrieved with the PowerShell snippet below. Replace `<API key>` with the API key from the connection settings.

```powershell
$baseUrl = 'https://webapi.multibel.eu'
$headers = @{
    'MB-ApiKey' = '<API key>'
}
$roles = Invoke-RestMethod -Uri "$baseUrl/api/v2/Role" -Method 'GET' -Headers $headers
$roles | Select-Object id, name, description | Format-Table -AutoSize
```

Use the value of `name` in the `rolName` field mapping, with the same spelling.

### JobCategories as permissions
- **Default job category**: MultiBel requires at least one job category when creating an account. The field mapping `jobCategories` therefore still sets a default job category on create. This default job category is not managed by HelloID, unless it is also assigned as a permission through a business rule. In that case it will be removed when the permission is revoked.
- **No dedicated endpoints**: Grant and revoke update the job categories by sending the complete person to `PUT /api/v2/Persons/Person`. See [Concurrent actions](#concurrent-actions).
- **Last job category**: Revoking the last job category of an account sends an empty list. Verify in the test environment whether MultiBel accepts a person without job categories.
- **Sub job categories**: MultiBel returns an error when a sub job category of a corporation job category is assigned.

### API Limitation
- **PhoneNumbers**:<br>
The API supports 1 - 10 phone numbers, in different properties. There is a difference between the GET and PUT call. There is some extra logic in the connector to handle this. The connector currently does not support adding or updating the phone numbers.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                                | HTTP Method | Description                               |
| --------------------------------------- | ----------- | ----------------------------------------- |
| /api/v2/Persons/Person?PersonId         | GET         | Retrieve (correlate) user information     |
| /api/v2/Persons/Person?MultiBelPersonId | GET, DELETE | Retrieve and delete user information      |
| /api/v2/Persons/Person                  | POST, PUT   | Create and update user information        |
| /api/v2/Persons/Persons                 | GET         | Retrieve all users information (import)   |
| /api/v2/JobCategory                     | GET         | Retrieve all job categories (permissions) |

### API documentation

- [Swagger documentation](https://webapi.multibel.eu/swagger/ui/index#/)

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
