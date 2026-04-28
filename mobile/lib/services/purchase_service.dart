import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:provider/provider.dart';
import '../state/auth_store.dart';
import 'api.dart';
import 'data_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // Store product ids across Android and iOS.
  // The first product returned by the current store will be used.
  static const Set<String> kIds = {
    'finsight_monthly',
    'finsight_pro_monthly',
    '7T8M8X5R46',
  };
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<void> _deliverPurchase(
    String? authToken,
    PurchaseDetails purchase,
  ) async {
    final api = ApiClient()..setToken(authToken);
    final data = DataService(api);
    final productId = purchase.productID;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final receiptData = purchase.verificationData.serverVerificationData;
      String? originalTransactionId;
      if (purchase is AppStorePurchaseDetails) {
        originalTransactionId =
            purchase
                .skPaymentTransaction
                .originalTransaction
                ?.transactionIdentifier;
      }
      if (productId.isEmpty || receiptData.isEmpty) {
        throw Exception('Missing App Store receipt data');
      }
      await data.linkAppStorePurchase(
        productId: productId,
        receiptData: receiptData,
        transactionId: purchase.purchaseID,
        originalTransactionId: originalTransactionId,
      );
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData;
    if (productId.isEmpty || purchaseToken.isEmpty) {
      throw Exception('Missing Play purchase token');
    }
    await data.linkPlayPurchase(
      productId: productId,
      purchaseToken: purchaseToken,
    );
  }

  void _attach(BuildContext context) {
    final authStore = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);
    _sub ??= InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          if (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) {
            try {
              await _deliverPurchase(authStore.token, p);
              await _acknowledge(p);
              if (!messenger.mounted) continue;

              final api = ApiClient()..setToken(authStore.token);
              final data = DataService(api);
              final me = await data.getMe();
              final isPro = (me['is_pro'] == true) || (me['is_pro'] == 1);

              if (isPro) {
                await authStore.setLocalPro(true);
                authStore.setServerPro(true);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Pro activated. Thanks!')),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Purchase received. Your subscription is still syncing.',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (messenger.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Purchase received, but activation failed: $e',
                    ),
                  ),
                );
              }
            }
          } else if (p.status == PurchaseStatus.error) {
            if (messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Purchase failed: ${p.error}')),
              );
            }
          }
        }
      },
      onDone: () {
        _sub?.cancel();
        _sub = null;
      },
    );
  }

  Future<void> purchasePro(BuildContext context) async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store unavailable on this device')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    _attach(context);
    final resp = await InAppPurchase.instance.queryProductDetails(kIds);
    if (resp.error != null || resp.productDetails.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found. Configure the store product id.'),
          ),
        );
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
