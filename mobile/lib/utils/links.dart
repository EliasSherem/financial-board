import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../state/auth_store.dart';

Future<void> openLink(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    // Try external browser first; fall back to in-app webview if not available
    bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}

Future<void> startStripeCheckout(BuildContext context) async {
  try {
    final auth = context.read<AuthStore>();
    final api = ApiClient()..setToken(auth.token);
    final res = await api.post('/api/stripe/checkout', body: {});
    String? url;
    if (res is Map && res['url'] is String) url = res['url'] as String;
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to start checkout')));
      }
      return;
    }
    await openLink(context, url);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }
}
