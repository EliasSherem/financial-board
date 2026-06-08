import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/auth_store.dart';
import 'admob_ad_units.dart';

const String _mutationCountKeyPrefix = 'mutation_count_for_ads';
const String _legacyCreateCountKeyPrefix = 'create_count_for_ads';
const String _legacyTransactionCountKeyPrefix =
    'transaction_create_count_for_ads';
const int _mutationsPerInterstitial = 5;
const int _maxInterstitialsPerSession = 3;
const Duration _interstitialCooldown = Duration(minutes: 5);
const Duration _naturalBreakDelay = Duration(milliseconds: 650);

const Set<String> _unsafeRouteNames = {
  '/ai-chat',
  '/login',
  '/signup',
  '/lock',
  '/auth',
};

class NonProInterstitialAdController {
  NonProInterstitialAdController._();

  static InterstitialAd? _interstitialAd;
  static bool _isLoading = false;
  static bool _isShowing = false;
  static bool _showAttemptInProgress = false;
  static int _sessionShowCount = 0;
  static int? _entitlementKnownUserId;
  static DateTime? _lastShownAt;

  static void markEntitlementKnownForUser(int? userId) {
    _entitlementKnownUserId = userId;
  }

  static void clearEntitlementState() {
    _entitlementKnownUserId = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
    _isShowing = false;
    _showAttemptInProgress = false;
  }

  static bool _canUseAdsForAuth(AuthStore auth) {
    final adUnitId = AdMobAdUnits.interstitial;
    final userId = auth.userId;
    if (adUnitId == null || userId == null) return false;
    return _entitlementKnownUserId == userId &&
        auth.isAuthenticated &&
        !auth.isLocked &&
        auth.hasToken &&
        !auth.isProOrExempt;
  }

  static bool _canUseAds(BuildContext context) {
    return _canUseAdsForAuth(context.read<AuthStore>());
  }

  static bool _isSafeToShow(BuildContext context) {
    if (!_canUseAds(context)) return false;
    if (_isShowing) return false;
    if (_sessionShowCount >= _maxInterstitialsPerSession) return false;

    final lastShownAt = _lastShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < _interstitialCooldown) {
      return false;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return false;
    }

    final route = ModalRoute.of(context);
    final routeName = route?.settings.name;
    if (route == null ||
        !route.isCurrent ||
        routeName == null ||
        routeName.isEmpty ||
        _unsafeRouteNames.contains(routeName)) {
      return false;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if ((mediaQuery?.viewInsets.bottom ?? 0) > 0) return false;

    return _interstitialAd != null;
  }

  static void preloadIfEligible(BuildContext context) {
    if (!_canUseAds(context)) return;
    _load();
  }

  static Future<void> recordSuccessfulMutation(BuildContext context) async {
    final auth = context.read<AuthStore>();
    if (!_canUseAdsForAuth(auth)) return;

    final userId = auth.userId;
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final counterKey = '${_mutationCountKeyPrefix}_$userId';
    final legacyCreateCounterKey = '${_legacyCreateCountKeyPrefix}_$userId';
    final legacyTransactionCounterKey =
        '${_legacyTransactionCountKeyPrefix}_$userId';
    final currentCount =
        sp.getInt(counterKey) ??
        sp.getInt(legacyCreateCounterKey) ??
        sp.getInt(legacyTransactionCounterKey) ??
        0;
    final updatedCount =
        currentCount >= _mutationsPerInterstitial
            ? _mutationsPerInterstitial
            : currentCount + 1;
    await sp.setInt(counterKey, updatedCount);

    if (updatedCount < _mutationsPerInterstitial) {
      _load();
      return;
    }

    if (_showAttemptInProgress || _isShowing) {
      _load();
      return;
    }

    _showAttemptInProgress = true;
    try {
      await Future<void>.delayed(_naturalBreakDelay);
      if (!context.mounted || !_isSafeToShow(context)) {
        _load();
        return;
      }
      final didShow = await _showIfReady(
        onShown: () async {
          _lastShownAt = DateTime.now();
          _sessionShowCount += 1;
          await sp.setInt(counterKey, 0);
        },
      );
      if (!didShow) {
        _load();
      }
    } finally {
      _showAttemptInProgress = false;
    }
  }

  static void _load() {
    final adUnitId = AdMobAdUnits.interstitial;
    if (adUnitId == null ||
        _isLoading ||
        _interstitialAd != null ||
        _sessionShowCount >= _maxInterstitialsPerSession) {
      return;
    }

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Non-Pro interstitial failed to load: $error');
          _isLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  static Future<bool> _showIfReady({
    required Future<void> Function() onShown,
  }) async {
    if (_isShowing) return false;
    final ad = _interstitialAd;
    if (ad == null) return false;

    _isShowing = true;
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        Future<void>.microtask(onShown);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowing = false;
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Non-Pro interstitial failed to show: $error');
        ad.dispose();
        _isShowing = false;
        _load();
      },
    );

    try {
      await ad.show();
    } catch (e, stack) {
      debugPrint('Non-Pro interstitial show threw: $e\n$stack');
      ad.dispose();
      _isShowing = false;
      _load();
      return false;
    }
    return true;
  }
}
