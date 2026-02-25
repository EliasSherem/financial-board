import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import 'update_profile_screen.dart';
import '../lang_store.dart';
import '../state/auth_store.dart';
import '../models.dart';
import '../services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/links.dart';
import '../utils/format.dart';
import '../utils/savings_goal.dart';

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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          L(
                            'Enter a valid amount',
                            'Ingresa un monto valido',
                          ),
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
    final showLock = auth.isAuthenticated && auth.biometricEnabled && biometricReady;
    return Scaffold(
      appBar: AppBar(title: Text(L('Settings', 'Ajustes'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.attach_money_outlined),
            title: Text(L('Automate salary income', 'Automatizar salario')),
            subtitle: Text(
              L(
                'Schedule recurring salary deposits',
                'Programa depósitos de salario recurrentes',
              ),
            ),
            onTap: () => _openSalaryAutomation(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(L('Update Profile', 'Actualizar perfil')),
            subtitle: Text(
              L('Name, email, password', 'Nombre, correo, contraseña'),
            ),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UpdateProfileScreen(),
                  ),
                ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(L('Biometric login', 'Inicio con biometr\u00EDa')),
            subtitle: Text(biometricSubtitle),
            trailing: FilledButton(
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
              child: Text(
                biometricEnabled ? L('Disable', 'Desactivar') : L('Enable', 'Activar'),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(L('Language', 'Idioma')),
            subtitle: Text(langStore.lang == 'es' ? 'Español' : 'English'),
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        value: 'en',
                        groupValue: langStore.lang,
                        onChanged: (v) {
                          Navigator.pop(context);
                          context.read<LangStore>().setLang('en');
                        },
                        title: const Text('English'),
                      ),
                      RadioListTile<String>(
                        value: 'es',
                        groupValue: langStore.lang,
                        onChanged: (v) {
                          Navigator.pop(context);
                          context.read<LangStore>().setLang('es');
                        },
                        title: const Text('Español'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(L('Savings goal', 'Meta de ahorro')),
            subtitle: Text(
              _savingsGoal == null || _savingsGoal! <= 0
                  ? L('Not set', 'Sin meta')
                  : '${L('Monthly goal', 'Meta mensual')}: ${money(_savingsGoal!)}',
            ),
            onTap: () => _editSavingsGoal(L),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(L('Finsight Assistant', 'Asistente Finsight')),
            subtitle: Text(
              L(
                'Open the support chat',
                'Abrir chat de ayuda',
              ),
            ),
            onTap: () => openLink(context, _supportGptUrl),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync_problem_outlined),
            title: Text(
              L(
                'Process overdue recurring payments',
                'Procesar pagos recurrentes vencidos',
              ),
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
                    SnackBar(content: Text(L('Failed', 'Error') + ': $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_graph_outlined),
            title: Text(
              L('Rebuild balance history', 'Reconstruir historial de saldo'),
            ),
            subtitle: Text(
              L(
                'Recompute monthly balances for analytics',
                'Recalcular saldos mensuales para analítica',
              ),
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
                    SnackBar(content: Text(L('Failed', 'Error') + ': $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          if (showLock)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(L('Lock', 'Bloquear')),
              subtitle: Text(
                L(
                  'Require biometrics to unlock',
                  'Requiere biometr\u00EDa para desbloquear',
                ),
              ),
              onTap: () async => auth.lock(),
            ),
          if (showLock) const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(L('Logout', 'Cerrar sesión')),
            onTap: () async {
              await context.read<AuthStore>().logout();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _openSalaryAutomation(BuildContext context) async {
  String L(String en, String es) =>
      context.read<LangStore>().lang == 'es' ? es : en;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _SalaryAutomationSheet(L: L),
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

  Future<void> _save() async {}

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
                          value: accountId,
                          items:
                              _accounts.map((a) {
                                final isInvestment =
                                    (a.type ?? '').toLowerCase() ==
                                    'investment';
                                final label = isInvestment ? ' ()' : a.name;
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
                          value: schedule,
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
                            value: weekday,
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
                        if (context.mounted) Navigator.pop(context);
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
                separatorBuilder: (_, __) => const Divider(height: 1),
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
