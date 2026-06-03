import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../models.dart';
import '../i18n.dart';
import '../utils/format.dart';
import '../liquid_glass/liquid_glass.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late final DataService _data;
  List<PaymentItem> _payments = [];
  List<SalaryRule> _salaries = [];
  bool _loading = true;
  late final RefreshBus _refreshBus;
  int _paymentsTick = 0;

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _paymentsTick = _refreshBus.payments;
    _refreshBus.addListener(_handleRefresh);
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _load();
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _payments = await _data.getPayments();
    } catch (_) {}
    try {
      final rows = await _data.getSalaryRules();
      _salaries = rows.map((e) => SalaryRule.fromJson(e)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _handleRefresh() {
    if (!mounted) return;
    if (_refreshBus.payments != _paymentsTick) {
      _paymentsTick = _refreshBus.payments;
      _load();
    }
  }

  // Compute due dates for a given payment within the visible month, starting from its nextDate forward.
  List<DateTime> _occurrencesInMonth(PaymentItem p, DateTime month) {
    final List<DateTime> out = [];
    if (!p.isActive) return out;
    if (p.nextDate.isEmpty) return out;
    final next = parseYmdLocal(p.nextDate);
    if (next == null) return out;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0); // last day
    if (next.isAfter(end)) return out;
    // Use a non-null working variable
    var n = next!;
    // Advance to on/after start
    while (n.isBefore(start)) {
      final nn = _addFrequency(n, p.frequency);
      if (nn == null) return out;
      n = nn;
      if (n.isAfter(end)) return out;
    }
    // Collect occurrences inside the month
    while (!n.isAfter(end)) {
      if (n.month == month.month && n.year == month.year) {
        out.add(n);
      }
      final nn = _addFrequency(n, p.frequency);
      if (nn == null) break;
      n = nn;
    }
    return out;
  }

  DateTime? _addFrequency(DateTime d, String freq) {
    switch (freq) {
      case 'Weekly':
        return d.add(const Duration(days: 7));
      case 'Monthly':
        return DateTime(d.year, d.month + 1, d.day);
      case 'Quarterly':
        return DateTime(d.year, d.month + 3, d.day);
      case 'Yearly':
        return DateTime(d.year + 1, d.month, d.day);
      default:
        // Fallback to monthly if unknown
        return DateTime(d.year, d.month + 1, d.day);
    }
  }

  Map<String, List<PaymentItem>> _eventsForMonth(DateTime month) {
    final Map<String, List<PaymentItem>> byDay = {};
    for (final p in _payments) {
      for (final d in _occurrencesInMonth(p, month)) {
        final key = d.toIso8601String().substring(0, 10);
        byDay.update(key, (v) => [...v, p], ifAbsent: () => [p]);
      }
    }
    return byDay;
  }

  Map<String, List<SalaryRule>> _salaryEventsForMonth(DateTime month) {
    final Map<String, List<SalaryRule>> byDay = {};
    for (final r in _salaries.where((r) => r.isActive)) {
      for (final d in _salaryOccurrencesInMonth(r, month)) {
        final key = d.toIso8601String().substring(0, 10);
        byDay.update(key, (v) => [...v, r], ifAbsent: () => [r]);
      }
    }
    return byDay;
  }

  List<DateTime> _salaryOccurrencesInMonth(SalaryRule r, DateTime month) {
    final List<DateTime> out = [];
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    int lastDay = end.day;
    switch (r.schedule) {
      case 'SemiMonthly':
        for (final d in [15, 30]) {
          final day = d > lastDay ? lastDay : d;
          out.add(DateTime(month.year, month.month, day));
        }
        break;
      case 'Monthly':
        final d = (r.day ?? 1);
        final day = d > lastDay ? lastDay : (d < 1 ? 1 : d);
        out.add(DateTime(month.year, month.month, day));
        break;
      case 'Weekly':
        // r.weekday uses 1=Mon..7=Sun like DateTime.weekday
        final int target = (r.weekday ?? 1);
        // Compute first occurrence on/after start
        int delta = target - start.weekday;
        if (delta < 0) delta += 7;
        var first = start.add(Duration(days: delta));
        while (!first.isAfter(end)) {
          out.add(first);
          first = first.add(const Duration(days: 7));
        }
        break;
      default:
        break;
    }
    return out.where((d) => !d.isBefore(start) && !d.isAfter(end)).toList();
  }

  Future<void> _exportToCalendar(PaymentItem p, DateTime date) async {
    // Build Google Calendar template URL
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    String fmt(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    final title = Uri.encodeComponent(
      '${I18n.t(context, 'calendar.duePayment')}: ${p.name}',
    );
    final details = Uri.encodeComponent(
      'Amount: ' +
          money(p.amount) +
          (p.accountName != null ? '\nAccount: ${p.accountName}' : ''),
    );
    final url =
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=${fmt(start)}/${fmt(end)}';
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _exportSalaryToCalendar(SalaryRule r, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    String fmt(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    final title = Uri.encodeComponent('Salary: ${r.name}');
    final details = Uri.encodeComponent('Amount: ' + money(r.amount));
    final url =
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=${fmt(start)}/${fmt(end)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _eventsForMonth(_month);
    final bySalary = _salaryEventsForMonth(_month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday; // 1=Mon..7=Sun
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellsBefore = (firstWeekday % 7); // Make weeks start on Sunday
    final totalCells = cellsBefore + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _loading
              ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                children: [
                  _pageHeader(context),
                  const SizedBox(height: LGSpacing.md),
                  const LGLoadingState(),
                ],
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                children: [
                  _pageHeader(context),
                  const SizedBox(height: LGSpacing.md),
                  _monthControls(context),
                  const SizedBox(height: LGSpacing.md),
                  LGSolidCard(
                    variant: LGCardVariant.elevated,
                    padding: const EdgeInsets.all(LGSpacing.sm),
                    child: Column(
                      children: [
                        _weekHeader(context),
                        const SizedBox(height: LGSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cellHeight =
                                constraints.maxWidth < 380 ? 66.0 : 78.0;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 6,
                                    mainAxisExtent: cellHeight,
                                  ),
                              itemCount: rows * 7,
                              itemBuilder: (context, idx) {
                                final dayNum = idx - cellsBefore + 1;
                                if (dayNum < 1 || dayNum > daysInMonth) {
                                  return const SizedBox.shrink();
                                }
                                final date = DateTime(
                                  _month.year,
                                  _month.month,
                                  dayNum,
                                );
                                final now = DateTime.now();
                                final isToday =
                                    date.year == now.year &&
                                    date.month == now.month &&
                                    date.day == now.day;
                                final key = date.toIso8601String().substring(
                                  0,
                                  10,
                                );
                                final list = byDay[key] ?? const [];
                                final sals = bySalary[key] ?? const [];
                                final has = list.isNotEmpty || sals.isNotEmpty;
                                return _dayCell(
                                  context: context,
                                  dayNum: dayNum,
                                  isToday: isToday,
                                  hasEvents: has,
                                  eventCount: list.length + sals.length,
                                  onTap:
                                      has ? () => _openDay(date, list) : null,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _pageHeader(BuildContext context) {
    return LGPageHeader(
      title: I18n.t(context, 'title.calendar'),
      leading: _CalendarIconBox(
        icon: Icons.calendar_today_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 52,
      ),
    );
  }

  Widget _monthControls(BuildContext context) {
    return LGGlassCard(
      padding: const EdgeInsets.all(LGSpacing.md),
      borderRadius: BorderRadius.circular(LGRadius.xxl),
      child: Row(
        children: [
          _SoftIconButton(
            tooltip: 'Prev',
            icon: Icons.chevron_left,
            onPressed:
                () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1),
                ),
          ),
          Expanded(
            child: Text(
              DateFormat.yMMMM(
                Localizations.localeOf(context).toString(),
              ).format(_month),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LGColors.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _SoftIconButton(
            tooltip: 'Next',
            icon: Icons.chevron_right,
            onPressed:
                () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1),
                ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell({
    required BuildContext context,
    required int dayNum,
    required bool isToday,
    required bool hasEvents,
    required int eventCount,
    required VoidCallback? onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor =
        isToday
            ? primary.withValues(alpha: 0.70)
            : LGColors.textSecondary(context).withValues(alpha: 0.14);
    final background =
        hasEvents
            ? primary.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.08)
            : isToday
            ? primary.withValues(alpha: LGColors.isDark(context) ? 0.14 : 0.06)
            : LGColors.surfaceTinted(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(LGRadius.md),
            border: Border.all(color: borderColor, width: isToday ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayNum',
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                  color: isToday ? primary : LGColors.textPrimary(context),
                ),
              ),
              if (hasEvents) ...[
                const Spacer(),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _eventCountBadge(context, eventCount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventCountBadge(BuildContext context, int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
      child: Text(
        count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  void _openDay(DateTime date, List<PaymentItem> payments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sals =
            _salaryEventsForMonth(DateTime(date.year, date.month, 1))[date
                .toIso8601String()
                .substring(0, 10)] ??
            const [];
        if (payments.isEmpty && sals.isEmpty) {
          return LGBottomSheetShell(
            title: DateFormat.yMMMMd(
              Localizations.localeOf(context).toString(),
            ).format(date),
            child: LGEmptyState(
              icon: Icons.event_busy_outlined,
              title: I18n.t(context, 'calendar.noEvents'),
              message: DateFormat.yMMMMd(
                Localizations.localeOf(context).toString(),
              ).format(date),
            ),
          );
        }
        return LGBottomSheetShell(
          title: DateFormat.yMMMMd(
            Localizations.localeOf(context).toString(),
          ).format(date),
          child: Column(
            children: [
              for (var i = 0; i < payments.length; i++) ...[
                _paymentEventRow(payments[i], date),
                if (i != payments.length - 1 || sals.isNotEmpty)
                  const SizedBox(height: LGSpacing.sm),
              ],
              for (var i = 0; i < sals.length; i++) ...[
                _salaryEventRow(sals[i], date),
                if (i != sals.length - 1) const SizedBox(height: LGSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _weekHeader(BuildContext context) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: LGColors.textSecondary(context),
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.xs,
        vertical: LGSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LGColors.surfaceTinted(context),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(
          color: LGColors.textSecondary(context).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          for (final n in names)
            Expanded(child: Center(child: Text(n, style: style))),
        ],
      ),
    );
  }

  Widget _paymentEventRow(PaymentItem p, DateTime date) {
    return _eventRow(
      icon: Icons.payments_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      title: p.name,
      subtitle: '${p.frequency} • ${money(p.amount)}',
      action: LGButton(
        label: I18n.t(context, 'calendar.addToCalendar'),
        icon: Icons.event_available_outlined,
        size: LGButtonSize.sm,
        variant: LGButtonVariant.outline,
        onPressed: () => _exportToCalendar(p, date),
      ),
    );
  }

  Widget _salaryEventRow(SalaryRule r, DateTime date) {
    return _eventRow(
      icon: Icons.attach_money,
      iconColor: LGColors.success,
      title: r.name,
      subtitle:
          'Salary • ${money(r.amount)}${r.accountName != null ? ' • ${r.accountName}' : ''}',
      action: LGButton(
        label: I18n.t(context, 'calendar.addToCalendar'),
        icon: Icons.event_available_outlined,
        size: LGButtonSize.sm,
        variant: LGButtonVariant.outline,
        onPressed: () => _exportSalaryToCalendar(r, date),
      ),
    );
  }

  Widget _eventRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return LGSolidCard(
      tinted: true,
      padding: const EdgeInsets.all(LGSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CalendarIconBox(icon: icon, color: iconColor, size: 42),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: LGColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LGColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.md),
          action,
        ],
      ),
    );
  }
}

class _CalendarIconBox extends StatelessWidget {
  const _CalendarIconBox({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(
          size >= 48 ? LGRadius.lg : LGRadius.md,
        ),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size >= 48 ? 25 : 20),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.md),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.09,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

class SalaryRule {
  final String name;
  final double amount;
  final String schedule; // 'Weekly' | 'Monthly' | 'SemiMonthly'
  final int? weekday; // 1=Mon..7=Sun
  final int? day; // 1..31 for Monthly
  final bool isActive;
  final int? accountId;
  final String? accountName;

  SalaryRule({
    required this.name,
    required this.amount,
    required this.schedule,
    this.weekday,
    this.day,
    this.isActive = true,
    this.accountId,
    this.accountName,
  });

  factory SalaryRule.fromJson(Map<String, dynamic> j) => SalaryRule(
    name: j['name'] as String? ?? 'Salary',
    amount:
        (j['amount'] is num)
            ? (j['amount'] as num).toDouble()
            : double.tryParse('${j['amount']}') ?? 0.0,
    schedule: j['schedule'] as String? ?? 'SemiMonthly',
    weekday: (j['weekday'] as num?)?.toInt(),
    day: (j['day'] as num?)?.toInt(),
    isActive:
        (j['isActive'] == null)
            ? true
            : ((j['isActive'] == 1) || (j['isActive'] == true)),
    accountId:
        (j['accountId'] as num?)?.toInt() ?? (j['account_id'] as num?)?.toInt(),
    accountName: j['accountName'] as String? ?? j['account_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'schedule': schedule,
    if (weekday != null) 'weekday': weekday,
    if (day != null) 'day': day,
    'isActive': isActive,
    if (accountId != null) 'accountId': accountId,
    if (accountName != null) 'accountName': accountName,
  };
}
