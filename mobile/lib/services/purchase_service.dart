import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:provider/provider.dart';
import '../state/auth_store.dart';
import 'api.dart';
import 'data_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // Keep product ids explicit per platform so we never try to buy an arbitrary
  // product from the store response.
  static const List<String> _kIosProductIds = [
    '7T8M8X5R46',
    'finsight_pro_monthly',
    'finsight_monthly',
  ];
  static const List<String> _kAndroidProductIds = [
    'finsight_monthly',
    'finsight_pro_monthly',
  ];
  static final Set<String> kIds = {..._kIosProductIds, ..._kAndroidProductIds};

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _storeKitDelegateRegistered = false;

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _preferredProductIds() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _kIosProductIds;
    }
    return _kAndroidProductIds;
  }

  ProductDetails? _selectProduct(List<ProductDetails> products) {
    if (products.isEmpty) return null;
    final byId = {for (final product in products) product.id: product};
    for (final id in _preferredProductIds()) {
      final product = byId[id];
      if (product != null) return product;
    }
    return products.first;
  }

  String _missingProductMessage(ProductDetailsResponse response) {
    final missing =
        response.notFoundIDs.where(_preferredProductIds().contains).toList();
    if (missing.isNotEmpty) {
      return 'Subscription product is not available yet (${missing.join(', ')}).';
    }
    return 'Subscription product not found. Please try again later.';
  }

  Future<void> _configureStoreKit() async {
    if (_storeKitDelegateRegistered ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final iosPlatformAddition =
        InAppPurchase.instance
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await iosPlatformAddition.setDelegate(_FinSightPaymentQueueDelegate());
    _storeKitDelegateRegistered = true;
  }

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

  void _attach(AuthStore authStore, ScaffoldMessengerState messenger) {
    _sub ??= InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          debugPrint(
            'IAP update: status=${p.status} product=${p.productID} '
            'pendingComplete=${p.pendingCompletePurchase} error=${p.error}',
          );
          if (p.status == PurchaseStatus.pending) {
            _showSnackBar(messenger, 'Waiting for App Store confirmation...');
            continue;
          }

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
                  SnackBar(
                    content: Text(
                      p.status == PurchaseStatus.restored
                          ? 'Purchases restored. Pro is active.'
                          : 'Pro activated. Thanks!',
                    ),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      p.status == PurchaseStatus.restored
                          ? 'Restore received. Your subscription is still syncing.'
                          : 'Purchase received. Your subscription is still syncing.',
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
            await _acknowledgeIfNeeded(p);
            if (messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Purchase failed: ${p.error}')),
              );
            }
          } else if (p.status == PurchaseStatus.canceled) {
            await _acknowledgeIfNeeded(p);
            _showSnackBar(messenger, 'Purchase canceled.');
          }
        }
      },
      onError: (error) {
        _showSnackBar(messenger, 'Purchase stream error: $error');
      },
      onDone: () {
        _sub?.cancel();
        _sub = null;
      },
    );
  }

  Future<void> initialize(BuildContext context) async {
    final authStore = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);
    _attach(authStore, messenger);
    try {
      await _configureStoreKit();
    } catch (e) {
      debugPrint('Failed to configure StoreKit delegate: $e');
    }
  }

  Future<void> purchasePro(BuildContext context) async {
    final authStore = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);
    _attach(authStore, messenger);
    try {
      await _configureStoreKit();
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _showSnackBar(messenger, 'Store unavailable on this device');
        return;
      }
      final resp = await InAppPurchase.instance.queryProductDetails(kIds);
      debugPrint(
        'IAP products loaded: found=${resp.productDetails.map((p) => p.id).toList()} '
        'missing=${resp.notFoundIDs} error=${resp.error}',
      );
      if (resp.error != null) {
        _showSnackBar(
          messenger,
          'Could not load subscriptions: ${resp.error!.message}',
        );
        return;
      }
      final product = _selectProduct(resp.productDetails);
      if (product == null) {
        _showSnackBar(messenger, _missingProductMessage(resp));
        return;
      }
      final param = PurchaseParam(productDetails: product);
      _showSnackBar(messenger, 'Opening App Store...');
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _showSnackBar(messenger, 'Unable to start purchase: $e');
    }
  }

  Future<void> restorePurchases(BuildContext context) async {
    final authStore = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);
    _attach(authStore, messenger);
    try {
      await _configureStoreKit();
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _showSnackBar(messenger, 'Store unavailable on this device');
        return;
      }
      _showSnackBar(messenger, 'Restoring purchases...');
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _showSnackBar(messenger, 'Could not restore purchases: $e');
    }
  }

  Future<void> _acknowledgeIfNeeded(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(p);
    }
  }

  Future<void> _acknowledge(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(p);
    }
  }
}

class _FinSightPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return true;
  }
}
