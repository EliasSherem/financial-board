Firebase Cloud Messaging (FCM) setup for the Flutter app

Overview
- This project now includes Firebase Messaging hooks and a foreground notification path.
- You only need to add your Firebase config files and enable capabilities to start receiving pushes.

What’s already wired up
- Dependencies: `firebase_core`, `firebase_messaging`, `flutter_local_notifications` in `pubspec.yaml`.
- Initialization: `PushService.instance.init()` is called from `main()`.
- Foreground handling: messages are shown via local notifications on both Android and iOS.
- Background handler: registered with `FirebaseMessaging.onBackgroundMessage(...)`.
- Android 13+ permission: requested at runtime; manifest includes `POST_NOTIFICATIONS`.
- iOS foreground presentation: alerts/badges/sounds enabled; Info.plist includes `UIBackgroundModes: remote-notification`.

1) Create a Firebase project
- Go to https://console.firebase.google.com and create a project.

2) Add the Android app
- Android package id: use the `applicationId` from `mobile/android/app/build.gradle.kts` (currently `com.finsight.finsight`).
- Download `google-services.json` and place it at:
  - `mobile/android/app/google-services.json`

3) Add the iOS app
- iOS bundle id: open Xcode (Runner target) and note the bundle id, or set the one you want. Use that when registering the iOS app in Firebase.
- Download `GoogleService-Info.plist` and place it at:
  - `mobile/ios/Runner/GoogleService-Info.plist`
- In Xcode, enable Capabilities for the Runner target:
  - Push Notifications
  - Background Modes → Remote notifications
- In Firebase Console → Project Settings → Cloud Messaging, upload your APNs key (recommended) or certificates.

4) Get packages and build
- From the `mobile` folder run:
  - `flutter pub get`
  - Android: `flutter run -d android`
  - iOS: open `ios/Runner.xcworkspace` in Xcode and run on a device/simulator (pushes require a real device for iOS).

5) Verify the FCM token
- The app saves the token in SharedPreferences under `fcm_token` and logs it at startup.
- When signed in, the token is registered with the backend via `/api/device-tokens` (with timezone offset).
- You can also fetch it manually in code: `FirebaseMessaging.instance.getToken()`.

6) Send a test notification
- Easiest: Firebase Console → Cloud Messaging → Send notification → target the app instance using the token.
- Or via HTTP v1 (replace placeholders):

  curl -X POST \
    -H "Authorization: Bearer <YOUR_OAUTH2_ACCESS_TOKEN>" \
    -H "Content-Type: application/json; UTF-8" \
    https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send \
    -d '{
      "message": {
        "token": "<DEVICE_FCM_TOKEN>",
        "notification": {"title": "Hello", "body": "Test push from FCM"},
        "data": {"foo": "bar"}
      }
    }'

Notes
- Foreground notifications are displayed by `flutter_local_notifications`.
- Background/terminated notifications show automatically if you send a `notification` payload. Data-only messages in the background require custom handling and are subject to platform limits.
- FCM token registration is handled in `mobile/lib/services/push_service.dart`.

Troubleshooting
- Android: ensure `google-services.json` path is correct and Gradle syncs the Google Services plugin. Clean build if needed: `flutter clean`.
- iOS: pushes require a real device and valid APNs key/cert uploaded to Firebase. Also ensure the Runner has Push Notifications capability enabled.
