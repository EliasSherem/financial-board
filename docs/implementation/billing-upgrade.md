# Billing implementation and release runbook

Verified locally on 2026-09-24. This follows the required repository audit checkpoint in `repository-audit.md`. No store publication, production migration, real charge, sandbox purchase, RTDN configuration, or provider account mutation was performed.

## Actual SDK upgrade

| Layer | Audited baseline | Implemented/resolved |
|---|---|---|
| Flutter | 3.41.6 / Dart 3.11.4 | retained |
| `in_app_purchase` | 3.2.3 | exact 3.3.1 |
| `in_app_purchase_android` | 0.4.0+8 | exact 0.5.0 |
| Play Billing native | 7.1.1 | **8.0.0**, Gradle release dependency graph and fresh merged manifest |
| StoreKit wrapper | 0.4.8+1 | retained; Apple server verification added |
| Apple server library | absent | official `@apple/app-store-server-library` 3.1.0 |

This is the supported **provisional Billing 8 route**, not a claim to have integrated Billing 9. Official Google release notes list 9.1.0 (2026-06-18); the official Flutter Android wrapper inspected still declares Billing 8.0.0. Core 3.3.1 requires Flutter 3.41/Dart 3.11; Android 0.5.0 supports the installed toolchain. Android 0.5.0+1 and subsequent releases require Flutter 3.44/Dart 3.12, absent here, without providing a Billing 9 native integration. Do not force `com.android.billingclient` to 9 under this wrapper. Track the official wrapper's future native migration, then update the toolchain/wrapper together and repeat the purchase matrix before publication. No fork was introduced.

Primary sources checked on the date above:

- [Google release notes](https://developer.android.com/google/play/billing/release-notes), [deprecation policy](https://developer.android.com/google/play/billing/deprecation-faq), [Billing 9 migration](https://developer.android.com/google/play/billing/migrate-gpblv9). Billing 7's submission deadline was 2026-08-31, with eligible extension to 2026-11-01; Billing 8 removes that specific baseline submission blocker.
- [Core Flutter changelog](https://pub.dev/packages/in_app_purchase/changelog), [Android wrapper changelog](https://pub.dev/packages/in_app_purchase_android/changelog), [official tagged Android 0.5.0 Gradle file](https://raw.githubusercontent.com/flutter/packages/in_app_purchase_android-v0.5.0/packages/in_app_purchase/in_app_purchase_android/android/build.gradle.kts), [tagged pubspec](https://raw.githubusercontent.com/flutter/packages/in_app_purchase_android-v0.5.0/packages/in_app_purchase/in_app_purchase_android/pubspec.yaml).
- [Backend lifecycle](https://developer.android.com/google/play/billing/backend), [subscription states](https://developer.android.com/google/play/billing/subscriptions), [verification/security](https://developer.android.com/google/play/billing/security), [RTDN schema](https://developer.android.com/google/play/billing/rtdn-reference), [test guidance](https://developer.android.com/google/play/billing/test).
- [Authenticated Pub/Sub push](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions), [Orders get](https://developers.google.com/android-publisher/api-ref/rest/v3/orders/get), [Orders/refund resource](https://developers.google.com/android-publisher/api-ref/rest/v3/orders).
- [Official Apple server library](https://github.com/apple/app-store-server-library-node), [signed transaction schema](https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload), [Apple PKI roots](https://www.apple.com/certificateauthority/).
- [Stripe signed webhooks](https://docs.stripe.com/webhooks), [Stripe currency encoding](https://docs.stripe.com/currencies). UGX/ISK retain Stripe's two-decimal API encoding, despite zero-decimal currency presentation.

## Authority and compatibility

Migration `009_billing_identity_collation.sql` gives provider contract, inbox, job and charge identifiers exact `utf8mb4_0900_bin` comparison, including the legacy Play token used for ownership reconciliation. It preserves lengths, nullability and unique indexes; human names and emails retain their original collation. Case or trailing-space variants remain distinct, while exact duplicates retain idempotency. Two additional SQL regressions cover ownership and deduplication; the complete suite now passes 83/83 on isolated MySQL 8.4.11. This migration has not been applied to the reviewed remote database; see [remote-migration-review.md](remote-migration-review.md).

`server/billing/{google,apple,repository,worker,rtdn,routes}.ts` normalizes provider contracts; `stripe.ts` uses the same repository. `users.is_pro` is a rebuildable cache of the OR of verified, effective contracts plus explicit unexpired grants. Pending/hold/paused/expired/revoked/refunded/unknown states do not grant access. Active/trial/grace/cancel-at-period-end require a future provider expiry. Trial and manual grants never become paid subscriber revenue. A failed provider sync does not overwrite a previously verified contract; its expiry still applies.

The migration preserves original Google product IDs `finsight_monthly,finsight_pro_monthly` and Apple aliases including `7T8M8X5R46`; it does not rename store products, base plans, packages, or signing configuration. Product lists are configurable allowlists. Existing link and sync routes remain, responses retain public fields, and `/api/me` remains the entitlement authority. `/api/pro/activate` now requires a verified restore (409); an old client can no longer grant itself paid access. New Flutter code never treats local Pro preferences as authority.

Old provider rows are copied into `billing_contracts` with `verified=false,status=legacy`; no historical purchase/revenue/platform is fabricated. An already-enabled user with an unreconciled legacy contract has a **30-day bridge measured from migration record creation**. Existing ID 1/3 Pro exceptions become separately labelled `legacy_code_exemption` grants, never admin roles. Existing unexplained `is_pro` values receive `legacy_unknown` grants expiring after 30 days. Operators must reconcile/classify these before the deadline. The bridge does not renew on API boot.

New purchases require the server-issued HMAC account binding (Google) or deterministic UUID appAccountToken (Apple). Known legacy ownership, including provider-confirmed linked/out-of-app expired-token chains, can restore without newly introduced account IDs; contradictory account IDs or ownership never transfer a purchase. `GOOGLE_PLAY_REQUIRE_ACCOUNT_ID=false` / `APPLE_REQUIRE_ACCOUNT_TOKEN=false` are explicit temporary legacy-adoption exceptions, not defaults; if used, restrict the rollout window operationally and review newly linked contracts before restoring `true`.

Google tokens and Apple receipts are encrypted using AES-256-GCM before transaction start; token identity is SHA-256, unique by provider. User-row locks protect entitlement updates, binding is rechecked under lock, duplicate deliveries produce one contract/ACK job, linked replacements retain old audit rows, and a pending replacement does **not** prematurely retire the existing contract. Provider observations carry fetch-start timestamps so older in-flight reads cannot overwrite a newer snapshot. Legacy plaintext token/receipt columns remain for backwards-compatible reconciliation; plan their separately reviewed encryption backfill/removal after all distributed clients and rollbacks are retired. Do not claim all historical secrets are already migrated.

## Delivery and ACK ownership

Flutter presents actual provider ProductDetails, localized prices, offer phases and purchase options. Android selection retains offerToken/base-plan information and passes prior native purchase details for a plan change. The stream handles pending, cancellation, network error, restored and purchased states, retries verification while alive, and recovers from the native purchase queue after restart. No price or free-trial promise is invented.

Google **server owns ACK**: verified entitlement and an idempotent `ack_google` job commit together; the worker rechecks Play v2 before `subscriptions.acknowledge`. Android Flutter does not independently call `completePurchase` after delivery. Apple finishes its StoreKit transaction only after backend verification; failed/cancelled StoreKit entries can be finished without a grant. Already distributed Android clients may still acknowledge; the server observes acknowledged state and handles that idempotently during transition. Never consume a subscription.

`POST /webhooks/google-play` verifies the Google signed JWT, exact audience, issuer, configured service-account email and `email_verified`, then validates package and envelope. `POST /webhooks/app-store` verifies Apple's signed notification and nested transaction with Apple's library and configured trust roots/app identity. Stripe `/webhooks/stripe` requires the configured signing secret and raw bytes; there is no unsigned fallback.

A webhook returns 2xx only after a durable encrypted inbox write. Event IDs deduplicate; callbacks cause a fresh provider lookup, not blind replay of stale event states. Worker rows have a five-minute lease and attempt fencing; crashes/redelivery are safe. Backoff starts at 60 seconds, caps at six hours; after 12 attempts a sanitized failed row remains visible to admin. The worker runs every 30 seconds, schedules stale-contract reconciliation hourly (six-hour threshold), and rechecks known recent Google orders daily for refund updates. Provider requests have bounded timeouts where supported. No provider network call happens inside the entitlement DB transaction.

## Billing data coverage for admin

- `billing_contracts`: current provider/raw/normalized state, expiry, trial/renewal, currency, optional recurring amount/period, sync freshness and replacement link. Checkout UUID persists through pending/app-kill/RTDN for flow attribution; it is not a purchase token.
- `billing_charges`: idempotent confirmed Stripe paid invoices and successful refunds, Google Orders processed/partial/full refund events, and Apple verified signed transaction prices when provided (Apple price is in milliunits). Amounts remain separated by currency and refund date. Personal financial transactions never enter subscription revenue.
- Google/Apple subscription response data does not always give a reliable contractual duration. Their MRR remains **N/D** until reliable provider duration is integrated; do not infer monthly from SKU or divide guessed prices. Stripe single-item undiscounted month/year contracts have contractual MRR, annual divided by 12. Mixed-item or discounted contracts are explicitly uncovered. Charges include provider tax/discount treatment and are not net payouts.
- Apple revocation proves access loss, not a reliable refund amount. Apple refund revenue is uncovered without a trusted amount-confirming report; do not infer it from list price. Historical provider transactions before tracking are not silently fabricated. Order API permissions/errors are visible as failed jobs.
- `billing_state_events` snapshots expiry/access when state or expiry changes. Churn denominators require observable paid state before range start; replacements and scheduled cancellations without effective loss are excluded. Coverage before first verified snapshot is unavailable.

## Environment and provider setup

Use secret management; this document lists names only. Root `.env.example` consolidates these with other modules.

| Variable | Purpose |
|---|---|
| `BILLING_ENCRYPTION_KEY` | Base64 32 random bytes, stable across instances; required to decrypt inbox/tokens. Back up in secret storage; rotation needs a separate re-encryption procedure. |
| `BILLING_ACCOUNT_ID_SECRET` | Stable secret at least 32 characters, account HMAC/Apple UUID; do not rotate casually or existing store bindings change. |
| `BILLING_CHECKOUT_ENABLED` | `false` stops new checkout UI/Stripe sessions; never disables verification/restores/webhooks. |
| `BILLING_WORKER_ENABLED` | Default enabled; pausing is incident-only, bounded well inside Play ACK deadlines. |
| `BILLING_ALLOW_SANDBOX` | Default false. Enable only on isolated sandbox backend/data environment. |
| `ANDROID_PACKAGE_NAME` | Actual package `com.finsight.finsight`. |
| `GOOGLE_APPLICATION_CREDENTIALS` / workload identity | Android Publisher ADC with subscription verification, acknowledgement and Orders read access. No JSON key belongs in the repo. |
| `GOOGLE_PLAY_PRODUCT_IDS` | Comma-separated unchanged existing product IDs. |
| `GOOGLE_PLAY_REQUIRE_ACCOUNT_ID` | Default true for newly claimed tokens; known legacy token owners can restore. |
| `GOOGLE_RTDN_AUDIENCE` | Exact HTTPS push endpoint audience. |
| `GOOGLE_RTDN_SERVICE_ACCOUNT` | Exact dedicated Pub/Sub push service-account email. |
| `APPLE_BUNDLE_ID`,`APPLE_APP_ID` | Actual bundle ID and numeric App Store app ID; production signature checks require both. |
| `APPLE_PRODUCT_IDS` | Existing aliases allowed for this app. |
| `APPLE_ROOT_CA_PATHS` | Comma-separated local Apple root DER certificate paths, downloaded/reviewed from Apple PKI. |
| `APPLE_PRIVATE_KEY_PATH`,`APPLE_KEY_ID`,`APPLE_ISSUER_ID` | App Store Server API signing credentials. |
| `APPLE_REQUIRE_ACCOUNT_TOKEN` | Default true on unknown new Apple original transactions. |
| `APPLE_SHARED_SECRET` | Legacy App Store receipt validation; existing `APPLE_APP_SHARED_SECRET`/`APPLE_IAP_SHARED_SECRET` aliases retained. |
| `STRIPE_SECRET_KEY`,`STRIPE_WEBHOOK_SECRET` | Stripe API and signature verification; existing price `STRIPE_CURRENCY`,`STRIPE_UNIT_AMOUNT` and canonical `CLIENT_URL` preserved. |
| `ADMIN_ANALYTICS_ENABLED`,`ANALYTICS_ENVIRONMENT` | Trusted purchase events and explicit test/internal/production classification; no significant-activity credit for billing callbacks. |

External rollout actions, **not performed here**:

1. Apply reviewed migrations on staging first with backup/rollback rehearsal. Confirm MySQL timezone tables for IANA reports. Deploy backend and workers before Flutter/web updates. Check explicit migration prerequisites and least-privilege DB grants.
2. Link the actual Play app/project and grant its server identity verification/ACK/Orders permissions. Create RTDN Pub/Sub topic; grant the Google Play notifications publisher permission to that topic. Configure the Play Console topic. Create an authenticated push subscription using the dedicated push identity and exact audience/HTTPS URL; grant the Pub/Sub service agent required token-creation permission. Set retry/dead-letter monitoring. Send Console test notification and verify one durable inbox row before 204.
3. Configure actual Apple production/sandbox app identity, root certs and server API credentials; configure App Store Server Notifications V2 endpoint. Validate signed TEST and subscription notifications on isolated sandbox.
4. Configure Stripe endpoint/event selection for checkout completion, async success, subscription created/updated/deleted, invoice.paid, charge.refunded and refund created/updated. Preserve raw-body middleware order. Verify signed delivery and retry in test mode.
5. Review all legacy bridge/grant owners, conflicts, expiry and missing provider credentials. Resolve unknown classifications before 30 days. Confirm no payments were silently converted into grants or guessed revenue.
6. Publish only after the manual matrix below and owner release process. This task does not upload the local artifact.

## Tests and actual local results

- `NODE_ENV=test node --import tsx --test server/billing/billing.test.ts`: **18 passed**, provider adapters use fixtures; signature/identity rejection, state table, ownership, AEAD tampering, ACK failure/retry, pending, forged Apple JWS, currencies/annual periods, durable RTDN failure and Orders/refund parsing.
- `npm run test:db -- server/billing/billing_sql.test.ts server/admin/metrics_sql.test.ts`: **6 passed** against isolated local MySQL 8.4.11 at loopback port 13306. Covers four concurrent same-account deliveries → one contract/ACK/trusted event, cross-account rejection, stale snapshot fencing, OR/replacements, pending-flow recovery, inbox lease/retry, charge/refund dedup, exact mature D7/D30, platform dedup, independent billing filters, annual/monthly MRR, separate currencies, real refund period, flow conversion, unavailable-week exclusion, all six report queries and safe exports. Fixtures create/remove synthetic users only; migrations/columns were aligned locally, never in production.
- Scoped backend TypeScript checks passed. Full workspace checks and broader baseline warnings are in the main upgrade report.
- Gradle `:app:dependencyInsight --dependency com.android.billingclient --configuration releaseRuntimeClasspath --console plain` with Android Studio JBR 21: **8.0.0 resolved** via the official plugin, no Billing force override.
- Android release app bundle **passed**, `mobile/build/app/outputs/bundle/release/app-release.aab`; fresh release merged manifest declares `com.google.android.play.billingclient.version=8.0.0`. The first build exposed existing home_widget Java 8 vs resolved WorkManager Java 11 incompatibility; only that plugin's Java/Kotlin target is aligned to 11. A stale preexisting GeneratedPluginRegistrant included a dev-only splash plugin: the official `flutter build appbundle --release` (without `--no-pub`) regenerated it correctly. No generated registrant was hand-edited.
- Flutter regression and iOS simulator results are recorded by the mobile implementation report. No device/store billing test was represented as performed.

Required Play internal testing: existing subscription restore after upgrade; new purchase on bound account; pending payment then approved/cancelled; kill after native purchase before verify and before ACK; lost network; ACK transient failure and retry before provider refund deadline; already-owned; expiry/cancel-at-end/recover from hold/grace; base-plan upgrade/downgrade and linked token; attempted second FinSight account claim; repeated/out-of-order RTDN; legacy client still ACKing; Google + Apple/Stripe coexistence. Repeat Apple sandbox restore, JWS validation, renewal/grace/revoke, account token mismatch, transaction finish and old receipt fallback. Repeat Stripe signed renewal/failure/cancel/refund and test/live separation.

## Rollback and operations

Disable **new checkout** first if needed, keep verification/webhooks and at least one worker available. Roll back the client independently while retaining normalized server entitlement authority. Do not restore the old unsigned/JWS-decoding/self-grant handlers. Keep additive schema, encrypted inbox, ownership bindings and financial/reward ledgers. Code rollback to a version lacking the new tables requires an explicitly reviewed adapter, not dropping the tables.

Data health exposes failed deliveries, pending inbox age and stale provider sync without secrets. Fix credentials/config first; replay only identified failed rows by their numeric ID with a reviewed operational SQL update to pending/attempts=0/next_attempt_at=UTC_TIMESTAMP, never by modifying subscription state or amounts. Successful inbox payloads expire after 30 days; all inbox payloads after 180 days; done jobs after 30 days; contracts/ledger persist until account deletion. Foreign keys cascade account-owned records. Unlinked encrypted webhooks are not yet associated with a user and expire through inbox retention. Account deletion and encryption-key loss must be considered in legal/operational retention policy.
