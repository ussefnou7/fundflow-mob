# FundFlow mobile architecture decisions

## Theme tokens

The app reads the tenant theme from `/api/organization/context`. All nine web
themes map into one Flutter `AppTokens` theme extension. Screens use semantic
tokens such as `brand`, `canvas`, `line`, `success`, `warning`, and `danger`
instead of literal colors. Spacing and corner radii use `AppSpace` and
`AppRadius`.

## Mobile interaction conventions

Application screens are RTL from the root. Text starts from the right and page
actions sit on the physical left. Data screens use `AppRefreshPage`; users
refresh them by pulling down, including when a page is shorter than the
viewport. Do not add refresh buttons to page headers.

Primary navigation uses an RTL side drawer, matching the web application. The
drawer shows the active company and lets users switch between their available
company memberships. A company change is sent to
`POST /api/organization/context/company`, then the organization context and all
company-scoped mobile screens are reloaded.

## Authorization

The mobile app uses the same permission codes returned by the web context API.
Navigation items and page actions are derived from the active membership's
`permissionCodes`; they are never inferred from a role name. Switching company
therefore rebuilds the drawer and the current screen using that company's
permissions. The backend remains responsible for enforcing authorization on
every API request.

## Single-device biometric login

MFA is outside the current mobile scope. Each user may register one mobile
device. The backend device table must enforce a unique `user_id`; registering a
replacement device first revokes and deletes the previous credential.

The app never reads or uploads biometric data. It creates a device-bound private
key in Secure Enclave or Android Keystore, protected by Face ID, Touch ID, or a
strong Android biometric. The backend stores only the public key and device
metadata. After the initial password login, authentication uses a server
challenge signed by that key. An administrator can reset the registered device,
after which password login is required to enroll another device.

Suggested server fields are `user_id`, `device_id`, `platform`, `display_name`,
`public_key`, `created_at`, `last_used_at`, `revoked_at`, and `credential_version`.

## Offline-first synchronization

The mobile database will contain cached read models and an outbox. Every local
mutation receives a stable UUID `clientOperationId`, creation time, payload,
attachment paths, retry count, and one of `pending`, `syncing`, `synced`, or
`failed`. The UI renders local data immediately and shows the synchronization
state beside the affected row.

When connectivity returns, the sync worker sends outbox entries in creation
order. The backend must persist `clientOperationId` per company and return the
original result for a repeated operation, preventing duplicate requests,
expenses, or transfers. Updates carry the server `version`; a version conflict
stops that record and asks the user to refresh or resolve it. Images remain in
app storage until their owning operation succeeds.

Before device reset or logout, the app must report unsynchronized operations.
Resetting a device credential does not silently delete business data waiting in
the outbox.
