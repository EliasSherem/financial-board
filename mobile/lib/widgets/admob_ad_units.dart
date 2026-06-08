import 'package:flutter/foundation.dart';

const String _androidTestBannerAdUnitId =
    'ca-app-pub-3940256099942544/6300978111';
const String _iosTestBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
const String _androidReleaseBannerAdUnitId =
    'ca-app-pub-6230562819068631/6476284755';
const String _iosReleaseBannerAdUnitId =
    'ca-app-pub-6230562819068631/5853468228';

const String _androidTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/1033173712';
const String _iosTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/4411468910';
const String _androidReleaseInterstitialAdUnitId =
    'ca-app-pub-6230562819068631/3950349290';
const String _iosReleaseInterstitialAdUnitId =
    'ca-app-pub-6230562819068631/3227304885';

class AdMobAdUnits {
  const AdMobAdUnits._();

  static String? get banner => _forCurrentPlatform(
    androidTest: _androidTestBannerAdUnitId,
    iosTest: _iosTestBannerAdUnitId,
    androidRelease: _androidReleaseBannerAdUnitId,
    iosRelease: _iosReleaseBannerAdUnitId,
  );

  static String? get interstitial => _forCurrentPlatform(
    androidTest: _androidTestInterstitialAdUnitId,
    iosTest: _iosTestInterstitialAdUnitId,
    androidRelease: _androidReleaseInterstitialAdUnitId,
    iosRelease: _iosReleaseInterstitialAdUnitId,
  );

  static String? _forCurrentPlatform({
    required String androidTest,
    required String iosTest,
    required String androidRelease,
    required String iosRelease,
  }) {
    if (kIsWeb) return null;
    final useReleaseAdUnits = kReleaseMode;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return useReleaseAdUnits ? androidRelease : androidTest;
      case TargetPlatform.iOS:
        return useReleaseAdUnits ? iosRelease : iosTest;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }
}
