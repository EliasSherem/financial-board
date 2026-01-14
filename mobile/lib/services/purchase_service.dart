import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../state/auth_store.dart';
import 'api.dart';
import 'data_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // Update this to your Play Console product id(s).
  // You can include multiple ids; the first found will be used.
  static const Set<String> kIds = {
    'finsight_monthly',
    'finsight_pro_monthly',
  };
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void _attach(BuildContext context) {
    _sub ??= InAppPurchase.instance.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased) {
          await _acknowledge(p);
          // Activate on backend (best-effort). UI flips immediately via local flag.
          try {
            final api = ApiClient()..setToken(context.read<AuthStore>().token);
            final data = DataService(api);
            final productId = p.productID;
            final token = p.verificationData.serverVerificationData; // Play purchase token on Android
            if (productId.isNotEmpty && token.isNotEmpty) {
              await data.linkPlayPurchase(productId: productId, purchaseToken: token);
            }
            await data.activatePro();
          } catch (_) {}
          if (context.mounted) {
            await context.read<AuthStore>().setLocalPro(true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro activated. Thanks!')));
          }
        } else if (p.status == PurchaseStatus.error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase failed: ${p.error}')));
          }
        }
      }
    }, onDone: () { _sub?.cancel(); _sub = null; });
  }

  Future<void> purchasePro(BuildContext context) async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store unavailable on this device')));
      }
      return;
    }
    _attach(context);
    final resp = await InAppPurchase.instance.queryProductDetails(kIds);
    if (resp.error != null || resp.productDetails.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found. Configure Play Console product id.')));
      }
      return;
    }
    final product = resp.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _acknowledge(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(p);
    }
  }
}
