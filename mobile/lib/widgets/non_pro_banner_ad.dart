import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_ad_units.dart';

class NonProBannerAd extends StatefulWidget {
  const NonProBannerAd({super.key});

  @override
  State<NonProBannerAd> createState() => _NonProBannerAdState();
}

class _NonProBannerAdState extends State<NonProBannerAd> {
  BannerAd? _bannerAd;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_loadStarted) return;
    final adUnitId = AdMobAdUnits.banner;
    if (adUnitId == null) return;

    _loadStarted = true;
    final bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
          });
        },
      ),
    );
    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (bannerAd == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final adSize = bannerAd.size;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
        ),
      ),
      child: Semantics(
        label: 'Advertisement',
        child: SizedBox(
          width: adSize.width.toDouble(),
          height: adSize.height.toDouble(),
          child: AdWidget(ad: bannerAd),
        ),
      ),
    );
  }
}
