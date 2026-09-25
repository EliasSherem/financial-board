# FinSight mobile upgrade

The Flutter implementation adds Momentum, secure password recovery, usage analytics, and access to the existing AI chat through verified server credits. It reuses the app's Liquid Glass components and original SVG assets. Progress, rewards, and entitlements remain authoritative on the server.

Implementation began after the repository audit checkpoint. The inventory, initial flows, baseline, and exclusions are recorded in [repository-audit.md](repository-audit.md); the detailed session inventory is `/tmp/finsight-mobile-audit.md`. This report covers the mobile implementation and its integration with the server. Billing dependency and purchase details are documented in [billing-upgrade.md](billing-upgrade.md), and shared DTOs in [client-contract.md](client-contract.md).

## Momentum state and presentation

Models, an API service, and a provider store consume `/api/engagement/me`. The client does not calculate rewards or complete missions locally. Progress and acknowledgement queues are bounded and scoped to the user. Logout and account changes discard them; generation checks prevent late responses or persistence writes from restoring another account's state.

Network errors retain cached progress with an explicit offline label. Refreshes occur on authenticated foreground, financial changes, return from actions or reviews, and period expiry. A financial change during an active fetch schedules another fetch. Dashboard and Accounts also preserve the session on ordinary financial network errors; a rejected current authentication token still triggers central revocation.

The Dashboard card shows the level, lifetime XP, actual weekly count, next achievable mission, and a button to open Momentum. Activation shows at most three actions and does not display an invented weekly `0/3` before assignment. The Momentum screen separates required weekly slots from optional, comeback, feature, and monthly missions. It displays server-provided requirements, unavailable reasons, nominal and granted XP, caps, the actual grace period, history, and credit balance. Profile and Settings expose Momentum and Achievements. Context strips connect missions to existing financial screens.

Reviews render actual server snapshots and require explicit confirmation of every applicable section. Weekly and monthly reviews also require a next-step choice. Opening a screen does not complete a mission. Network retries retain the event ID and `occurred_at`; expired or changed snapshots require a new read. PDF reporting obtains the server snapshot before export and emits `report_exported` only after Printing or sharing returns success. Cancellation does not award XP.

The gallery displays the 34 server achievements using the original asset manifest. Filters and details expose progress, requirements, unavailable reasons, locked states, and server acknowledgements for viewed achievements. Automatic unlock presentation is limited to one per `HomeShell` session on the visible foreground Dashboard. It avoids stacked modals and excludes historical backfill. The detail animation lasts 420 ms and uses scale, fade, and a restrained halo; reduced motion disables it. The XP chart uses the actual 30-day server ledger history, with an accessible list of exact values and an empty state.

## Assets, accessibility, and native context

All 168 supplied SVGs remain unchanged. The manifest selects light, dark, and locked variants rendered by `flutter_svg` at 24, 40, and 64 px where appropriate. Asset copies were verified byte for byte. No artwork was replaced with a bitmap or redrawn.

Liquid Glass buttons inherit the theme's `labelLarge` typography. Outline buttons use readable light text in dark mode while keeping the existing blue outline. The new-week indicator uses brand blue. The new surfaces support English and Spanish, and card tests cover both themes at 200% text scale.

A native channel provides the real Android or iOS platform, app version and build, and IANA timezone, with UTC-offset fallback. Momentum preferences support notification opt-in, integer quiet hours, and timezone selection. Notifications default to disabled on the server. A persisted manual timezone preference takes precedence over later device context; an already assigned period retains its stored boundaries.

The existing push pipeline recognizes `momentum`, `momentum_week_ready`, `momentum_week_reminder`, and `momentum_comeback`. Their action opens Momentum for an authenticated user. Background notification delivery does not start an analytics session.

## Recovery, sessions, and entitlements

English and Spanish recovery request and reset screens use existing Liquid Glass components. Requests show a neutral response and handle resend cooldowns and rate limits. Reset validates the password and confirmation, distinguishes invalid, used, and expired links, and reports success only after the server accepts the change. Success clears password and token state and forces sign-out.

Recovery tokens remain in memory, with sanitized route settings and no analytics or preference storage. The native route handler accepts the existing `financialboard://reset-password#token=...` scheme. Emailed HTTPS links retain the web fallback. This implementation does not establish or claim deployed Universal Links or App Links associations. Profile password changes now call the authenticated change-password endpoint with the current password; the old local-only success path was removed.

The API client revokes a rejected current token on `401`, while an old request cannot invalidate an unrelated newly authenticated token. The global `localPro` flag and hardcoded user exemptions no longer grant entitlements. Verified server state is cached per user and cleared on account changes. Login and foreground use the common billing sync followed by `/api/me`; a network failure preserves the last verified state.

### Biometric session restoration, 2026-09-25

Cold startup now waits for persisted authentication before choosing a screen. A saved session with biometrics enabled always starts locked, even if the previous run had been unlocked. Storage read failures offer a retry without deleting credentials. Ordered storage writes and session generation checks prevent a late restore or login write from undoing a newer logout. A biometric result applies only to the token that started its challenge.

Moving to `hidden`, `paused`, or `detached` locks an authenticated biometric session; `inactive` alone does not interrupt the native biometric prompt. Protected routes close on lock, and the authenticated home is mounted only after unlocking. Password recovery remains a public route. Momentum and analytics suspend background work while locked; device-token registration resumes after unlock. Pending store verification waits for authentication rather than treating the local lock as a rejected purchase.

Camera/gallery and print/share activities explicitly opened by the user keep their current session while the native activity runs and Flutter returns to the foreground. This prevents Android's activity handoff from discarding a selected receipt or report. The exception is held only in memory, applies to the initiating session, and cannot bypass a cold-start lock. Recovery routes remain available after locking, but any protected routes underneath them are removed.

Every API method, including multipart upload, checks the current session lock before sending. Each request retains its original token for `401` handling, including when its API client is reused with another token. Connection failures and `503` preserve the session; rejection of the current token and explicit sign-out still clear it.

This fixes persistence across closing and reopening the app. It does not renew expired credentials: the existing backend JWT lifetime remains **24 hours**, with no refresh-token flow or backend/schema changes in this correction. A genuinely expired or revoked session requires a new sign-in. Android Studio/Xcode builds must be rebuilt from these sources; Cloud Run deployment alone does not update installed mobile apps.

Validation of this correction: **84/84 Flutter tests passed**, including 52 session regressions covering storage races, cold/warm locking, cancelled/successful biometric challenges, stale `401` responses, suspended Momentum/analytics, pending purchases, protected navigation below recovery, and native activity handoffs. The new cases use synthetic tokens, mocked HTTP/native channels, and a fake store; no real purchase is performed. Scoped analysis of 19 files reports no errors or warnings, with 33 informational lints remaining. Logs: `/tmp/finsight-biometric-session-tests.log` and `/tmp/finsight-biometric-session-analyze.log`.

The Android release AAB build passed in 31.9 seconds (61.2 MB). Artifact: `mobile/build/app/outputs/bundle/release/app-release.aab`, SHA-256 `c9f74b651b20a9392d3a7ae74018b96b1cc4f2c979f2243674caee84ec61ecfc`. Build log: `/tmp/finsight-biometric-android-release.log`. This is build and automated-test evidence; a physical-device biometric authentication or store publication is not claimed.

The unsigned arm64 iOS simulator Debug build also passed (`/tmp/finsight-biometric-ios-build.log`). It was installed over the existing app without uninstalling or clearing preferences, then launched after termination. The saved session remained present and the authenticated Dashboard and Momentum rendered successfully. Biometrics were disabled in that simulator's existing preferences and were left unchanged; native startup is smoke-test evidence, while the biometric cancel/success and lock transitions are covered by the automated tests above. The simulator app remains at the DerivedData path documented under native build commands below.

## Analytics and existing AI chat

Behavioral telemetry is separate from domain completion. Its queue holds at most 100 events, sends at most 20 per batch, retains stable UUIDs for a maximum of 24 hours, and renews the session after 30 minutes of inactivity. Events use the actual native platform, version, build, and a rotated random installation ID. Screens, features, steps, and outcomes are allowlisted. Financial amounts, notes, reset URLs, tokens, and message contents do not enter this queue.

The privacy preference synchronizes with the server. Opt-out is immediate locally; an offline preference change remains pending and retries. Signup records the actual `client_platform`. The existing mobile app has no Google login flow, so no such flow was introduced.

The existing AI chat accepts verified Pro access or a positive balance of available server credits. Each logical question receives one stable `request_id`. Retries preserve that ID and message payload. Server responses indicating an in-progress request remain retryable; terminal credit, access, or retry-cache errors refresh the balance and do not invent a successful answer. The client timeout accommodates the existing server generation budget. Successful responses refresh Momentum and credits. The pending request identifier is held in memory; durable retry after process termination is not claimed. No separate AI product was added.

## Files

New modules:

- `mobile/lib/momentum/models.dart`, `service.dart`, `store.dart`, `widgets.dart`, `screens.dart`, and `xp_chart.dart`.
- `mobile/lib/screens/password_recovery_screen.dart`.
- `mobile/lib/services/analytics_service.dart`, `client_context.dart`, and `session_lifecycle.dart`.
- `mobile/test/momentum_test.dart`.

Modified integrations:

- `mobile/lib/main.dart`.
- `mobile/lib/services/api.dart`, `auth_service.dart`, and `push_service.dart`.
- `mobile/lib/state/auth_store.dart` and `refresh_bus.dart`.
- `mobile/lib/screens/accounts_screen_new.dart`, `ai_chat_screen.dart`, `analytics_screen.dart`, `dashboard_screen.dart`, `investments_screen.dart`, `invoices_screen.dart`, `login_screen.dart`, `manage_categories_screen.dart`, `payments_screen.dart`, `projects_screen.dart`, `receipt_scan_screen.dart`, `settings_screen.dart`, `transactions_v2_screen.dart`, and `update_profile_screen.dart`.
- `mobile/lib/liquid_glass/lg_button.dart`.
- `mobile/android/app/src/main/AndroidManifest.xml` and `mobile/android/app/src/main/kotlin/com/example/mobile/MainActivity.kt`.
- `mobile/ios/Runner/AppDelegate.swift`.
- `mobile/ios/Podfile` and `Podfile.lock`: the post-install hook aligns older pod deployment targets with the app's existing iOS 15 minimum, without lowering higher requirements.
- `mobile/pubspec.yaml`: asset entries, alongside the dependency changes documented by the billing work.

Original assets are under `mobile/assets/momentum/assets/`, including the manifest and badge, level, and UI directories. Billing integration also changes `purchase_service.dart`, `pro_widgets.dart`, the billing methods in `DataService`, pubspec dependencies and lockfile, and Android Gradle files; see the billing report for their behavior and validation.

## Verification evidence

The environment used Flutter 3.41.6, Dart 3.11.4, Android Studio's JBR 21, and Xcode 27. Paths under `/tmp` are evidence from this implementation session, not committed fixtures.

| Check | Result | Evidence |
| --- | --- | --- |
| Initial isolated Flutter baseline | 2/2 tests passed | `/tmp/finsight-mobile-baseline-test.log` |
| Initial isolated Dart analysis | 0 errors, 5 warnings, 128 informational findings | `/tmp/finsight-mobile-baseline-analyze.log` |
| Final Flutter tests | **16/16 passed** | `/tmp/finsight-mobile-implementation-test.log` |
| Analysis of new modules and core integrations | **No issues found** | `/tmp/finsight-mobile-scoped-analyze.log` |
| Whole mobile `lib` and `test` analysis | 0 errors, 4 existing warnings, 127 informational findings | `/tmp/finsight-mobile-full-analyze.log` |
| Whitespace validation | `git diff --check` passed | Local repository check |
| Android release AAB | **Passed**, 26.6 s, 61.2 MB | `/tmp/finsight-mobile-android-release.log` |
| Unsigned iOS arm64 simulator Debug build | **Passed** | `/tmp/finsight-mobile-ios-arm64-build.log` |

The audit baseline ran from an isolated copy without `pub get` or generated source changes before the checkpoint. The remaining whole-project warnings concern an unnecessary `!` in `calendar_screen.dart`, an unused `per` in `payments_screen.dart`, and an unnecessary `!` plus unused `fmt` in legacy `transactions_screen.dart`. The unused AuthService import was removed. Repository-wide lint success is not claimed.

The final test command was `flutter test --no-pub --reporter expanded`. Tests cover:

- Existing invoice PDF behavior, recovery URI allowlisting and malformed input, and UUID shape and uniqueness.
- Server progress clamping and the explicit review flag; offline cache and logout; late responses from a previous account; refresh coalescing; and the real Dashboard error branch preserving login and cached Momentum.
- Rejection of local purchase flags as entitlement authority, parsing all 168 original SVG variants with the installed renderer, and explicit review confirmation with stable event IDs after a failed submission.
- Four English/Spanish and light/dark card variants with text scaled to 200%.

Actual Momentum widgets were rendered with local fixtures at 390 × 844 using loaded SDK fonts. `/tmp/finsight-momentum-light.png` and `/tmp/finsight-momentum-dark.png` were inspected for light and dark presentation, 24/40/64 px SVGs and locked states, text, the compact card, and the numeric progress ring. Separate test processes avoided a completed static Future crossing Flutter's fake-async test zones. Render logs are `/tmp/finsight-mobile-preview-light.log` and `/tmp/finsight-mobile-preview-dark.log`. These images use fixture data and are not physical-device or production screenshots.

Both final native commands returned exit code 0 after the source freeze. They ran sequentially to avoid generated plugin metadata races. The Android artifact is `mobile/build/app/outputs/bundle/release/app-release.aab`, with SHA-256 `6a86bf87d26f357a1d40a60e11941e6aeb39bc946731866d122e60801e82c30d`. The iOS artifact is `/Users/elias/Library/Developer/Xcode/DerivedData/Runner-brvxcjmhytyuiaamdoylbvnhgwcw/Build/Products/Debug-iphonesimulator/Runner.app`.

Commands used from the `mobile` directory:

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true /Users/elias/Documents/flutter/bin/flutter build appbundle --release
/usr/bin/xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -arch arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build
```

The Android release command deliberately permits normal pub regeneration. A preexisting generated registrant referenced the `flutter_native_splash` development dependency, while release Gradle excluded development plugins. Normal Flutter regeneration produced matching metadata and registrant while preserving locked versions. The registrant was not edited by hand; no fake native class was added and no development tool was moved into production dependencies. The billing work separately corrected the legacy `home_widget` Kotlin/Java mismatch to Java 11 and verified Billing 8.0.0 with release `dependencyInsight`.

The universal `flutter build ios --simulator` path encountered an Xcode 27 `lipo` failure on the combined `-verify_arch arm64 x86_64` invocation. `lipo -info` reported both slices, and individual architecture checks passed. The verified local path is the explicit arm64 simulator `xcodebuild` above. An x86_64 or universal build, signed device build, or archive is not claimed. The SDK was not modified to bypass validation.

## Backend review and remaining checks

### Momentum visibility and loading performance, 2026-09-24

The local debug API was missing `MOMENTUM_ENABLED`; after activation, a real `/engagement/me` request still took 38.24 seconds and exceeded the mobile 15-second deadline. A cached disabled response then hid the failure. Dashboard pull/retry now refreshes Momentum, disabled-cache loading/error states remain visible, and evaluation requests have a bounded 90-second deadline. Ordinary API reads retain 15 seconds. The server was also optimized; extending the deadline is not reported as a server speedup.

Financial screens now avoid an unused Dashboard investment request and load independent transaction/form lists concurrently. The resulting suite passes **32/32**, the iOS arm64 simulator build and Android AAB build pass, and Momentum was observed in the signed-in iOS simulator with real server data. No Android device or store-publication claim is made. See [server performance](server-performance.md) for before/after timings, tests and deployment evidence; this supersedes earlier test/artifact counts for these changes.

### iOS startup regression fixed on 2026-09-24

The real `FinancialBoardRoot` now has a startup widget test. Before the fix it reproduced the reported `WidgetsApp` assertion: `home` and `onGenerateInitialRoutes` cannot be specified together. `MaterialApp.home` was replaced with the named `/` route, preserving the custom initial stack and keeping `AppGate` underneath password recovery.

A platform-route test also reproduced a second failure while the app was running: Flutter normalized `financialboard://reset-password#token=...` into `/#token=...`. `SessionLifecycle` now handles the original recovery URI before that normalization, applies the existing scheme/token validation, and pushes a route named only `/reset-password`. Untrusted HTTPS input cannot become a trusted relative route, and navigation metadata does not contain the recovery token.

Validation: **24/24 Flutter tests passed**, including eight new startup and navigation regressions; scoped analysis reported no issues. The unsigned arm64 iOS simulator build passed, was installed without uninstalling or clearing application data, and displayed the actual login screen without the red assertion screen. Logs: `/tmp/finsight-app-startup-final-tests.log`, `/tmp/finsight-app-startup-analyze.log`, `/tmp/finsight-ios-startup-fix.log`. The simulator login screenshot is `/tmp/finsight-ios-startup-fixed.png`. Cold/warm links and return navigation are proven by widget tests; a separate native `simctl openurl` attempt reached the iOS confirmation dialog, so it is not recorded as a completed native recovery flow. No recovery form was submitted and no real password or email was changed.

An independent review of Momentum's engine, service, repository, and routes identified issues that were corrected in the server work: manual timezone precedence over repeated device queries; consistent unavailable status and reasons; civil-IANA spacing for grace across DST; explicit review-key allowlisting; visibility of the prior grace period; a deterministic optional pool that reaches project, customer, and category review missions; and route read/write limits. The review also covered caps and locks, snapshot and period rejection, server reward authority, comeback episode uniqueness, and initial backfill acknowledgement. Server tests are separate evidence and are not included in the Flutter count.

Real-environment release checks remain: SMTP delivery; invalid, used, and expired recovery links from real mail clients into cold and warm installed apps; device timezone, DST, locale, reduced motion, large text, and notifications; server flag rollout; store sandbox purchases, pending payments, restore, renewal, and refunds; and signed Android/iOS distribution builds using the intended credentials. This mobile work made no production calls, deployment, store upload, or real purchase. Server tests, migrations, billing validation, and operational procedures are documented in their respective reports.


### Store artifacts and iOS version, 2026-09-25

The requested iOS update is **1.0.9 (10)**. Runner and FinancialBoardWidgetExtension use matching native `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` values in Xcode. Runner Info.plist now reads these settings, as the widget already did. This keeps Android at its requested **1.0.8 / version code 52**: `pubspec.yaml` remains `1.0.8+9` and the explicit Android version code remains 52. Flutter build-name/build-number overrides no longer change the iOS bundle metadata; future iOS bumps must update both native targets.

Release build settings and the actual archived Info.plist files confirm iOS 1.0.9 / 10 for both bundles. A local device Release archive succeeded with the existing Apple Development identity and profiles, with valid app/widget signatures and the signed APNs development entitlement. No profiles were downloaded or changed automatically. The archive is a Development-signed archive for Organizer, not an exported App Store IPA. Distribution still requires the appropriate App Store signing profile with Push Notifications; the previously cached store profile did not contain that entitlement.

Deliverables are in `~/Desktop/FinSight-Releases/2026-09-25/`: `FinSight-android-1.0.8-52.aab`, `FinSight-ios-1.0.9-10.xcarchive`, a README and checksum manifest. The Android AAB was reused from the successful final-source release build because only iOS metadata and documentation changed afterward. Its embedded manifest confirms `com.finsight.finsight`, version 1.0.8 / code 52; JAR signature verification passed. SHA-256: `1e49bdb73d6bd4d9be9b9bbf2a419ef7fe017546922ff5f41bab2399260397e0`.

The 119 passing Flutter tests cover the unchanged application logic. Metadata checks, `plutil -lint`, and the signed Release archive validate this version-only follow-up; the test suite was not repeated. Logs: `/tmp/finsight-ios-109-final-archive.log` and `/tmp/finsight-ios-109-final-settings.json`. No app was uploaded to either store, and physical-device push reception remains unverified.
