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
