# Explain User Management and Authentication

> :pencil: **Note:** this document explains the target configuration,
> we are currently in the process of migrating towards it

User management mostly happens in keycloak.

## Keycloak

[Keycloak](https://www.keycloak.org/)
is an Open Source identity and access management platform.

The [openfoodfacts-auth](https://github.com/openfoodfacts/openfoodfacts-auth) project
handles a specific deployment of keycloak fitted to our needs.

You can refer to its documentation.

In production, it is deployed as https://auth.openfoodfacts.org/

Our users are inside the "openfoodfacts" realm.

To login as a keycloak administrator (that is administrator of all realms),
you can log to https://auth.openfoodfacts.org/admin/
with a specific account (which is distinct from your Open Food Facts Account)

### How to register an OIDC client

* Create a client id (e.g. "OFF") in Keycloak by following these instructions: https://github.com/openfoodfacts/openfoodfacts-auth?tab=readme-ov-file#internal-backend-client
* Set the $oidc_client_id and $oidc_client_secret values in Config2.pm
* Set the $oidc_implementation_level=1 in Config2.pm and export all of the variables
* Make sure the redis listener service is started for each instance

## Login and registration

Keycloak acts as a SSO to all dev platform.

### In Product Opener (Open x Facts websites)

The authentification is handled through **FIXME explain OIDC and session cookie**

When users come to one of our website,
they are redirected to the login or registration forms of keycloak.

Keycloak also handles password reset.

### Wiki

At the moment the wiki uses a plugin
to read the authentication cookie from Open Food Facts
(it's possible because we are on the same domain)
to authenticate users in the wiki.

### Hunger game

Reads the authentication cookie from Open Food Facts.
and use the `auth.pl?body=1` to get users info and roles.

### Taxonomy editor and Nutripatrol

The backend reads the authentication cookie from Open Food Facts,

Reads the authentication cookie from openfoodfacts.
and use the `auth.pl?body=1` to get users info and roles.

They both cache the results.

## Users information

### Users main informations

The main user information is stored in Keycloak using the PostgreSQL database.

### Users preferences

Keycloak stores user's information, but not application specific preferences
which are deferred to a file on disk. (see `User.pm`, `retrieve_user` and `store_user`)

Those files are in a users dataset which is shared between all OxF websites.

> Note: They are in STO format (Perl serialization), but we are transitioning to a JSON format. Also they could be better stored in a database like postgreSQL.


### User roles

Apart from simple users, there are important users roles:
- administrator
- moderator
- moderator for the producers platform

There are also a series of informative flags on the user to specify that an account is:
* a producer account belonging a specific org
* a bot account
* an account used by an application to access the data, and so on

User roles are specified:
* in the config file for administrators (`$admins` variable)
* through specific properties of user preferences for the other roles

On producer platform, role within an org (administrator or user of an organization)
is part of the organization information, stored in a file on disk (`orgs` dataset).

## In development

In development, the openfoodfacts-auth project is a service dependency of this project.
See [Service Dependencies](https://github.com/openfoodfacts/.github/blob/main/docs/service-dependencies.md)

If you want to become admin of the website,
you just need to create a user using one of the account listed in `admins`,
like `stephane`.
With this account you can eventually give any role to other accounts.

On keycloak side,
the `openfoodfacts-auth` container sets up the `root:test` admin user by default,
Although it's not strictly necessary during development
you may use it to gain admin access to keycloak as admin
on http://auth.openfoodfacts.localhost:5600/admin/.
