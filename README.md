# HelloID-Conn-Prov-Target-MultiBel

<!--
** for extra information about alert syntax please refer to [Alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
-->

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://multibel.eu/wp-content/uploads/2016/10/multibel_logo-header.png.webp">
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
  - [Remarks](#remarks)
    - [FieldMapping](#fieldmapping)
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

| Feature                                   | Supported | Actions                                 | Remarks |
| ----------------------------------------- | --------- | --------------------------------------- | ------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable, Delete |         |
| **Permissions**                           | ❌         | -                                       |         |
| **Resources**                             | ❌         | -                                       |         |
| **Entitlement Import: Accounts**          | ✅         | -                                       |         |
| **Entitlement Import: Permissions**       | ❌         | -                                       |         |
| **Governance Reconciliation Resolutions** | ✅         | -                                       |         |


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

## Remarks
### FieldMapping
- **JobCategories**: In MultiBel, a user can have multiple job categories. The connector is configured to set only a default job category during creation. And will not be updated afterwards. In the Import script the job categories are listed comma separated.
- **Values must exist**: The Field `JobCategories` and `rolName` must be configured with existing values in MultiBel.

### API Limitation
- **PhoneNumbers**:<br>
The API supports 1 - 10 phone numbers, in different properties. There is a difference between the GET and PUT call. There is some extra logic in the connector to handle this. The connector currently does not support adding or updating the phone numbers.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                                | HTTP Method | Description                                    |
| --------------------------------------- | ----------- | ---------------------------------------------- |
| /api/v2/Persons/Person?PersonId         | GET         | Retrieve (correlate) user information          |
| /api/v2/Persons/Person?MultiBelPersonId | GET, DELETE | Retrieve and delete user information           |
| /api/v2/Persons/Person                  | POST, PUT   | Create and update user information             |
| /api/v2/Persons/Persons                 | GET         | Retrieve all users information (import)        |

### API documentation

- [Swagger documentation](https://webapi.multibel.eu/swagger/ui/index#/)

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
