import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/accounts_screen_new.dart';
import 'screens/invoices_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/transactions_v2_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/investments_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen.dart';
import 'services/api.dart';
import 'services/data_service.dart';
import 'widgets/new_transaction_dialog.dart';
import 'widgets/non_pro_banner_ad.dart';
import 'widgets/non_pro_interstitial_ad_controller.dart';
import 'state/auth_store.dart';
import 'state/refresh_bus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/pro_widgets.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'lang_store.dart';
import 'theme_mode_store.dart';
import 'i18n.dart';
import 'widgets/quick_create_dialogs.dart';
import 'liquid_glass/liquid_glass.dart';

import 'services/push_service.dart';
import 'services/purchase_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    // The backend validates legacy App Store receipts via verifyReceipt.
    // StoreKit 2 returns transaction JWS data instead, so keep iOS on StoreKit 1
    // until the server supports App Store Server API/JWS validation.
    // ignore: deprecated_member_use
    await InAppPurchaseStoreKitPlatform.enableStoreKit1();
  }
  unawaited(_initializeMobileAds());
  runApp(const FinancialBoardRoot());
  unawaited(_initializeStartupServices());
}

Future<void> _initializeMobileAds() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  try {
    await MobileAds.instance.initialize();
  } catch (e, stack) {
    debugPrint('Ads init failed: $e\n$stack');
  }
}

Future<void> _initializeStartupServices() async {
  try {
    await NativeWidgetBridge.ensureInitialized();
  } catch (e, stack) {
    debugPrint('Widget init failed: $e\n$stack');
  }
  try {
    await PushService.instance.init().timeout(const Duration(seconds: 12));
  } catch (e) {
    // Don't block app startup if push init fails or takes too long.
    debugPrint('Push init failed: $e');
  }
}

class FinancialBoardRoot extends StatelessWidget {
  const FinancialBoardRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStore()..load()),
        ChangeNotifierProvider(create: (_) => LangStore()..load()),
        ChangeNotifierProvider(create: (_) => ThemeModeStore()..load()),
        ChangeNotifierProvider(create: (_) => RefreshBus()),
      ],
      child: const FinancialBoardApp(),
    );
  }
}

class FinancialBoardApp extends StatelessWidget {
  const FinancialBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial Board',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: context.watch<ThemeModeStore>().mode,
      locale: context.watch<LangStore>().locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppGate(),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.hasToken) {
      return const LoginScreen();
    }
    return Stack(
      children: [const HomeShell(), if (auth.isLocked) const LockScreen()],
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Center Home like the design
  int _currentIndex = 2; // Stats, Transfers, Home, Payments, Account
  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();
  String _currentRouteName = '/root';
  late final _ContentNavObserver _contentObserver = _ContentNavObserver(
    _handleRouteChanged,
  );
  StreamSubscription<Uri>? _widgetSubscription;
  StreamSubscription<PushAction>? _pushSubscription;
  bool _processingWidgetAction = false;
  bool _adEntitlementStateKnown = false;
  final GlobalKey<PopupMenuButtonState<String>> _profileMenuKey =
      GlobalKey<PopupMenuButtonState<String>>();

  // Order (bottom nav): Stats, Transfers, Home, Payments, Account
  // Projects and Invoices moved to side drawer
  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const AnalyticsScreen();
      case 1:
        return const TransactionsScreen();
      case 2:
        return const DashboardScreen();
      case 3:
        return const PaymentsScreen();
      case 4:
        return const AccountsScreenNew();
      default:
        return const DashboardScreen();
    }
  }

  void _setTab(int index) {
    setState(() => _currentIndex = index);
    final Widget page = _buildTab(index);
    // Replace nested content with the exact target page to avoid stale index issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentNavKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/root'),
          builder: (_) => page,
        ),
        (route) => false,
      );
    });
  }

  void _onTab(int index) {
    _setTab(index);
  }

  @override
  void initState() {
    super.initState();
    NonProInterstitialAdController.clearEntitlementState();
    // One-time Play Billing sync after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final authStore = context.read<AuthStore>();
        await PurchaseService().initialize(context);
        final api = ApiClient()..setToken(authStore.token);
        final data = DataService(api);
        await data.syncPlay();
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          await data.syncAppStore();
        }
        // Sync Stripe entitlements too (web upgrades)
        try {
          await data.stripeSync();
        } catch (_) {}
        // Also refresh Pro flag from server in case user upgraded on Web (Stripe)
        try {
          final me = await data.getMe();
          final pro = (me['is_pro'] == true) || (me['is_pro'] == 1);
          if (!mounted) return;
          authStore.setServerPro(pro);
          if (!pro) await authStore.setLocalPro(false);
          NonProInterstitialAdController.markEntitlementKnownForUser(
            authStore.userId,
          );
          if (mounted) setState(() => _adEntitlementStateKnown = true);
        } catch (_) {}
      } catch (_) {}
    });
    _widgetSubscription = NativeWidgetBridge.widgetEvents.listen(
      _handleWidgetUri,
    );
    final initialUri = NativeWidgetBridge.consumeInitialUri();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleWidgetUri(initialUri),
      );
    }

    _pushSubscription = PushService.instance.actions.listen(_handlePushAction);
    final initialAction = PushService.instance.consumeInitialAction();
    if (initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handlePushAction(initialAction),
      );
    }
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    _pushSubscription?.cancel();
    NonProInterstitialAdController.clearEntitlementState();
    super.dispose();
  }

  void _handleRouteChanged(String? name) {
    final next = (name == null || name.isEmpty) ? '/unknown' : name;
    if (!mounted || next == _currentRouteName) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || next == _currentRouteName) return;
      setState(() => _currentRouteName = next);
    });
  }

  bool _isBannerRouteAllowed() {
    if (_currentRouteName == '/calendar') return true;
    if (_currentRouteName != '/root') return false;
    return _currentIndex == 1 ||
        _currentIndex == 2 ||
        _currentIndex == 3 ||
        _currentIndex == 4;
  }

  bool _shouldShowBannerAd(AuthStore auth) {
    if (!_adEntitlementStateKnown) return false;
    if (!auth.isAuthenticated || auth.isLocked || !auth.hasToken) return false;
    if (auth.isProOrExempt) return false;
    final shellRoute = ModalRoute.of(context);
    if (shellRoute != null && !shellRoute.isCurrent) return false;
    if (!_isBannerRouteAllowed()) return false;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return false;
    return true;
  }

  List<Widget> _buildAppBarActions() {
    return [
      _ShellIconButton(
        onPressed: _openNotifications,
        icon: Icons.notifications_none,
      ),
      const SizedBox(width: LGSpacing.xs),
      _buildProfileMenu(),
      const SizedBox(width: LGSpacing.sm),
    ];
  }

  Widget _buildProfileMenu({bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final menu = PopupMenuButton<String>(
      key: _profileMenuKey,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, LGSpacing.sm),
      color: LGColors.glassStrong(context),
      surfaceTintColor: Colors.transparent,
      shadowColor: Theme.of(context).shadowColor,
      elevation: LGColors.isDark(context) ? 14 : 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        side: BorderSide(color: LGColors.glassStroke(context)),
      ),
      constraints: const BoxConstraints(minWidth: 224),
      child: _ShellActionIcon(
        icon: Icons.person_outline,
        highlighted: highlight,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'guide':
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GuideScreen()));
            break;
          case 'settings':
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            break;
          case 'categories':
            await _openManageCategories();
            break;
          case 'privacy':
            await _openUrl('https://finsight.com.mx/privacy');
            break;
          case 'terms':
            await _openUrl('https://finsight.com.mx/terms');
            break;
          case 'logout':
            await context.read<AuthStore>().logout();
            break;
        }
      },
      // Important: use the parent BuildContext for i18n to avoid
      // listening from the popup overlay context (Provider error).
      itemBuilder:
          (menuCtx) => [
            PopupMenuItem(
              value: 'guide',
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.guide')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.settings')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'categories',
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.manageCategories')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'privacy',
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.privacy')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'terms',
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.terms')),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Text(I18n.tr(context, 'menu.logout')),
                ],
              ),
            ),
          ],
    );

    if (!highlight) return menu;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: menu,
    );
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final isPro = auth.isProOrExempt;
    final showBannerAd = _shouldShowBannerAd(auth);
    final shellBackground = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: shellBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const _GlassAppBarBackground(),
        title: Row(
          children: [
            SvgPicture.asset('assets/finsight-icon.svg', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('FinSight'),
          ],
        ),
        actions: _buildAppBarActions(),
      ),
      // Left-side drawer menu with entries moved from bottom nav
      drawer: Drawer(
        backgroundColor: shellBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              LGSpacing.lg,
              LGSpacing.lg,
              LGSpacing.lg,
              LGSpacing.xl,
            ),
            children: [
              LGGlassCard(
                variant: LGCardVariant.elevated,
                padding: const EdgeInsets.all(LGSpacing.lg),
                child: Row(
                  children: [
                    SvgPicture.asset('assets/finsight-icon.svg', height: 42),
                    const SizedBox(width: LGSpacing.md),
                    Text(
                      'FinSight',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LGSpacing.lg),
              _DrawerDestinationTile(
                icon: Icons.calendar_month_outlined,
                label: I18n.t(context, 'nav.calendar'),
                selected: _currentRouteName == '/calendar',
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/calendar');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.chat_bubble_outline,
                label: I18n.t(context, 'nav.aiChat'),
                trailing: isPro ? null : const ProMiniChip(),
                selected: _currentRouteName == '/ai-chat',
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/ai-chat');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.trending_up,
                label: I18n.t(context, 'title.investments'),
                trailing: isPro ? null : const ProMiniChip(),
                selected: _currentRouteName == '/investments',
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/investments');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.folder_open_outlined,
                label: I18n.t(context, 'nav.projects'),
                trailing: isPro ? null : const ProMiniChip(),
                selected: _currentRouteName == '/projects',
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/projects');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.description_outlined,
                label: I18n.t(context, 'nav.invoices'),
                trailing: isPro ? null : const ProMiniChip(),
                selected: _currentRouteName == '/invoices',
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/invoices');
                },
              ),
            ],
          ),
        ),
      ),
      // Nested Navigator keeps bottom nav visible when navigating
      body: ColoredBox(
        color: shellBackground,
        child: Stack(
          children: [
            Navigator(
              key: _contentNavKey,
              observers: [_contentObserver],
              initialRoute: '/root',
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/root':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => _buildTab(_currentIndex),
                    );
                  case '/calendar':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const CalendarScreen(),
                    );
                  case '/ai-chat':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const AiChatScreen(),
                    );
                  case '/investments':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const InvestmentsScreen(),
                    );
                  case '/projects':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const ProjectsScreen(),
                    );
                  case '/invoices':
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const InvoicesScreen(),
                    );
                  default:
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => _buildTab(_currentIndex),
                    );
                }
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBannerAd) const NonProBannerAd(),
          _BottomNavBar(current: _currentIndex, onTap: _onTab),
        ],
      ),
      floatingActionButton:
          _currentRouteName == '/ai-chat'
              ? null
              : _LiquidGlassFab(onPressed: () => _openAddMenu()),
    );
  }

  void _handleWidgetUri(Uri uri) {
    if (!mounted) return;
    final action = NativeWidgetBridge.actionFromUri(uri);
    if (action == null) return;
    switch (action) {
      case NativeWidgetBridge.actionCreateTransaction:
        _openQuickTransactionFromWidget();
        break;
      case NativeWidgetBridge.actionCreateRecurringPayment:
        _openQuickRecurringPaymentFromWidget();
        break;
    }
  }

  Future<void> _openQuickTransactionFromWidget() async {
    if (_processingWidgetAction) return;
    _processingWidgetAction = true;
    try {
      if (!mounted) return;
      final bool? ok = await showNewTransactionDialog(context, null);
      if (ok == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'tx.added'))));
      }
    } catch (e, stack) {
      debugPrint('Quick transaction launch failed: $e\n$stack');
    } finally {
      _processingWidgetAction = false;
    }
  }

  Future<void> _openQuickRecurringPaymentFromWidget() async {
    if (_processingWidgetAction) return;
    _processingWidgetAction = true;
    try {
      if (!mounted) return;
      await showQuickNewPaymentDialog(context);
    } catch (e, stack) {
      debugPrint('Quick recurring payment launch failed: $e\n$stack');
    } finally {
      _processingWidgetAction = false;
    }
  }

  void _openAddMenu() async {
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    final data = DataService(api);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isPro = context.watch<AuthStore>().isProOrExempt;
        return LGBottomSheetShell(
          solidContent: true,
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddMenuAction(
                icon: Icons.swap_horiz,
                label: I18n.t(context, 'add.newTransaction'),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showNewTransactionDialog(context, data);
                  if (ok == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(I18n.tr(context, 'tx.added'))),
                    );
                  }
                },
              ),
              _AddMenuAction(
                icon: Icons.event_repeat,
                label: I18n.t(context, 'add.newRecurringPayment'),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewPaymentDialog(context);
                },
              ),
              _AddMenuAction(
                icon: Icons.account_balance_wallet_outlined,
                label: I18n.t(context, 'add.newAccount'),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewAccountDialog(context);
                },
              ),
              _AddMenuAction(
                icon: Icons.trending_up,
                label: I18n.t(context, 'add.newInvestment'),
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isPro) {
                    // Navigate to Investments page; ProBlock will be shown there
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InvestmentsScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InvestmentsScreen(autoOpen: true),
                      ),
                    );
                  }
                },
              ),
              _AddMenuAction(
                icon: Icons.folder_open_outlined,
                label: I18n.t(context, 'add.newProject'),
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isPro) {
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProjectsScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  await showQuickNewProjectDialog(context);
                },
              ),
              _AddMenuAction(
                icon: Icons.description_outlined,
                label: I18n.t(context, 'add.newInvoice'),
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isPro) {
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InvoicesScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  await showQuickNewInvoiceDialog(context);
                },
              ),
              _AddMenuAction(
                icon: Icons.person_add_alt_1_outlined,
                label: I18n.t(context, 'add.newCustomer'),
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isPro) {
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InvoicesScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  await showQuickNewCustomerDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
      }
    }
  }

  Future<void> _openNotifications() async {
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    final data = DataService(api);
    List<Map<String, dynamic>> notifs = [];
    try {
      notifs = await data.getNotifications(days: 7);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        if (notifs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No notifications'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final n = notifs[i];
            final type = (n['type'] as String? ?? '');
            final title = n['title'] as String? ?? '';
            final msg = n['message'] as String? ?? '';
            final icon =
                type == 'invoice_due'
                    ? Icons.description_outlined
                    : Icons.payments_outlined;
            return ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(msg),
            );
          },
        );
      },
    );
  }

  void _handlePushAction(PushAction action) {
    if (!mounted) return;
    switch (action.targetType) {
      case 'payment':
        _openPaymentFromNotification(action.targetId);
        break;
      case 'project':
        _openProjectFromNotification(action.targetId);
        break;
      case 'subcategory':
        _openCategoriesFromNotification();
        break;
      default:
        break;
    }
  }

  void _openPaymentFromNotification(int paymentId) {
    setState(() => _currentIndex = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentNavKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PaymentsScreen(openPaymentId: paymentId),
        ),
        (route) => false,
      );
    });
  }

  void _openProjectFromNotification(int projectId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentNavKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ProjectsScreen(openProjectId: projectId),
        ),
      );
    });
  }

  void _openCategoriesFromNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentNavKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
      );
    });
  }
}

class _GlassAppBarBackground extends StatelessWidget {
  const _GlassAppBarBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LGGlassSurface(
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          blur: LGBlur.medium,
          intensity: LGGlassIntensity.strong,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          child: const SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(
            color:
                LGColors.isDark(context)
                    ? LGColors.glassStrokeDark
                    : const Color(0xFFE2E8F0),
            child: const SizedBox(height: 1, width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _ShellIconButton extends StatelessWidget {
  const _ShellIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LGGlassSurface(
      blur: LGBlur.subtle,
      intensity: LGGlassIntensity.medium,
      borderRadius: BorderRadius.circular(LGRadius.lg),
      padding: EdgeInsets.zero,
      shadows: LGShadows.none,
      child: SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: LGColors.textPrimary(context),
        ),
      ),
    );
  }
}

class _ShellActionIcon extends StatelessWidget {
  const _ShellActionIcon({required this.icon, this.highlighted = false});

  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return LGGlassSurface(
      blur: LGBlur.subtle,
      intensity:
          highlighted ? LGGlassIntensity.strong : LGGlassIntensity.medium,
      borderRadius: BorderRadius.circular(LGRadius.lg),
      padding: EdgeInsets.zero,
      shadows: LGShadows.none,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          icon,
          color:
              highlighted
                  ? LGColors.primaryBlue
                  : LGColors.textPrimary(context),
        ),
      ),
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent =
        selected ? LGColors.primaryBlue : LGColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.sm),
      child: LGSolidCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LGSpacing.md,
          vertical: LGSpacing.sm,
        ),
        tinted: selected,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    selected
                        ? LGColors.primaryBlue.withValues(alpha: 0.12)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(LGRadius.md),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: LGSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LGColors.textPrimary(context),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: LGSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AddMenuAction extends StatelessWidget {
  const _AddMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.sm),
      child: LGSolidCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LGSpacing.md,
          vertical: LGSpacing.md,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LGColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(LGRadius.md),
              ),
              child: Icon(icon, color: LGColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: LGSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LGColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: LGSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassFab extends StatelessWidget {
  const _LiquidGlassFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = LGColors.isDark(context);
    return Semantics(
      button: true,
      child: Material(
        color: LGColors.primaryBlue,
        elevation: 12,
        shadowColor: LGColors.primaryBlue.withValues(
          alpha: isDark ? 0.42 : 0.28,
        ),
        borderRadius: BorderRadius.circular(LGRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                right: 10,
                top: 6,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.34),
                  child: const SizedBox(height: 1),
                ),
              ),
              const SizedBox(
                width: 58,
                height: 58,
                child: Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AuthStore>().isProOrExempt;
    final items = [
      (Icons.show_chart, I18n.t(context, 'nav.stats')),
      (Icons.swap_horiz, I18n.t(context, 'nav.transactions')),
      (Icons.receipt_long_outlined, I18n.t(context, 'nav.home')),
      (Icons.event_note_outlined, I18n.t(context, 'nav.payments')),
      (Icons.account_balance_wallet_outlined, I18n.t(context, 'nav.account')),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: LGGlassSurface(
                      blur: LGBlur.subtle,
                      intensity:
                          LGColors.isDark(context)
                              ? LGGlassIntensity.medium
                              : LGGlassIntensity.strong,
                      borderRadius: BorderRadius.circular(LGRadius.pill),
                      shadows: LGShadows.floating(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: LGSpacing.sm,
                        vertical: LGSpacing.xs,
                      ),
                      child: SizedBox(
                        height: 68,
                        child: Row(
                          children: List.generate(items.length, (i) {
                            final isHome = i == 2;
                            return Expanded(
                              child: _MagicNavItem(
                                icon: items[i].$1,
                                label: items[i].$2,
                                selected: current == i,
                                isHome: isHome,
                                showPro: !isPro && i == 0,
                                onTap: () => onTap(i),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _MagicCenterNavButton(
                icon: items[2].$1,
                selected: current == 2,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicNavItem extends StatelessWidget {
  const _MagicNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isHome,
    required this.showPro,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isHome;
  final bool showPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = LGColors.textSecondary(context);
    final active = LGColors.primaryBlue;
    final textColor =
        selected ? active : (isHome ? active.withValues(alpha: 0.72) : muted);
    final iconColor =
        selected ? active : (isHome ? active.withValues(alpha: 0.72) : muted);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LGRadius.xl),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: EdgeInsets.only(
                  left: LGSpacing.xs,
                  right: LGSpacing.xs,
                  top: isHome ? 24 : 6,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      selected && !isHome
                          ? LGColors.primaryBlue.withValues(
                            alpha: LGColors.isDark(context) ? 0.16 : 0.08,
                          )
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(LGRadius.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isHome)
                      Icon(icon, size: 23, color: iconColor)
                    else
                      const SizedBox(height: 10),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showPro)
                const Positioned(top: 1, right: 4, child: ProMiniChip()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MagicCenterNavButton extends StatelessWidget {
  const _MagicCenterNavButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = LGColors.isDark(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isDark
                      ? LGColors.glassStrong(context)
                      : LGColors.surfaceSolid(context),
              border: Border.all(
                color:
                    selected
                        ? LGColors.primaryBlue.withValues(alpha: 0.36)
                        : LGColors.glassStroke(context),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: LGColors.primaryBlue.withValues(
                    alpha: isDark ? 0.30 : 0.18,
                  ),
                  blurRadius: selected ? 28 : 18,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: LGColors.alpha(Colors.black, isDark ? 0.34 : 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    selected
                        ? LGColors.primaryBlue
                        : LGColors.primaryBlue.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                border: Border.all(
                  color: LGColors.primaryBlue.withValues(
                    alpha: selected ? 0.18 : 0.20,
                  ),
                ),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : LGColors.primaryBlue,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentNavObserver extends NavigatorObserver {
  _ContentNavObserver(this.onRouteChanged);

  final ValueChanged<String?> onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteChanged(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteChanged(previousRoute?.settings.name);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onRouteChanged(newRoute?.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
