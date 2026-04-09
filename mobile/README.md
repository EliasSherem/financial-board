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

The current app version is `1.0.1` with build number `2`.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set your Apple Developer team for both `Runner` and `FinancialBoardWidgetExtension`.
3. Choose the `Any iOS Device (arm64)` destination.
4. Archive from Xcode, or build from CLI with:

```bash
flutter build ios --release --dart-define=API_BASE_URL=https://api.finsight.com.mx
```

To verify the project compiles for App Store upload before signing, you can also run:

```bash
flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://api.finsight.com.mx
```
