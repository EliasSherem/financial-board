import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:provider/provider.dart';
import '../state/auth_store.dart';
import 'api.dart';
import 'analytics_service.dart';
import 'client_context.dart';
import 'data_service.dart';

String billingText(BuildContext context, String en, String es) =>
    Localizations.localeOf(context).languageCode == 'es' ? es : en;

/// Native store remains the durable purchase queue. Google ACK belongs to the
/// backend worker; StoreKit transactions are finished only after verification.
class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();
  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  AuthStore? _auth;
  ScaffoldMessengerState? _messenger;
  bool _es = false;
  int? _account;
  bool loading = false;
  bool busy = false;
  String? _flowId;
  int? _recoveredForUser;
  final Map<String, int> _attempts = {};
  final Map<String, GooglePlayPurchaseDetails> _owned = {};
  String? error;
  List<ProductDetails> products = [];
  Map<String, dynamic>? _config;
  final Map<String, ({PurchaseDetails purchase, int user})> _retry = {};
  Timer? _timer;
  final Set<String> _delivering = {};
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String _t(String en, String es) => _es ? es : en;
  void _message(String value) {
    final messenger = _messenger;
    if (messenger != null && messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(value)));
    }
  }

  DataService get _data => DataService(ApiClient()..setToken(_auth?.token));

  Future<void> initialize(BuildContext context) async {
    _messenger = ScaffoldMessenger.of(context);
    _es = Localizations.localeOf(context).languageCode == 'es';
    final auth = context.read<AuthStore>();
    if (_auth != auth) {
      _auth?.removeListener(_identityChanged);
      _auth = auth;
      auth.addListener(_identityChanged);
    }
    _identityChanged();
    if (kIsWeb) return;
    _sub ??= _store.purchaseStream.listen(
      _updates,
      onError:
          (_) => _message(
            _t(
              'Store connection interrupted. Try restoring purchases.',
              'Se interrumpió la tienda. Intenta restaurar las compras.',
            ),
          ),
      onDone: () {
        _sub = null;
      },
    );
    // Querying existing purchases recovers Android checkout after process death.
    if (!_ios && auth.isAuthenticated && _recoveredForUser != auth.userId) {
      _recoveredForUser = auth.userId;
      try {
        if (await _store.isAvailable()) await _store.restorePurchases();
      } catch (_) {}
    }
  }

  void _identityChanged() {
    final id = _auth?.userId;
    if (id == _account) {
      if (_auth?.isAuthenticated == true && _retry.isNotEmpty) {
        unawaited(() async {
          for (final item in _retry.values.toList()) {
            await _deliver(item.purchase, item.user);
          }
        }());
      }
      return;
    }
    _account = id;
    _retry.clear();
    _attempts.clear();
    _owned.clear();
    _recoveredForUser = null;
    _timer?.cancel();
    _timer = null;
    _config = null;
    products = [];
    error = null;
    busy = false;
    notifyListeners();
  }

  Future<void> loadProducts(BuildContext context) async {
    await initialize(context);
    if (loading || kIsWeb || _auth?.isAuthenticated != true) return;
    final user = _account;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final config = await _data.billingConfig();
      if (!await _store.isAvailable()) throw StateError('store_unavailable');
      final ids =
          ((config[_ios ? 'appleProductIds' : 'googleProductIds'] as List?) ??
                  [])
              .cast<String>()
              .toSet();
      if (ids.isEmpty) throw StateError('products_not_configured');
      final result = await _store.queryProductDetails(ids);
      if (result.error != null) throw StateError('store_query_failed');
      if (_account != user) return;
      _config = config;
      products =
          result.productDetails.where((p) => ids.contains(p.id)).toList();
      if (products.isEmpty)
        error = _t(
          'No subscription is available for this account.',
          'No hay una suscripción disponible para esta cuenta.',
        );
    } catch (_) {
      if (_account == user)
        error = _t(
          'Prices are unavailable. Check your connection and try again.',
          'Los precios no están disponibles. Revisa la conexión e inténtalo de nuevo.',
        );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _updates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        AnalyticsService.instance.event(
          'purchase_pending',
          flowId: _flowId,
          outcome: 'pending',
        );
        _message(
          _t(
            'Payment pending. Access starts after confirmation.',
            'Pago pendiente. El acceso empieza tras la confirmación.',
          ),
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase is GooglePlayPurchaseDetails)
          _owned[purchase.productID] = purchase;
        final user = _account;
        if (user != null) await _deliver(purchase, user);
      } else {
        busy = false;
        AnalyticsService.instance.event(
          'purchase_failed',
          flowId: _flowId,
          outcome:
              purchase.status == PurchaseStatus.canceled
                  ? 'canceled'
                  : 'failed',
        );
        // Failed/cancelled StoreKit transactions must also leave its unfinished queue.
        if (_ios && purchase.pendingCompletePurchase) {
          try {
            await _store.completePurchase(purchase);
          } catch (_) {}
        }
        _message(
          purchase.status == PurchaseStatus.canceled
              ? _t('Purchase canceled.', 'Compra cancelada.')
              : _t(
                'Purchase could not be completed. Try again or restore purchases if already owned.',
                'No se pudo completar la compra. Intenta de nuevo o restaura las compras si ya la tienes.',
              ),
        );
      }
    }
    notifyListeners();
  }

  Future<void> _deliver(
    PurchaseDetails purchase,
    int user, {
    bool retryLateUnlock = true,
  }) async {
    final key =
        '${purchase.productID}:${purchase.purchaseID ?? purchase.transactionDate}';
    if (_delivering.contains(key) || user != _account) return;
    if (_auth?.isAuthenticated != true) {
      _retry[key] = (purchase: purchase, user: user);
      return;
    }
    final sessionToken = _auth!.token;
    var parkedForLock = false;
    _delivering.add(key);
    try {
      final receipt = purchase.verificationData.serverVerificationData;
      final result =
          _ios
              ? await _data.linkAppStorePurchase(
                productId: purchase.productID,
                receiptData: receipt,
                transactionId: purchase.purchaseID,
                flowId: _flowId,
              )
              : await _data.linkPlayPurchase(
                productId: purchase.productID,
                purchaseToken: receipt,
                flowId: _flowId,
              );
      if (user != _account) return;
      if (result['verified'] != true) throw StateError('purchase_not_verified');
      if (_ios && purchase.pendingCompletePurchase)
        await _store.completePurchase(purchase);
      // Android: do not call completePurchase/acknowledge independently. The backend
      // persisted the verified grant and ACK job atomically, including retry after app kill.
      final me = await _data.getMe();
      if (user != _account) return;
      _auth!.setServerPro(me['is_pro'] == true || me['is_pro'] == 1);
      _retry.remove(key);
      _attempts.remove(key);
      if (purchase.status == PurchaseStatus.restored)
        AnalyticsService.instance.event(
          'restore_completed',
          outcome: 'success',
        );
      _message(
        _auth!.isPro
            ? _t(
              'Subscription verified. Pro is active.',
              'Suscripción verificada. Pro está activo.',
            )
            : _t(
              'Purchase verified. Access depends on its current store status.',
              'Compra verificada. El acceso depende de su estado actual en la tienda.',
            ),
      );
    } catch (error) {
      if (user == _account &&
          error is ApiException &&
          error.code == 'SESSION_LOCKED') {
        _retry[key] = (purchase: purchase, user: user);
        parkedForLock = true;
        return;
      }
      if (user == _account &&
          error is ApiException &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          error.statusCode != 429) {
        _retry.remove(key);
        _message(
          _t(
            'This purchase could not be linked. Sign in to the original FinSight account and restore it.',
            'No se pudo vincular la compra. Inicia sesión en la cuenta original de FinSight y restáurala.',
          ),
        );
        return;
      }
      final attempt = (_attempts[key] ?? 0) + 1;
      _attempts[key] = attempt;
      if (user == _account && attempt <= 5) {
        _retry[key] = (purchase: purchase, user: user);
        _timer ??= Timer(Duration(seconds: 30 * attempt), () async {
          _timer = null;
          final items = _retry.values.toList();
          for (final item in items) {
            if (item.user == _account) await _deliver(item.purchase, item.user);
          }
        });
        _message(
          _t(
            'Verification is pending. Your purchase is saved by the store; you can restore it after reconnecting.',
            'La verificación está pendiente. La tienda conserva tu compra; puedes restaurarla al reconectarte.',
          ),
        );
      }
    } finally {
      _delivering.remove(key);
      busy = false;
      notifyListeners();
      // Unlock may have occurred while this delivery still held its key. Its
      // listener then could not resume the queued purchase; release it first.
      if (parkedForLock &&
          retryLateUnlock &&
          user == _account &&
          _auth?.token == sessionToken &&
          _auth?.isAuthenticated == true) {
        unawaited(_deliver(purchase, user, retryLateUnlock: false));
      }
    }
  }

  String offerDescription(ProductDetails product, bool spanish) {
    String period(String value) {
      final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(value);
      if (match == null) return value;
      final count = match.group(1)!;
      final units =
          spanish
              ? {'D': 'días', 'W': 'semanas', 'M': 'meses', 'Y': 'años'}
              : {'D': 'days', 'W': 'weeks', 'M': 'months', 'Y': 'years'};
      return '$count ${units[match.group(2)]}';
    }

    if (product is GooglePlayProductDetails) {
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (index != null && offers != null && index < offers.length) {
        return offers[index].pricingPhases
            .map(
              (p) =>
                  '${p.formattedPrice} / ${period(p.billingPeriod)}${p.billingCycleCount > 0 ? ' × ${p.billingCycleCount}' : ''}',
            )
            .join(spanish ? ', después ' : ', then ');
      }
    }
    if (product is AppStoreProduct2Details) {
      final value = product.sk2Product.subscription?.subscriptionPeriod;
      if (value != null) {
        final units =
            spanish
                ? {
                  'day': 'días',
                  'week': 'semanas',
                  'month': 'meses',
                  'year': 'años',
                }
                : {
                  'day': 'days',
                  'week': 'weeks',
                  'month': 'months',
                  'year': 'years',
                };
        return '${product.price} / ${value.value} ${units[value.unit.name]}';
      }
    }
    return product.price;
  }

  Future<void> purchasePro(BuildContext context) async {
    if (busy) return;
    await loadProducts(context);
    if (!context.mounted || products.isEmpty) return;
    if (_config?['checkoutEnabled'] != true) {
      _message(
        _t(
          'Checkout is temporarily unavailable.',
          'Las compras no están disponibles temporalmente.',
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<ProductDetails>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('Choose your subscription', 'Elige tu suscripción'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final product in products)
                      ListTile(
                        title: Text(product.title),
                        subtitle: Text(offerDescription(product, _es)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(sheetContext, product),
                      ),
                    Text(
                      _t(
                        'Recurring plans renew automatically until canceled. Review the store confirmation for all terms.',
                        'Los planes recurrentes se renuevan hasta que los canceles. Revisa todas las condiciones en la confirmación de la tienda.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (chosen == null || !context.mounted) return;
    busy = true;
    _flowId = clientEventId();
    AnalyticsService.instance.event('checkout_started', flowId: _flowId);
    notifyListeners();
    try {
      final PurchaseParam param =
          chosen is GooglePlayProductDetails
              ? GooglePlayPurchaseParam(
                productDetails: chosen,
                offerToken: chosen.offerToken,
                applicationUserName: _config!['obfuscatedAccountId'] as String,
                changeSubscriptionParam:
                    _owned.isEmpty
                        ? null
                        : ChangeSubscriptionParam(
                          oldPurchaseDetails: _owned.values.last,
                        ),
              )
              : PurchaseParam(
                productDetails: chosen,
                applicationUserName: _config!['appleAppAccountToken'] as String,
              );
      if (!await _store.buyNonConsumable(purchaseParam: param)) {
        busy = false;
        _message(
          _t(
            'The store could not open checkout. Please try again.',
            'La tienda no pudo abrir la compra. Inténtalo de nuevo.',
          ),
        );
      }
    } catch (_) {
      busy = false;
      _message(
        _t(
          'Unable to start purchase. Try restoring purchases if already owned.',
          'No se pudo iniciar la compra. Si ya la tienes, intenta restaurarla.',
        ),
      );
    }
    notifyListeners();
  }

  Future<void> restorePurchases(BuildContext context) async {
    await initialize(context);
    try {
      await _store.restorePurchases();
      await _data.billingSync();
      _message(
        _t(
          'Restore requested. Verified purchases will appear shortly.',
          'Restauración solicitada. Las compras verificadas aparecerán pronto.',
        ),
      );
    } catch (_) {
      _message(
        _t(
          'Unable to restore now. Try again when connected.',
          'No se pudo restaurar. Inténtalo cuando tengas conexión.',
        ),
      );
    }
  }
}
