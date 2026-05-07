import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../state/auth_store.dart';

const String kPurchaseTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const String kPurchasePrivacyPolicyUrl = 'https://finsight.com.mx/privacy';
const String kDeleteAccountUrl = 'https://finsight.com.mx/delete-account';

Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final uri = Uri.parse(url);
    // Try external browser first; fall back to in-app webview if not available
    bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
  } catch (e) {
    if (messenger?.mounted ?? false) {
      messenger!.showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}

Future<void> startStripeCheckout(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final auth = context.read<AuthStore>();
    final api = ApiClient()..setToken(auth.token);
    final res = await api.post('/api/stripe/checkout', body: {});
    String? url;
    if (res is Map && res['url'] is String) url = res['url'] as String;
    if (url == null || url.isEmpty) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to start checkout')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await openLink(context, url);
  } catch (e) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }
}
