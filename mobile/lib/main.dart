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
import 'screens/update_profile_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/api.dart';
import 'services/data_service.dart';
import 'widgets/new_transaction_dialog.dart';
import 'state/auth_store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/pro_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'lang_store.dart';
import 'i18n.dart';
import 'widgets/quick_create_dialogs.dart';
import 'widgets/onboarding_coach.dart';

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
    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
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
  OnboardingStep _onboardingStep = OnboardingStep.done;
  bool _onboardingStarted = false;
  Completer<void>? _accountCompleter;
  Completer<void>? _categoriesCompleter;
  Completer<void>? _transactionCompleter;
  bool _transactionPromptOpen = false;
  OnboardingStep? _dismissedCoachStep;
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
        final onboardingAccount = _onboardingStep == OnboardingStep.account;
        return AccountsScreenNew(
          forceCreate: onboardingAccount,
          onAccountCreated: onboardingAccount ? _handleAccountCreated : null,
        );
      default:
        return const DashboardScreen();
    }
  }

  bool get _isOnboarding => _onboardingStep != OnboardingStep.done;

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
    if (_isOnboarding) {
      final required = _requiredOnboardingTab();
      if (required == null || index != required) {
        _showOnboardingBlocked();
        return;
      }
    }
    _setTab(index);
    if (_onboardingStep == OnboardingStep.transaction && index == 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _promptTransactionCreate(),
      );
    }
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
      await _maybeStartOnboarding();
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

  void _showOnboardingBlocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_onboardingBlockedMessage())),
    );
  }

  int? _requiredOnboardingTab() {
    switch (_onboardingStep) {
      case OnboardingStep.account:
        return 4;
      case OnboardingStep.transaction:
        return 1;
      default:
        return null;
    }
  }

  String _onboardingBlockedMessage() {
    switch (_onboardingStep) {
      case OnboardingStep.account:
        return I18n.t(context, 'onboarding.tapAccount');
      case OnboardingStep.categories:
        return I18n.t(context, 'onboarding.tapCategories');
      case OnboardingStep.transaction:
        return I18n.t(context, 'onboarding.tapTransactions');
      default:
        return I18n.t(context, 'onboarding.finishSetup');
    }
  }

  PreferredSizeWidget? _onboardingBanner() {
    if (!_isOnboarding || _dismissedCoachStep != _onboardingStep) {
      return null;
    }
    String? message;
    switch (_onboardingStep) {
      case OnboardingStep.account:
        message = I18n.t(context, 'onboarding.tapAccount');
        break;
      case OnboardingStep.categories:
        message = I18n.t(context, 'onboarding.tapCategories');
        break;
      case OnboardingStep.transaction:
        message = I18n.t(context, 'onboarding.tapTransactions');
        break;
      default:
        message = null;
    }
    if (message == null) return null;
    return PreferredSize(
      preferredSize: const Size.fromHeight(42),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.35),
            ),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String? _onboardingCoachMessage() {
    if (!_isOnboarding || _dismissedCoachStep == _onboardingStep) return null;
    switch (_onboardingStep) {
      case OnboardingStep.account:
        return I18n.t(context, 'onboarding.tapAccount');
      case OnboardingStep.categories:
        return I18n.t(context, 'onboarding.tapCategories');
      case OnboardingStep.transaction:
        return I18n.t(context, 'onboarding.tapTransactions');
      default:
        return null;
    }
  }

  Widget _buildOnboardingCoach() {
    final message = _onboardingCoachMessage();
    if (message == null) return const SizedBox.shrink();
    return OnboardingCoach(
      message: message,
      onOk: () => setState(() => _dismissedCoachStep = _onboardingStep),
    );
  }

  String _onboardingKey(String suffix, int userId) =>
      'onboarding_${suffix}_$userId';

  Future<String?> _promptLanguageSelection() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text('Choose your language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select the language for the app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'en'),
                      child: const Text('English'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 'es'),
                      child: const Text('Espanol'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _handleAccountCreated() {
    final completer = _accountCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _handleCategoriesUpdated() async {
    if (_onboardingStep != OnboardingStep.categories) return;
    await _checkCategoriesCompletion();
  }

  Future<void> _checkCategoriesCompletion() async {
    final completer = _categoriesCompleter;
    if (completer == null || completer.isCompleted || !mounted) return;
    final auth = context.read<AuthStore>();
    if (!auth.isAuthenticated) return;
    final api = ApiClient()..setToken(auth.token);
    final data = DataService(api);
    try {
      final categories = await data.getExpenseCategories();
      final done =
          categories.isNotEmpty &&
          categories.any((c) => c.subcategories.isNotEmpty);
      if (!done) return;
      final sp = await SharedPreferences.getInstance();
      final userId = auth.userId ?? 0;
      await sp.setBool(_onboardingKey('categories', userId), true);
      if (!completer.isCompleted) completer.complete();
    } catch (_) {}
  }

  Future<void> _promptTransactionCreate() async {
    if (_transactionPromptOpen) return;
    final completer = _transactionCompleter;
    if (completer == null || completer.isCompleted) return;
    _transactionPromptOpen = true;
    try {
      bool? ok;
      while (mounted && ok != true) {
        ok = await showNewTransactionDialog(context, null, forceCreate: true);
      }
      if (ok == true && mounted) {
        final sp = await SharedPreferences.getInstance();
        final userId = context.read<AuthStore>().userId ?? 0;
        await sp.setBool(_onboardingKey('tx', userId), true);
        if (!completer.isCompleted) completer.complete();
      }
    } finally {
      _transactionPromptOpen = false;
    }
  }

  Future<void> _maybeStartOnboarding() async {
    if (_onboardingStarted || !mounted) return;
    _onboardingStarted = true;
    final auth = context.read<AuthStore>();
    if (!auth.isAuthenticated) return;
    final sp = await SharedPreferences.getInstance();
    final userId = auth.userId ?? 0;
    final langKey = _onboardingKey('lang', userId);
    final accountKey = _onboardingKey('account', userId);
    final categoriesKey = _onboardingKey('categories', userId);
    final txKey = _onboardingKey('tx', userId);

    var langDone = sp.getBool(langKey) ?? false;
    if (!langDone) {
      if (!mounted) return;
      setState(() => _onboardingStep = OnboardingStep.language);
      final selected = await _promptLanguageSelection();
      if (!mounted || selected == null) return;
      await context.read<LangStore>().setLang(selected);
      await sp.setBool(langKey, true);
      langDone = true;
    }

    final api = ApiClient()..setToken(auth.token);
    final data = DataService(api);

    var accountDone = sp.getBool(accountKey) ?? false;
    if (!accountDone) {
      try {
        final accounts = await data.getAccounts();
        accountDone = accounts.isNotEmpty;
        if (accountDone) await sp.setBool(accountKey, true);
      } catch (_) {}
    }
    if (!accountDone) {
      if (!mounted) return;
      setState(() => _onboardingStep = OnboardingStep.account);
      _accountCompleter = Completer<void>();
      await _accountCompleter!.future;
      _accountCompleter = null;
      await sp.setBool(accountKey, true);
    }

    var categoriesDone = sp.getBool(categoriesKey) ?? false;
    if (!categoriesDone) {
      try {
        final categories = await data.getExpenseCategories();
        categoriesDone =
            categories.isNotEmpty &&
            categories.any((c) => c.subcategories.isNotEmpty);
        if (categoriesDone) await sp.setBool(categoriesKey, true);
      } catch (_) {}
    }
    if (!categoriesDone) {
      if (!mounted) return;
      setState(() => _onboardingStep = OnboardingStep.categories);
      _categoriesCompleter = Completer<void>();
      await _checkCategoriesCompletion();
      await _categoriesCompleter!.future;
      _categoriesCompleter = null;
      await sp.setBool(categoriesKey, true);
    }

    var txDone = sp.getBool(txKey) ?? false;
    if (!txDone) {
      try {
        final txs = await data.getTransactions();
        txDone = txs.isNotEmpty;
        if (txDone) await sp.setBool(txKey, true);
      } catch (_) {}
    }
    if (!txDone) {
      if (!mounted) return;
      setState(() => _onboardingStep = OnboardingStep.transaction);
      _transactionCompleter = Completer<void>();
      if (_currentIndex == 1) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _promptTransactionCreate(),
        );
      }
      await _transactionCompleter!.future;
      _transactionCompleter = null;
      await sp.setBool(txKey, true);
    }

    if (mounted) {
      setState(() => _onboardingStep = OnboardingStep.done);
    }
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
    if (_isOnboarding) {
      if (_onboardingStep == OnboardingStep.categories) {
        return [_buildProfileMenu(highlight: true)];
      }
      return [];
    }
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
        if (_isOnboarding) {
          if (_onboardingStep != OnboardingStep.categories ||
              value != 'categories') {
            _showOnboardingBlocked();
            return;
          }
        }
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
        builder:
            (_) => ManageCategoriesScreen(
              forceCreate: _onboardingStep == OnboardingStep.categories,
              onCategoryCreated: _handleCategoriesUpdated,
              onSubcategoryCreated: _handleCategoriesUpdated,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tie ApiClient token to AuthStore
    final auth = context.watch<AuthStore>();
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
        bottom: _onboardingBanner(),
      ),
      // Left-side drawer menu with entries moved from bottom nav
      drawer:
          _isOnboarding
              ? null
              : Drawer(
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
          if (_isOnboarding) _buildOnboardingCoach(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        current: _currentIndex,
        onTap: _onTab,
        highlightIndex: _requiredOnboardingTab(),
      ),
      floatingActionButton:
          _isOnboarding || _currentRouteName == '/ai-chat'
              ? null
              : FloatingActionButton(
                onPressed: () => _openAddMenu(),
                child: const Icon(Icons.add),
              ),
    );
  }

  void _handleWidgetUri(Uri uri) {
    if (!mounted) return;
    if (_isOnboarding) return;
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

  Future<void> _openUpdateProfile() async {
    final sp = await SharedPreferences.getInstance();
    String userJson = sp.getString('user') ?? '{}';
    Map<String, dynamic> user;
    try {
      user =
          userJson.isNotEmpty
              ? (jsonDecode(userJson) as Map<String, dynamic>)
              : {};
    } catch (_) {
      user = {};
    }
    final nameCtrl = TextEditingController(
      text: (user['username'] as String?) ?? '',
    );
    final emailCtrl = TextEditingController(
      text: (user['email'] as String?) ?? '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t(context, 'title.updateProfile'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'profile.username'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'profile.email'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () async {
                      final updated = {
                        ...user,
                        'username': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                      };
                      await sp.setString('user', jsonEncode(updated));
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: Text(I18n.t(context, 'label.save')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  // Drawer helper removed

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
    if (!mounted || _isOnboarding) return;
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
    super.key,
    required this.current,
    required this.onTap,
    this.highlightIndex,
  });
  final int current;
  final ValueChanged<int> onTap;
  final int? highlightIndex;

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
              final icon = items[i].$1 as IconData;
              final label = items[i].$2 as String;
              final isHome = i == 2; // Home is at index 2 now
              final selected = current == i;
              final highlight = highlightIndex == i;
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
                        highlight: highlight,
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

enum OnboardingStep { language, account, categories, transaction, done }
