import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'state/auth_store.dart';
import 'state/refresh_bus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/pro_widgets.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'lang_store.dart';
import 'i18n.dart';
import 'widgets/quick_create_dialogs.dart';
import 'ui/finsight_ui.dart';

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
  runApp(const FinancialBoardRoot());
  unawaited(_initializeStartupServices());
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
          if (context.mounted) {
            authStore.setServerPro(pro);
            if (!pro) await authStore.setLocalPro(false);
          }
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
    super.dispose();
  }

  void _handleRouteChanged(String? name) {
    final next = (name == null || name.isEmpty) ? '/root' : name;
    if (!mounted || next == _currentRouteName) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || next == _currentRouteName) return;
      setState(() => _currentRouteName = next);
    });
  }

  List<Widget> _buildAppBarActions() {
    return [
      _ShellIconButton(
        onPressed: _openNotifications,
        icon: Icons.notifications_none_rounded,
      ),
      const SizedBox(width: FSSpacing.xs),
      _buildProfileMenu(),
      const SizedBox(width: FSSpacing.sm),
    ];
  }

  Widget _buildProfileMenu({bool highlight = false}) {
    final menu = PopupMenuButton<String>(
      key: _profileMenuKey,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, FSSpacing.sm),
      color: FSColors.surfaceElevated(context),
      surfaceTintColor: Colors.transparent,
      shadowColor: Theme.of(context).shadowColor,
      elevation: FSColors.isDark(context) ? 12 : 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FSRadius.lg),
        side: BorderSide(color: FSColors.border(context)),
      ),
      constraints: const BoxConstraints(minWidth: 224),
      child: _ShellActionIcon(
        icon: Icons.person_outline_rounded,
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
              child: _ShellMenuItem(
                icon: Icons.menu_book_outlined,
                label: I18n.tr(context, 'menu.guide'),
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: _ShellMenuItem(
                icon: Icons.settings_outlined,
                label: I18n.tr(context, 'menu.settings'),
              ),
            ),
            PopupMenuItem(
              value: 'categories',
              child: _ShellMenuItem(
                icon: Icons.category_outlined,
                label: I18n.tr(context, 'menu.manageCategories'),
              ),
            ),
            PopupMenuItem(
              value: 'privacy',
              child: _ShellMenuItem(
                icon: Icons.privacy_tip_outlined,
                label: I18n.tr(context, 'menu.privacy'),
              ),
            ),
            PopupMenuItem(
              value: 'terms',
              child: _ShellMenuItem(
                icon: Icons.article_outlined,
                label: I18n.tr(context, 'menu.terms'),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: _ShellMenuItem(
                icon: Icons.logout_rounded,
                label: I18n.tr(context, 'menu.logout'),
                color: FSColors.danger,
              ),
            ),
          ],
    );
    return menu;
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AuthStore>().isProOrExempt;
    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        leadingWidth: 60,
        leading: Builder(
          builder:
              (context) => Padding(
                padding: const EdgeInsets.only(left: FSSpacing.sm),
                child: _ShellIconButton(
                  icon: Icons.menu_rounded,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        ),
        titleSpacing: 0,
        title: const _ShellBrandTitle(),
        actions: _buildAppBarActions(),
      ),
      // Left-side drawer menu with entries moved from bottom nav
      drawer: Drawer(
        backgroundColor: FSColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(FSRadius.xl),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FSSpacing.lg,
              FSSpacing.lg,
              FSSpacing.lg,
              FSSpacing.xl,
            ),
            children: [
              const _DrawerBrandHeader(),
              const SizedBox(height: FSSpacing.lg),
              Divider(color: FSColors.border(context)),
              const SizedBox(height: FSSpacing.sm),
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
                selected: _currentRouteName == '/ai-chat',
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/ai-chat');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.trending_up,
                label: I18n.t(context, 'title.investments'),
                selected: _currentRouteName == '/investments',
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/investments');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.folder_open_outlined,
                label: I18n.t(context, 'nav.projects'),
                selected: _currentRouteName == '/projects',
                trailing: isPro ? null : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/projects');
                },
              ),
              _DrawerDestinationTile(
                icon: Icons.description_outlined,
                label: I18n.t(context, 'nav.invoices'),
                selected: _currentRouteName == '/invoices',
                trailing: isPro ? null : const ProMiniChip(),
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
      body: DecoratedBox(
        decoration: BoxDecoration(color: FSColors.background(context)),
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
      bottomNavigationBar: _BottomNavBar(current: _currentIndex, onTap: _onTab),
      floatingActionButton:
          _currentRouteName == '/ai-chat'
              ? null
              : FloatingActionButton(
                onPressed: () => _openAddMenu(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FSRadius.lg),
                ),
                child: const Icon(Icons.add_rounded),
              ),
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
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final isPro = context.watch<AuthStore>().isProOrExempt;
        return FSBottomSheetShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddMenuTile(
                icon: Icons.swap_horiz_rounded,
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
              _AddMenuTile(
                icon: Icons.event_repeat_rounded,
                label: I18n.t(context, 'add.newRecurringPayment'),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewPaymentDialog(context);
                },
              ),
              _AddMenuTile(
                icon: Icons.account_balance_wallet_outlined,
                label: I18n.t(context, 'add.newAccount'),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewAccountDialog(context);
                },
              ),
              _AddMenuTile(
                icon: Icons.trending_up_rounded,
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
              _AddMenuTile(
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
              _AddMenuTile(
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
              _AddMenuTile(
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

class _ShellBrandTitle extends StatelessWidget {
  const _ShellBrandTitle();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoTile(size: 34, iconSize: 22),
        const SizedBox(width: FSSpacing.sm),
        Text('FinSight', style: textStyle),
      ],
    );
  }
}

class _DrawerBrandHeader extends StatelessWidget {
  const _DrawerBrandHeader();

  @override
  Widget build(BuildContext context) {
    return FSCard(
      variant: FSCardVariant.subtle,
      padding: const EdgeInsets.all(FSSpacing.md),
      child: Row(
        children: [
          _LogoTile(size: 44, iconSize: 28),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Text(
              'FinSight',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.size, required this.iconSize});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FSColors.intentContainer(context, FSIntent.primary),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color: FSColors.intentBorder(context, FSIntent.primary),
        ),
      ),
      child: SvgPicture.asset(
        'assets/finsight-icon.svg',
        width: iconSize,
        height: iconSize,
      ),
    );
  }
}

class _ShellIconButton extends StatelessWidget {
  const _ShellIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: FSColors.surfaceElevated(context),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: FSColors.border(context)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
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
    final color =
        highlighted
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            highlighted
                ? FSColors.intentContainer(context, FSIntent.primary)
                : FSColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color:
              highlighted
                  ? FSColors.intentBorder(context, FSIntent.primary)
                  : FSColors.border(context),
        ),
        boxShadow: highlighted ? FSShadows.soft(context) : FSShadows.none,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _ShellMenuItem extends StatelessWidget {
  const _ShellMenuItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 20, color: itemColor),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: itemColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    final foreground =
        selected ? selectedColor : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FSSpacing.xs / 2),
      child: Material(
        color:
            selected
                ? FSColors.intentContainer(context, FSIntent.primary)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(FSRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FSRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.md,
              vertical: FSSpacing.sm,
            ),
            child: Row(
              children: [
                _ShellListIcon(icon: icon, selected: selected),
                const SizedBox(width: FSSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: FSSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellListIcon extends StatelessWidget {
  const _ShellListIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color =
        selected
            ? Theme.of(context).colorScheme.primary
            : FSColors.mutedText(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            selected
                ? FSColors.intentContainer(context, FSIntent.primary)
                : FSColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

class _AddMenuTile extends StatelessWidget {
  const _AddMenuTile({
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
      padding: const EdgeInsets.symmetric(vertical: FSSpacing.xs / 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FSRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FSRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.md,
              vertical: FSSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(color: FSColors.border(context)),
            ),
            child: Row(
              children: [
                _ShellListIcon(icon: icon, selected: true),
                const SizedBox(width: FSSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: FSSpacing.sm),
                  trailing!,
                ],
              ],
            ),
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
      (Icons.show_chart_rounded, I18n.t(context, 'nav.stats')),
      (Icons.swap_horiz_rounded, I18n.t(context, 'nav.transactions')),
      (Icons.receipt_long_outlined, I18n.t(context, 'nav.home')),
      (Icons.event_note_outlined, I18n.t(context, 'nav.payments')),
      (Icons.account_balance_wallet_outlined, I18n.t(context, 'nav.account')),
    ];
    return ColoredBox(
      color: FSColors.background(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: FSColors.border(context))),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            FSSpacing.sm,
            FSSpacing.sm,
            FSSpacing.sm,
            FSSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.xs,
              vertical: FSSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: FSColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(FSRadius.xl),
              border: Border.all(color: FSColors.border(context)),
              boxShadow: FSShadows.soft(context),
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final icon = items[i].$1;
                final label = items[i].$2;
                final selected = current == i;
                return Expanded(
                  child: _BottomNavItem(
                    icon: icon,
                    label: label,
                    selected: selected,
                    showPro: !isPro && i == 0,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showPro,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        selected
            ? Theme.of(context).colorScheme.primary
            : FSColors.mutedText(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(FSRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FSRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 54,
                  height: 34,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _NavIcon(icon: icon, selected: selected),
                      if (showPro)
                        Positioned(
                          top: -8,
                          right: -10,
                          child: Transform.scale(
                            scale: 0.78,
                            child: ProMiniChip(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 48 : 42,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
        borderRadius: BorderRadius.circular(FSRadius.pill),
      ),
      child: Icon(
        icon,
        size: selected ? 21 : 22,
        color: selected ? Colors.white : FSColors.mutedText(context),
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
