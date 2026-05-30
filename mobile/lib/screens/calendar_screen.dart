import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../models.dart';
import '../i18n.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
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
    var n = next;
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
      'Amount: ${money(p.amount)}${p.accountName != null ? '\nAccount: ${p.accountName}' : ''}',
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
    final details = Uri.encodeComponent('Amount: ${money(r.amount)}');
    final url =
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=${fmt(start)}/${fmt(end)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final byDay = _eventsForMonth(_month);
    final bySalary = _salaryEventsForMonth(_month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday; // 1=Mon..7=Sun
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellsBefore = (firstWeekday % 7); // Make weeks start on Sunday
    final totalCells = cellsBefore + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();

    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        title: Text(I18n.t(context, 'title.calendar')),
        backgroundColor: FSColors.background(context),
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
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
              ? const FSLoadingState()
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FSSpacing.lg,
                      FSSpacing.lg,
                      FSSpacing.lg,
                      FSSpacing.md,
                    ),
                    child: FSCard(
                      variant: FSCardVariant.subtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FSSpacing.sm,
                        vertical: FSSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          _CalendarNavButton(
                            tooltip: 'Prev',
                            icon: Icons.chevron_left_rounded,
                            onPressed:
                                () => setState(
                                  () =>
                                      _month = DateTime(
                                        _month.year,
                                        _month.month - 1,
                                        1,
                                      ),
                                ),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat.yMMMM(
                                Localizations.localeOf(context).toString(),
                              ).format(_month),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _CalendarNavButton(
                            tooltip: 'Next',
                            icon: Icons.chevron_right_rounded,
                            onPressed:
                                () => setState(
                                  () =>
                                      _month = DateTime(
                                        _month.year,
                                        _month.month + 1,
                                        1,
                                      ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FSSpacing.lg,
                    ),
                    child: FSCard(
                      variant: FSCardVariant.elevated,
                      padding: const EdgeInsets.all(FSSpacing.sm),
                      child: _weekHeader(context),
                    ),
                  ),
                  const SizedBox(height: FSSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FSSpacing.lg,
                        0,
                        FSSpacing.lg,
                        FSSpacing.xxl,
                      ),
                      child: FSCard(
                        variant: FSCardVariant.elevated,
                        padding: const EdgeInsets.all(FSSpacing.sm),
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: FSSpacing.sm,
                                crossAxisSpacing: FSSpacing.sm,
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
                            final key = date.toIso8601String().substring(0, 10);
                            final list = byDay[key] ?? const [];
                            final sals = bySalary[key] ?? const [];
                            final has = list.isNotEmpty || sals.isNotEmpty;
                            return _CalendarDayCell(
                              dayNum: dayNum,
                              isToday: isToday,
                              eventCount: list.length + sals.length,
                              onTap: has ? () => _openDay(date, list) : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  void _openDay(DateTime date, List<PaymentItem> payments) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sals =
            _salaryEventsForMonth(DateTime(date.year, date.month, 1))[date
                .toIso8601String()
                .substring(0, 10)] ??
            const [];
        final dateLabel = DateFormat.yMMMMd(
          Localizations.localeOf(context).toString(),
        ).format(date);
        if (payments.isEmpty && sals.isEmpty) {
          return FSBottomSheetShell(
            title: dateLabel,
            child: FSEmptyState(
              icon: Icons.event_busy_outlined,
              title: I18n.t(context, 'calendar.noEvents'),
            ),
          );
        }
        return FSBottomSheetShell(
          title: dateLabel,
          child: Column(
            children: [
              for (final p in payments)
                _CalendarEventCard(
                  icon: Icons.payments_outlined,
                  title: p.name,
                  subtitle: '${p.frequency} • ${money(p.amount)}',
                  intent: FSIntent.warning,
                  onExport: () => _exportToCalendar(p, date),
                  exportLabel: I18n.t(context, 'calendar.addToCalendar'),
                ),
              for (final r in sals)
                _CalendarEventCard(
                  icon: Icons.attach_money,
                  title: r.name,
                  subtitle:
                      'Salary • ${money(r.amount)}'
                      '${r.accountName != null ? ' • ${r.accountName}' : ''}',
                  intent: FSIntent.success,
                  onExport: () => _exportSalaryToCalendar(r, date),
                  exportLabel: I18n.t(context, 'calendar.addToCalendar'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _weekHeader(BuildContext context) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: FSColors.mutedText(context),
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.xs,
        vertical: FSSpacing.xs,
      ),
      child: Row(
        children: [
          for (final n in names)
            Expanded(child: Center(child: Text(n, style: style))),
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(42),
        backgroundColor: FSColors.intentContainer(context, FSIntent.primary),
        foregroundColor: FSColors.primary,
        side: BorderSide(
          color: FSColors.intentBorder(context, FSIntent.primary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.dayNum,
    required this.isToday,
    required this.eventCount,
    required this.onTap,
  });

  final int dayNum;
  final bool isToday;
  final int eventCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvents = eventCount > 0;
    final borderColor =
        isToday
            ? FSColors.primary
            : hasEvents
            ? FSColors.intentBorder(context, FSIntent.info)
            : FSColors.border(context);
    final backgroundColor =
        hasEvents
            ? FSColors.intentContainer(context, FSIntent.info)
            : isToday
            ? FSColors.intentContainer(context, FSIntent.primary)
            : FSColors.surface(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FSRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(FSSpacing.xs),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(FSRadius.md),
            border: Border.all(color: borderColor, width: isToday ? 1.8 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayNum',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isToday ? FSColors.primary : null,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              if (hasEvents) ...[
                const Spacer(),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _CalendarCountBadge(count: eventCount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarCountBadge extends StatelessWidget {
  const _CalendarCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FSColors.primary,
        borderRadius: BorderRadius.circular(FSRadius.pill),
        boxShadow: FSShadows.soft(context),
      ),
      child: Text(
        count.toString(),
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.intent,
    required this.exportLabel,
    required this.onExport,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final FSIntent intent;
  final String exportLabel;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final color = FSColors.intent(intent);
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.md),
      child: FSCard(
        variant: FSCardVariant.subtle,
        padding: const EdgeInsets.all(FSSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FSColors.intentContainer(context, intent),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                    border: Border.all(
                      color: FSColors.intentBorder(context, intent),
                    ),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: FSSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: FSSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FSColors.mutedText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FSSpacing.md),
            FSButton(
              label: exportLabel,
              icon: Icons.calendar_month_outlined,
              variant: FSButtonVariant.outline,
              size: FSButtonSize.sm,
              fullWidth: true,
              onPressed: onExport,
            ),
          ],
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
