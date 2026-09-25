# Push delivery and independent notification channels

The financial reminder cron and Momentum reminders share `server/notifications/delivery.ts`. Email keeps its existing independent event types and payment reminder content. A failure in either channel, or for one user, does not stop the other channel or subsequent users.

## Configuration

- `FCM_PROJECT_ID` identifies the Firebase project used by the installed Android/iOS apps. It takes precedence over the project in a service-account JSON, so explicitly authorized cross-project sending works.
- Cloud Run can use its attached service identity through Application Default Credentials. Set `FCM_PROJECT_ID` and omit `FCM_SERVICE_ACCOUNT_JSON` for this mode. The sender needs the FCM API enabled and `cloudmessaging.messages.create` permission on the target project. No downloaded key is required.
- An explicitly configured `FCM_SERVICE_ACCOUNT_JSON` remains supported. Malformed or incomplete JSON fails local configuration validation; it does not silently fall back to a different identity.
- iOS additionally needs the app's push entitlement/provisioning, user permission, an APNs registration, and working APNs credentials in the same Firebase project. Android uses the existing `finsight_default` notification channel; an OS-disabled channel cannot be enabled by the server.
- `NOTIFICATION_CRON_ENABLED` controls payment/budget reminders. Momentum also requires `MOMENTUM_ENABLED`, `MOMENTUM_PUSH_ENABLED`, the user's preference, an eligible current week, and a permitted hour. Existing quiet hours, frequency limits and eligibility checks remain in effect.

Reference: [FCM HTTP v1 authorization](https://firebase.google.com/docs/cloud-messaging/send/v1-api), [send endpoint and IAM permission](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send).

## Durable push outcomes

Migration `010_notification_delivery.sql` adds one delivery record per notification event and device-token SHA-256. It also expands existing tokens to 1024 ASCII characters with case-sensitive comparison. The delivery table does not copy raw tokens, email addresses, financial descriptions or notification bodies.

Preparation, claiming and completion take the user lock first. Provider requests occur after the transaction commits. A short per-device lease and conditional lease-token update prevent competing cron instances from acknowledging each other's work. Deadlocks and lock waits retry database transactions only; a provider call that already returned is never repeated by that retry.

| Status | Meaning and follow-up |
| --- | --- |
| `accepted` | FCM returned a message identifier. This is provider acceptance, not proof that a phone displayed the notification. Never automatically resend this device for the same event. |
| `retryable` | Explicit transient HTTP failure, credential lookup failure before sending, or a confirmed connection failure before reaching FCM. Retry with exponential backoff, jitter and `Retry-After`, with at most eight attempts and within the event lifetime. |
| `invalid` | FCM explicitly returned `UNREGISTERED`, or the token is no longer unambiguously owned by the user. Delete a stored token only for confirmed `UNREGISTERED`, scoped to that user and exact token. |
| `rejected` | A non-transient rejection, including malformed requests or sender mismatch. Retain the token and inspect the sanitized error code/configuration. Generic HTTP 400/403 do not prove a token expired. |
| `unknown` | A timeout/ambiguous network result or an abandoned lease may already have reached FCM. Do not automatically repeat it. |
| `expired` | The reminder is resolved, its delivery window ended, or retry limits were reached. |

One accepted device no longer prevents a different device's explicit transient failure from being retried. Tokens registered to several users are excluded both when an event is prepared and immediately before a device is claimed. Registration must establish one owner before that token can receive financial information.

Existing `notification_events` without delivery records remain historical claims and are **not** backfilled into new pushes. This prevents a rollout from replaying old notifications whose actual delivery cannot be established. Newly registered devices are included in newly prepared events; the queue retains the original recipients for an existing event.

Payment push attempts end after the due date in the stored local offset. Budget events have a 24-hour attempt window. Momentum attempts end at the fixed period boundary and are subject to the current preference, quiet hours and activity checks on each cron pass. Failed email sends release only their email event claim, preserving the existing email retry behavior.

Provider failures log bounded codes and HTTP statuses, never provider response bodies, device tokens, credentials or notification text. See [FCM error handling](https://firebase.google.com/docs/cloud-messaging/error-codes).

## Validation without delivery

`npm run doctor:push` invokes the separate operator CLI. It uses FCM's documented `validate_only: true` mode and prints aggregate counts, configuration identifiers and error codes only. Successful validation has the distinct `validated` outcome, never `accepted`. The FCM module performs no token deletion or delivery-table update; dry-run validation cannot claim or acknowledge an event.

Validation verifies the request/authentication path. It does not prove permission state, APNs end-to-end delivery, background presentation or a notification being displayed on a physical phone.

## Local checks

- `NODE_ENV=test node --import tsx --test server/notifications/fcm.test.ts server/notifications/delivery.test.ts server/notifications/cron.test.ts server/momentum/notifications.test.ts`: 20 passing mock tests; no provider requests.
- `FINSIGHT_TEST_PORT=13307 FINSIGHT_TEST_DATABASE=finsight_performance_test npm run test:db -- server/notifications/delivery_sql.test.ts`: 4 passing isolated MySQL tests after the lock-order fix. Covers historical claims, concurrent workers, shared-token exclusion, delayed retries, stale leases, owner-scoped cleanup and tokens longer than 255 characters. All sends are injected mocks.
- `npm run check:server`: passed.

These checks do not assert that production was migrated or deployed. Deployment evidence is recorded separately by the release operator.
