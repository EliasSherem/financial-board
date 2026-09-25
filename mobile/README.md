# FinSight Mobile

Flutter mobile app for Financial Board / FinSight.

## iOS Testing

This app now targets iOS 15.0+ because the current Firebase iOS SDK requires it.

1. Install Flutter and Xcode.
2. Install CocoaPods if needed: `brew install cocoapods`
3. Fetch Dart packages: `flutter pub get`
4. Install iOS pods: `cd ios && pod install`
5. Run on the iOS simulator: `flutter run -d "iPhone 17"`

Build-only check:

```bash
flutter build ios --simulator
```

If you want to test on a physical iPhone, open `ios/Runner.xcworkspace` in Xcode and set your signing team for the `Runner` app target and the `FinancialBoardWidgetExtension` target.

## App Store Archive

The current iOS version is **1.0.9**, build **10**, for both Runner and the embedded widget. Their `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` settings in `ios/Runner.xcodeproj` are the iOS source of truth; both Info.plist files use those native settings. Update both targets together for future releases. Flutter's `--build-name` and `--build-number` do not override these iOS bundle versions.

Android remains **1.0.8**, version code **52**. Its version name comes from `pubspec.yaml` (`1.0.8+9`); its version code is explicitly set in `android/app/build.gradle.kts`.

The local deliverables from 2026-09-25 are in `~/Desktop/FinSight-Releases/2026-09-25/`: the signed Android AAB and an iOS `1.0.9 (10)` archive signed with Apple Development. The archive is not an exported App Store IPA. Open it in Xcode Organizer to distribute it with the appropriate App Store signing profile, including Push Notifications. No store upload was performed.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set your Apple Developer team for both `Runner` and `FinancialBoardWidgetExtension`.
3. Choose the `Any iOS Device (arm64)` destination.
4. Choose Product → Archive in Xcode. To create a local archive from CLI without automatic profile updates:

```bash
flutter build ios --release --config-only --no-pub
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath build/ios/archive/FinSight-1.0.9-10.xcarchive archive
```

The local archive uses the already installed signing identity and provisioning profiles. App Store distribution/export is a separate operation in Organizer. To check a device Release build without signing:

```bash
flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://api.finsight.com.mx
```
