import 'package:flutter/material.dart';
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

import 'services/push_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NativeWidgetBridge.ensureInitialized();
  } catch (e, stack) {
    debugPrint('Widget init failed: $e\n$stack');
  }
  try {
    await PushService.instance.init();
  } catch (e) {
    // Don't block app startup if push init fails
    debugPrint('Push init failed: $e');
  }
  runApp(const FinancialBoardRoot());
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
      children: [
        const HomeShell(),
        if (auth.isLocked) const LockScreen(),
      ],
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
  late final _ContentNavObserver _contentObserver = _ContentNavObserver(_handleRouteChanged);
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
        final api = ApiClient()..setToken(context.read<AuthStore>().token);
        final data = DataService(api);
        await data.syncPlay();
        // Sync Stripe entitlements too (web upgrades)
        try {
          await data.stripeSync();
        } catch (_) {}
        // Also refresh Pro flag from server in case user upgraded on Web (Stripe)
        try {
          final me = await data.getMe();
          final pro = (me['is_pro'] == true) || (me['is_pro'] == 1);
          if (context.mounted) {
            context.read<AuthStore>().setServerPro(pro);
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
      IconButton(
        onPressed: _openNotifications,
        icon: const Icon(Icons.notifications_none),
      ),
      _buildProfileMenu(),
    ];
  }

  Widget _buildProfileMenu({bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final menu = PopupMenuButton<String>(
      key: _profileMenuKey,
      icon: Icon(
        Icons.person_outline,
        color: highlight ? cs.primary : null,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'guide':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GuideScreen()),
            );
            break;
          case 'settings':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
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
                  const Icon(
                    Icons.logout,
                    size: 20,
                    color: Colors.redAccent,
                  ),
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
            color: cs.primary.withOpacity(0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: menu,
    );
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManageCategoriesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              Center(
                child: SvgPicture.asset('assets/finsight-icon.svg', height: 48),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'FinSight',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(I18n.t(context, 'nav.calendar')),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/calendar');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(I18n.t(context, 'nav.aiChat')),
                trailing:
                    context.watch<AuthStore>().isProOrExempt
                        ? null
                        : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/ai-chat');
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(I18n.t(context, 'title.investments')),
                trailing:
                    context.watch<AuthStore>().isProOrExempt
                        ? null
                        : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/investments');
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(I18n.t(context, 'nav.projects')),
                trailing:
                    context.watch<AuthStore>().isProOrExempt
                        ? null
                        : const ProMiniChip(),
                onTap: () {
                  Navigator.of(context).pop();
                  _contentNavKey.currentState?.pushNamed('/projects');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(I18n.t(context, 'nav.invoices')),
                trailing:
                    context.watch<AuthStore>().isProOrExempt
                        ? null
                        : const ProMiniChip(),
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
      body: Stack(
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
      bottomNavigationBar: _BottomNavBar(
        current: _currentIndex,
        onTap: _onTab,
      ),
      floatingActionButton:
          _currentRouteName == '/ai-chat'
              ? null
              : FloatingActionButton(
                onPressed: () => _openAddMenu(),
                child: const Icon(Icons.add),
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
      showDragHandle: true,
      builder: (_) {
        final isPro = context.watch<AuthStore>().isProOrExempt;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(I18n.t(context, 'add.newTransaction')),
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
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: Text(I18n.t(context, 'add.newRecurringPayment')),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewPaymentDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(I18n.t(context, 'add.newAccount')),
                onTap: () async {
                  Navigator.pop(context);
                  await showQuickNewAccountDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(I18n.t(context, 'add.newInvestment')),
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
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(I18n.t(context, 'add.newProject')),
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
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(I18n.t(context, 'add.newInvoice')),
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
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: Text(I18n.t(context, 'add.newCustomer')),
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
              const SizedBox(height: 8),
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
          separatorBuilder: (_, __) => const Divider(height: 1),
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
        MaterialPageRoute(
          builder: (_) => const ManageCategoriesScreen(),
        ),
      );
    });
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.current,
    required this.onTap,
  });
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
    final cs = Theme.of(context).colorScheme;
    final inactive = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    return Material(
      color: cs.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final icon = items[i].$1;
              final label = items[i].$2;
              final isHome = i == 2; // Home is at index 2 now
              final selected = current == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavIcon(
                        icon: icon,
                        isHome: isHome,
                        selected: selected,
                        highlight: false,
                        colorScheme: cs,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style:
                              isHome
                                  ? Theme.of(
                                    context,
                                  ).textTheme.labelMedium?.copyWith(
                                    color:
                                        selected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  )
                                  : inactive,
                        ),
                      ),
                      // Show Pro chip only for Analytics (index 0)
                      if (!isPro && (i == 0)) const ProMiniChip(),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.isHome,
    required this.selected,
    required this.highlight,
    required this.colorScheme,
  });

  final IconData icon;
  final bool isHome;
  final bool selected;
  final bool highlight;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final base = isHome
        ? Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 26),
        )
        : Icon(
          icon,
          size: 22,
          color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        );

    if (!highlight) return base;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: base,
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
