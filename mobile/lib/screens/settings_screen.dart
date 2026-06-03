import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../services/purchase_service.dart';
import 'update_profile_screen.dart';
import '../lang_store.dart';
import '../state/auth_store.dart';
import '../models.dart';
import '../services/biometric_service.dart';
import '../utils/links.dart';
import '../utils/format.dart';
import '../utils/savings_goal.dart';
import '../state/refresh_bus.dart';
import '../liquid_glass/liquid_glass.dart';

const String _supportGptUrl =
    'https://chatgpt.com/g/g-68f9371179548191a018ea1e1ff99727-finsight-assistant';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _savingsGoal;
  bool _biometricAvailable = false;
  bool _biometricSupported = false;
  bool _biometricEnrolled = false;
  bool _biometricChecked = false;
  bool _repairingTransfers = false;
  final _biometric = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadSavingsGoal();
    _checkBiometric();
  }

  Future<void> _loadSavingsGoal() async {
    final userId = context.read<AuthStore>().userId;
    final goal = await SavingsGoalStore.load(userId);
    if (!mounted) return;
    setState(() => _savingsGoal = goal);
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) {
      if (mounted) setState(() => _biometricChecked = true);
      return;
    }
    final availability = await _biometric.availability();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = availability.isAvailable;
      _biometricSupported = availability.isSupported;
      _biometricEnrolled = availability.hasEnrollment;
      _biometricChecked = true;
    });
  }

  Future<void> _repairPastTransfers(
    DataService data,
    String Function(String en, String es) L,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(
                  L(
                    'Repair past transfers?',
                    '¿Corregir transferencias pasadas?',
                  ),
                ),
                content: Text(
                  L(
                    'This will convert old transfer records that were saved as income or expense into the Transfer type so analytics no longer counts them incorrectly.',
                    'Esto convertirá transferencias antiguas guardadas como ingreso o gasto al tipo Transfer para que la analítica deje de contarlas incorrectamente.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(L('Cancel', 'Cancelar')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(L('Repair', 'Corregir')),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _repairingTransfers = true);
    try {
      final result = await data.repairPastTransfers();
      RefreshBus.instance?.notifyTransactions();
      RefreshBus.instance?.notifyProjects();
      if (!mounted) return;
      final updated = (result['updated'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L(
              updated == 0
                  ? 'No past transfers needed repair.'
                  : 'Repaired $updated past transfer records.',
              updated == 0
                  ? 'No había transferencias pasadas por corregir.'
                  : 'Se corrigieron $updated transferencias pasadas.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${L('Failed', 'Error')}: $e')));
    } finally {
      if (mounted) setState(() => _repairingTransfers = false);
    }
  }

  String _goalInputValue() {
    final goal = _savingsGoal;
    if (goal == null) return '';
    final isWhole = goal.truncateToDouble() == goal;
    return goal.toStringAsFixed(isWhole ? 0 : 2);
  }

  Future<void> _editSavingsGoal(String Function(String en, String es) L) async {
    final userId = context.read<AuthStore>().userId;
    final messenger = ScaffoldMessenger.of(context);
    String draft = _goalInputValue();
    double? result;
    result = await showDialog<double?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(L('Monthly savings goal', 'Meta de ahorro mensual')),
            content: TextFormField(
              initialValue: draft,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: L('Amount', 'Monto'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => draft = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(L('Cancel', 'Cancelar')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 0.0),
                child: Text(L('Clear', 'Limpiar')),
              ),
              FilledButton(
                onPressed: () {
                  final raw = draft.trim();
                  if (raw.isEmpty) {
                    Navigator.pop(ctx, 0.0);
                    return;
                  }
                  final parsed = double.tryParse(raw.replaceAll(',', ''));
                  if (parsed == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          L('Enter a valid amount', 'Ingresa un monto valido'),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, parsed);
                },
                child: Text(L('Save', 'Guardar')),
              ),
            ],
          ),
    );
    if (!mounted || result == null) return;
    final goal = result <= 0 ? null : result;
    setState(() => _savingsGoal = goal);
    await SavingsGoalStore.save(userId, goal);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final api = ApiClient()..setToken(auth.token);
    final data = DataService(api);
    final langStore = context.watch<LangStore>();
    final isEs = langStore.lang == 'es';
    String L(String en, String es) => isEs ? es : en;
    final biometricReady = _biometricChecked && _biometricAvailable;
    final biometricEnabled = auth.biometricEnabled;
    final canEnableBiometric = biometricReady;
    final canToggleBiometric = biometricEnabled || canEnableBiometric;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final canPop = Navigator.of(context).canPop();
    final biometricSubtitle =
        !_biometricChecked
            ? L(
              'Checking device support...',
              'Verificando soporte del dispositivo...',
            )
            : !_biometricSupported
            ? L(
              'Not available on this device',
              'No disponible en este dispositivo',
            )
            : !_biometricEnrolled
            ? L(
              'Set up biometrics in device settings',
              'Configura biometria en ajustes del dispositivo',
            )
            : _biometricAvailable
            ? L(
              'Use fingerprint or face to sign in',
              'Usa huella o rostro para iniciar sesi\u00F3n',
            )
            : L(
              'Not available on this device',
              'No disponible en este dispositivo',
            );
    final showLock =
        auth.isAuthenticated && auth.biometricEnabled && biometricReady;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            LGSpacing.lg,
            LGSpacing.lg,
            LGSpacing.lg,
            120,
          ),
          children: [
            LGPageHeader(
              title: L('Settings', 'Ajustes'),
              subtitle: L(
                'Manage your account, preferences, and security.',
                'Administra tu cuenta, preferencias y seguridad.',
              ),
              leading:
                  canPop
                      ? const _SettingsBackButton()
                      : const _SettingsHeaderIcon(),
            ),
            const SizedBox(height: LGSpacing.md),
            LGGlassCard(
              variant: LGCardVariant.hero,
              child: Row(
                children: [
                  const _SettingsIconBox(
                    icon: Icons.person_outline,
                    intent: LGIntent.primary,
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L('FinSight account', 'Cuenta de FinSight'),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: LGColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.xs),
                        Text(
                          isIos
                              ? L(
                                'Profile, subscription, and secure device access.',
                                'Perfil, suscripción y acceso seguro del dispositivo.',
                              )
                              : L(
                                'Profile, preferences, and secure device access.',
                                'Perfil, preferencias y acceso seguro del dispositivo.',
                              ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: LGColors.textSecondary(context),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LGSpacing.xl),
            _SettingsSection(
              title: L('Account', 'Cuenta'),
              children: [
                _SettingsRow(
                  icon: Icons.person_outline,
                  title: L('Update Profile', 'Actualizar perfil'),
                  subtitle: L(
                    'Name, email, password',
                    'Nombre, correo, contraseña',
                  ),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UpdateProfileScreen(),
                        ),
                      ),
                ),
                if (isIos)
                  _SettingsRow(
                    icon: Icons.restore_outlined,
                    title: L('Restore purchases', 'Restaurar compras'),
                    subtitle: L(
                      'Sync your App Store subscription',
                      'Sincronizar tu suscripción de App Store',
                    ),
                    onTap: () => PurchaseService().restorePurchases(context),
                  ),
              ],
            ),
            _SettingsSection(
              title: L('Preferences', 'Preferencias'),
              children: [
                _SettingsRow(
                  icon: Icons.language_outlined,
                  title: L('Language', 'Idioma'),
                  subtitle: langStore.lang == 'es' ? 'Español' : 'English',
                  onTap: () async {
                    await showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      showDragHandle: false,
                      builder: (_) {
                        return LGBottomSheetShell(
                          title: L('Language', 'Idioma'),
                          solidContent: true,
                          child: RadioGroup<String>(
                            groupValue: langStore.lang,
                            onChanged: (value) {
                              Navigator.pop(context);
                              if (value != null) {
                                context.read<LangStore>().setLang(value);
                              }
                            },
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioListTile<String>(
                                  value: 'en',
                                  title: Text('English'),
                                ),
                                RadioListTile<String>(
                                  value: 'es',
                                  title: Text('Español'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                _SettingsRow(
                  icon: Icons.savings_outlined,
                  title: L('Savings goal', 'Meta de ahorro'),
                  subtitle:
                      _savingsGoal == null || _savingsGoal! <= 0
                          ? L('Not set', 'Sin meta')
                          : '${L('Monthly goal', 'Meta mensual')}: ${money(_savingsGoal!)}',
                  onTap: () => _editSavingsGoal(L),
                ),
              ],
            ),
            _SettingsSection(
              title: L('Security', 'Seguridad'),
              children: [
                _SettingsRow(
                  icon: Icons.fingerprint,
                  title: L('Biometric login', 'Inicio con biometr\u00EDa'),
                  subtitle: biometricSubtitle,
                  trailing: LGButton(
                    label:
                        biometricEnabled
                            ? L('Disable', 'Desactivar')
                            : L('Enable', 'Activar'),
                    size: LGButtonSize.sm,
                    variant:
                        biometricEnabled
                            ? LGButtonVariant.outline
                            : LGButtonVariant.primary,
                    onPressed:
                        canToggleBiometric
                            ? () async {
                              if (biometricEnabled) {
                                await auth.setBiometricEnabled(false);
                                return;
                              }
                              if (!canEnableBiometric) return;
                              final ok = await _biometric.authenticate(
                                reason: L(
                                  'Confirm biometrics to enable login',
                                  'Confirma biometria para habilitar el inicio',
                                ),
                              );
                              if (!ok) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        L(
                                          'Biometric authentication failed',
                                          'Fallo la autenticacion biometrica',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              await auth.setBiometricEnabled(true);
                            }
                            : null,
                  ),
                ),
                if (showLock)
                  _SettingsRow(
                    icon: Icons.lock_outline,
                    title: L('Lock', 'Bloquear'),
                    subtitle: L(
                      'Require biometrics to unlock',
                      'Requiere biometr\u00EDa para desbloquear',
                    ),
                    onTap: () async => auth.lock(),
                  ),
              ],
            ),
            _SettingsSection(
              title: L('Automation', 'Automatización'),
              children: [
                _SettingsRow(
                  icon: Icons.attach_money_outlined,
                  title: L('Automate salary income', 'Automatizar salario'),
                  subtitle: L(
                    'Schedule recurring salary deposits',
                    'Programa depósitos de salario recurrentes',
                  ),
                  onTap: () => _openSalaryAutomation(context),
                ),
                _SettingsRow(
                  icon: Icons.sync_problem_outlined,
                  title: L(
                    'Process overdue recurring payments',
                    'Procesar pagos recurrentes vencidos',
                  ),
                  onTap: () async {
                    try {
                      await data.processOverduePayments();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L(
                                'Processed overdue payments',
                                'Pagos vencidos procesados',
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${L('Failed', 'Error')}: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
                _SettingsRow(
                  icon: Icons.swap_horiz_outlined,
                  title: L(
                    'Repair past transfers',
                    'Corregir transferencias pasadas',
                  ),
                  subtitle: L(
                    'Fix old transfers that were counted as income or expense',
                    'Corrige transferencias antiguas que se contaron como ingreso o gasto',
                  ),
                  trailing:
                      _repairingTransfers
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : null,
                  onTap:
                      _repairingTransfers
                          ? null
                          : () => _repairPastTransfers(data, L),
                ),
                _SettingsRow(
                  icon: Icons.auto_graph_outlined,
                  title: L(
                    'Rebuild balance history',
                    'Reconstruir historial de saldo',
                  ),
                  subtitle: L(
                    'Recompute monthly balances for analytics',
                    'Recalcular saldos mensuales para analítica',
                  ),
                  onTap: () async {
                    try {
                      await data.rebuildBalanceHistory();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L('Rebuild started', 'Reconstrucción iniciada'),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${L('Failed', 'Error')}: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            _SettingsSection(
              title: L('Support', 'Soporte'),
              children: [
                _SettingsRow(
                  icon: Icons.help_outline,
                  title: L('Finsight Assistant', 'Asistente Finsight'),
                  subtitle: L('Open the support chat', 'Abrir chat de ayuda'),
                  onTap: () => openLink(context, _supportGptUrl),
                ),
              ],
            ),
            _SettingsSection(
              title: L('Session', 'Sesión'),
              children: [
                if (isIos)
                  _SettingsRow(
                    icon: Icons.person_remove_outlined,
                    title: L('Delete account', 'Eliminar cuenta'),
                    subtitle: L(
                      'Open the secure account deletion page',
                      'Abrir la página segura para eliminar la cuenta',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    danger: true,
                    onTap: () => openLink(context, kDeleteAccountUrl),
                  ),
                _SettingsRow(
                  icon: Icons.logout,
                  title: L('Logout', 'Cerrar sesión'),
                  danger: true,
                  onTap: () async {
                    await context.read<AuthStore>().logout();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeaderIcon extends StatelessWidget {
  const _SettingsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return const _SettingsIconBox(
      icon: Icons.settings_outlined,
      intent: LGIntent.primary,
      size: 56,
      iconSize: 26,
    );
  }
}

class _SettingsBackButton extends StatelessWidget {
  const _SettingsBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.pill),
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LGColors.surfaceTinted(context),
            borderRadius: BorderRadius.circular(LGRadius.pill),
            border: Border.all(
              color: LGColors.alpha(LGColors.textSecondary(context), 0.18),
            ),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: LGColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: LGSpacing.xs,
              bottom: LGSpacing.sm,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: LGColors.textSecondary(context),
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          LGSolidCard(
            padding: EdgeInsets.zero,
            variant: LGCardVariant.elevated,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      color: LGColors.alpha(
                        LGColors.textSecondary(context),
                        LGColors.isDark(context) ? 0.18 : 0.10,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final intent = danger ? LGIntent.danger : LGIntent.primary;
    final titleColor = danger ? LGColors.danger : LGColors.textPrimary(context);
    final content = Padding(
      padding: const EdgeInsets.all(LGSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SettingsIconBox(icon: icon, intent: intent),
          const SizedBox(width: LGSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: LGSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LGColors.textSecondary(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: LGSpacing.md),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: LGSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: LGColors.alpha(LGColors.textSecondary(context), 0.82),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _SettingsIconBox extends StatelessWidget {
  const _SettingsIconBox({
    required this.icon,
    required this.intent,
    this.size = 42,
    this.iconSize = 20,
  });

  final IconData icon;
  final LGIntent intent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = LGColors.intentColor(intent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LGColors.intentContainer(context, intent),
        borderRadius: BorderRadius.circular(
          size >= 52 ? LGRadius.xl : LGRadius.md,
        ),
        border: Border.all(color: LGColors.intentStroke(context, intent)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

Future<void> _openSalaryAutomation(BuildContext context) async {
  String L(String en, String es) =>
      context.read<LangStore>().lang == 'es' ? es : en;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder:
        (ctx) => LGBottomSheetShell(
          scrollable: false,
          maxHeightFactor: 0.92,
          child: _SalaryAutomationSheet(L: L),
        ),
  );
}

class _SalaryAutomationSheet extends StatefulWidget {
  const _SalaryAutomationSheet({required this.L});
  final String Function(String en, String es) L;
  @override
  State<_SalaryAutomationSheet> createState() => _SalaryAutomationSheetState();
}

class _SalaryAutomationSheetState extends State<_SalaryAutomationSheet> {
  List<Map<String, dynamic>> _rules = [];
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadAccounts();
  }

  Future<void> _load() async {
    try {
      final api = ApiClient()..setToken(context.read<AuthStore>().token);
      final data = DataService(api);
      final rows = await data.getSalaryRules();
      if (mounted) setState(() => _rules = rows);
    } catch (_) {
      if (mounted) setState(() => _rules = []);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final api = ApiClient()..setToken(context.read<AuthStore>().token);
      final data = DataService(api);
      final accs = await data.getAccounts();
      if (mounted) setState(() => _accounts = accs);
    } catch (_) {}
  }

  void _addOrEdit({Map<String, dynamic>? initial, int? index}) async {
    final nameCtrl = TextEditingController(text: initial?['name'] ?? 'Salary');
    final amountCtrl = TextEditingController(
      text: (initial?['amount']?.toString() ?? '0'),
    );
    String schedule = initial?['schedule'] ?? 'SemiMonthly';
    int weekday = (initial?['weekday'] as int?) ?? 1; // Mon
    int day = (initial?['day'] as int?) ?? 15;
    bool isActive =
        (initial?['isActive'] == null)
            ? true
            : ((initial?['isActive'] == 1) || (initial?['isActive'] == true));
    int? accountId =
        (initial?['accountId'] as int?) ??
        (_accounts.isNotEmpty ? _accounts.first.id : null);

    await showDialog<void>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (dctx, setLocal) => AlertDialog(
                  title: Text(widget.L('Salary rule', 'Regla de salario')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: widget.L('Name', 'Nombre'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: widget.L('Amount', 'Monto'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: accountId,
                          items:
                              _accounts.map((a) {
                                final isInvestment =
                                    (a.type ?? '').toLowerCase() ==
                                    'investment';
                                final baseName =
                                    a.name.trim().isEmpty
                                        ? widget.L('Account', 'Cuenta')
                                        : a.name;
                                final label =
                                    isInvestment
                                        ? '$baseName (${widget.L('Investment', 'Inversión')})'
                                        : baseName;
                                return DropdownMenuItem<int>(
                                  value: a.id,
                                  child: Text(label),
                                );
                              }).toList(),
                          onChanged: (v) => setLocal(() => accountId = v),
                          decoration: InputDecoration(
                            labelText: widget.L(
                              'Deposit account',
                              'Cuenta de depósito',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: schedule,
                          items: [
                            DropdownMenuItem(
                              value: 'SemiMonthly',
                              child: Text(
                                widget.L(
                                  'Semi-monthly (15 & 30)',
                                  'Quincenal (15 y 30)',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Monthly',
                              child: Text(
                                widget.L(
                                  'Monthly (day of month)',
                                  'Mensual (día del mes)',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Weekly',
                              child: Text(widget.L('Weekly', 'Semanal')),
                            ),
                          ],
                          onChanged:
                              (v) =>
                                  setLocal(() => schedule = v ?? 'SemiMonthly'),
                          decoration: const InputDecoration(
                            labelText: 'Schedule',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (schedule == 'Monthly')
                          TextField(
                            controller: TextEditingController(
                              text: day.toString(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => day = int.tryParse(v) ?? day,
                            decoration: InputDecoration(
                              labelText: widget.L(
                                'Day of month (1-31)',
                                'Día del mes (1-31)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        if (schedule == 'Weekly')
                          DropdownButtonFormField<int>(
                            initialValue: weekday,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text('Sun')),
                              DropdownMenuItem(value: 1, child: Text('Mon')),
                              DropdownMenuItem(value: 2, child: Text('Tue')),
                              DropdownMenuItem(value: 3, child: Text('Wed')),
                              DropdownMenuItem(value: 4, child: Text('Thu')),
                              DropdownMenuItem(value: 5, child: Text('Fri')),
                              DropdownMenuItem(value: 6, child: Text('Sat')),
                            ],
                            onChanged: (v) => setLocal(() => weekday = v ?? 1),
                            decoration: InputDecoration(
                              labelText: widget.L(
                                'Weekday',
                                'Día de la semana',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: isActive,
                          onChanged: (v) => setLocal(() => isActive = v),
                          title: Text(widget.L('Active', 'Activa')),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.L('Cancel', 'Cancelar')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final selectedName =
                            (_accounts
                                    .where((a) => a.id == accountId)
                                    .isNotEmpty)
                                ? _accounts
                                    .firstWhere((a) => a.id == accountId)
                                    .name
                                : 'Account';
                        final rule = {
                          'name':
                              nameCtrl.text.trim().isEmpty
                                  ? 'Salary'
                                  : nameCtrl.text.trim(),
                          'amount':
                              double.tryParse(
                                amountCtrl.text.replaceAll(',', ''),
                              ) ??
                              0,
                          'schedule': schedule,
                          if (schedule == 'Weekly') 'weekday': weekday,
                          if (schedule == 'Monthly') 'day': day,
                          'isActive': isActive,
                          'accountId': accountId,
                          'accountName': selectedName,
                        };
                        try {
                          final api =
                              ApiClient()
                                ..setToken(context.read<AuthStore>().token);
                          final data = DataService(api);
                          if (index != null && (_rules[index]['id'] != null)) {
                            await data.updateSalaryRule(
                              id: (_rules[index]['id'] as num).toInt(),
                              name: rule['name'] as String,
                              amount: rule['amount'] as double,
                              schedule: rule['schedule'] as String,
                              weekday: rule['weekday'] as int?,
                              day: rule['day'] as int?,
                              accountId: rule['accountId'] as int?,
                              isActive: rule['isActive'] as bool,
                            );
                          } else {
                            await data.createSalaryRule(
                              name: rule['name'] as String,
                              amount: rule['amount'] as double,
                              schedule: rule['schedule'] as String,
                              weekday: rule['weekday'] as int?,
                              day: rule['day'] as int?,
                              accountId: rule['accountId'] as int?,
                              isActive: rule['isActive'] as bool,
                            );
                          }
                          await _load();
                        } catch (_) {}
                        if (dctx.mounted) Navigator.pop(dctx);
                      },
                      child: Text(widget.L('Save', 'Guardar')),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.L(
                        'Salary automation',
                        'Automatización de salario',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addOrEdit(),
                    icon: const Icon(Icons.add),
                    label: Text(widget.L('Add', 'Agregar')),
                  ),
                ],
              ),
            ),
            if (_rules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.L('No salary rules yet', 'Sin reglas de salario'),
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _rules.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _rules[i];
                  String subtitle;
                  switch (r['schedule']) {
                    case 'Weekly':
                      subtitle = 'Weekly · ${r['weekday']}';
                      break;
                    case 'Monthly':
                      subtitle = 'Monthly · day ${r['day']}';
                      break;
                    default:
                      subtitle = 'Semi-monthly (15 & 30)';
                  }
                  return ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: Text(r['name'] ?? 'Salary'),
                    subtitle: Text(
                      '$subtitle • ${(r['accountName'] ?? 'Account')}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value:
                              (r['isActive'] == null)
                                  ? true
                                  : ((r['isActive'] == 1) ||
                                      (r['isActive'] == true)),
                          onChanged: (v) async {
                            try {
                              if (r['id'] != null) {
                                final api =
                                    ApiClient()..setToken(
                                      context.read<AuthStore>().token,
                                    );
                                final data = DataService(api);
                                await data.updateSalaryRule(
                                  id: (r['id'] as num).toInt(),
                                  isActive: v,
                                );
                              }
                            } catch (_) {}
                            await _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addOrEdit(initial: r, index: i),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            try {
                              if (r['id'] != null) {
                                final api =
                                    ApiClient()..setToken(
                                      context.read<AuthStore>().token,
                                    );
                                final data = DataService(api);
                                await data.deleteSalaryRule(
                                  (r['id'] as num).toInt(),
                                );
                              }
                            } catch (_) {}
                            await _load();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
