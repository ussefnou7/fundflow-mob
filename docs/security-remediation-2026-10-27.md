# Security remediation — 27 October 2026

## Behavior changes

- Bearer session cookies now live only in memory. Startup deletes the legacy `fundflow-cookies` directory. Cold starts require password/MFA or the existing OS-protected biometric credential. This intentionally removes automatic passwordless reuse of a persisted session.
- Local logout clears auth/workspace even without connectivity. Session generations reject late network/cookie responses; workspace generations discard late loads. Expiry resets the navigator so sensitive dialogs cannot remain above the login screen. A 401 from a protected resource clears the session; a 403 does not.
- Background content is obscured. Returning after two minutes in the background ends the local session and requires login again. Android uses FLAG_SECURE; iOS includes a scene snapshot cover, pending native validation on Mac. This is not transaction-specific server step-up authentication.
- MFA login supports the server's `mfaRequired` response and `code` field. Optional biometric enrollment failures no longer strand successful login.
- Financial creation requests use durable random idempotency keys, identified by hashed user/company/endpoint/payload/attachment identities. No financial payload is stored by this mechanism. Successful responses remove the pending key; uncertain attempts retain it across restarts. Retry the same operation with unchanged data. This is not an offline outbox.
- Backend V18 stores request receipts atomically with the operation, scopes them to actor/company, rejects changed content under a reused key, and serializes concurrent retries across instances using a database lock. `X-Company-Id` rejects a changed active-company context. Existing web clients without a key retain their prior behavior; deploy backend before mobile.
- Covered creation routes: custody expenses/transfers/requests, contractor extracts, treasury movements/direct expenses/returns. Review/update routes retain their existing version/state guards.
- Push notification title/body are generic; no company name or financial message is sent as visible notification content. Logout/new login removes server push registration; client unregistration is best effort. Offline remote revocation cannot be guaranteed, so the payload itself is nonsensitive.
- Extract quantity/rate/percentage serialization and preview totals use decimal arithmetic, matching per-line HALF_UP rounding. Financial display formatting avoids binary doubles.
- Invoice selection bounds dimensions to 2400px, avoids requesting full photo metadata, checks size/count, and handles permission/file failures. Thumbnails decode at bounded width without rebuilding file byte futures. Upload send timeout is separate from normal requests. Search ignores stale replies. Firebase initialization follows first UI startup.

## Platform/release changes

- Android backup/cloud/device-transfer rules exclude application data; release disallows cleartext. Debug retains the existing LAN development exception.
- Release builds require explicit `android/key.properties` signing credentials, never debug fallback. See `android/key.properties.example`; private keys/properties are gitignored. Release tasks require an explicit HTTPS API_BASE_URL. AppConfig also validates release URL at runtime.
- iOS project target is 15.0 to match the installed Firebase plugins. Runner entitlements declare APNs development/production environments. Actual provisioning/APNs authorization still requires the developer account and a Mac build.
- No legal/privacy policy URL, organization identity, licensing claim, store declaration, or developer key has been invented. These remain release-owner inputs.

## Validation and limits

See the accompanying remediation report in `/home/ussef/FundFlow/output/mobile-audit-2026-10-27/remediation.ar.md` for final run counts and baseline failures.

No production deployment/database changes were performed. V18 must be applied by the normal backend deployment before distributing the new mobile build. Do not delete receipts casually: removing them permits old keys to create duplicate operations. They are financial application records and need a documented retention/access policy. A new key or altered payload describes a new request; idempotency does not infer that two different business requests are duplicates.

Release archive/signature/16KB-native verification, iOS runtime testing, low-memory/large-font/device profiling, store privacy manifests and disclosures, legal classification, and transaction-level step-up/maker-checker policy remain release validation or product-policy work. Image-picker process-death draft recovery is not implemented as offline persistence in this change. Do not label this a completed penetration test or store approval.
