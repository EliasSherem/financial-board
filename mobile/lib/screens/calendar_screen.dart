import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../models.dart';
import '../i18n.dart';
import '../utils/format.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _load();
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
    for (final r in _salaries.where((r)=> r.isActive)) {
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
        '${x.year.toString().padLeft(4,'0')}${x.month.toString().padLeft(2,'0')}${x.day.toString().padLeft(2,'0')}';
    final title = Uri.encodeComponent('${I18n.t(context, 'calendar.duePayment')}: ${p.name}');
    final details = Uri.encodeComponent('Amount: ' + money(p.amount) + (p.accountName != null ? '\nAccount: ${p.accountName}' : ''));
    final url = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=${fmt(start)}/${fmt(end)}';
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _exportSalaryToCalendar(SalaryRule r, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    String fmt(DateTime x) =>
        '${x.year.toString().padLeft(4,'0')}${x.month.toString().padLeft(2,'0')}${x.day.toString().padLeft(2,'0')}';
    final title = Uri.encodeComponent('Salary: ${r.name}');
    final details = Uri.encodeComponent('Amount: ' + money(r.amount));
    final url = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=${fmt(start)}/${fmt(end)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final byDay = _eventsForMonth(_month);
    final bySalary = _salaryEventsForMonth(_month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Mon..7=Sun
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellsBefore = (firstWeekday % 7); // Make weeks start on Sunday
    final totalCells = cellsBefore + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, 'title.calendar')),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Prev',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
                      ),
                      Text(DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(_month), style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        tooltip: 'Next',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
                      ),
                    ],
                  ),
                ),
                _weekHeader(context),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: rows * 7,
                    itemBuilder: (context, idx) {
                      final dayNum = idx - cellsBefore + 1;
                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(_month.year, _month.month, dayNum);
                      final now = DateTime.now();
                      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                      final key = date.toIso8601String().substring(0, 10);
                      final list = byDay[key] ?? const [];
                      final sals = bySalary[key] ?? const [];
                      final has = list.isNotEmpty || sals.isNotEmpty;
                      return InkWell(
                        onTap: has ? () => _openDay(date, list) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isToday ? cs.primary : cs.outlineVariant, width: isToday ? 2 : 1),
                            color: has
                                ? cs.primaryContainer.withOpacity(0.25)
                                : (isToday ? cs.primary.withOpacity(0.08) : null),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$dayNum',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: isToday ? FontWeight.w700 : null,
                                      color: isToday ? cs.primary : null,
                                    ),
                              ),
                              if (has) ...[
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: _dot(list.length + sals.length, cs.primary),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _dot(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  void _openDay(DateTime date, List<PaymentItem> payments) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sals = _salaryEventsForMonth(DateTime(date.year, date.month, 1))[date.toIso8601String().substring(0,10)] ?? const [];
        if (payments.isEmpty && sals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(I18n.t(context, 'calendar.noEvents')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length + sals.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            if (i < payments.length) {
              final p = payments[i];
              return ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(p.name),
                subtitle: Text('${p.frequency} • ' + money(p.amount)),
                trailing: FilledButton(
                  onPressed: () => _exportToCalendar(p, date),
                  child: Text(I18n.t(context, 'calendar.addToCalendar')),
                ),
              );
            } else {
              final r = sals[i - payments.length];
              return ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(r.name),
                subtitle: Text('Salary • ' + money(r.amount) + (r.accountName != null ? ' • ${r.accountName}' : '')),
                trailing: FilledButton(
                  onPressed: () => _exportSalaryToCalendar(r, date),
                  child: Text(I18n.t(context, 'calendar.addToCalendar')),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _weekHeader(BuildContext context) {
    const names = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final n in names)
            Expanded(child: Center(child: Text(n, style: style))),
        ],
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

  SalaryRule({required this.name, required this.amount, required this.schedule, this.weekday, this.day, this.isActive = true, this.accountId, this.accountName});

  factory SalaryRule.fromJson(Map<String, dynamic> j) => SalaryRule(
    name: j['name'] as String? ?? 'Salary',
    amount: (j['amount'] is num) ? (j['amount'] as num).toDouble() : double.tryParse('${j['amount']}') ?? 0.0,
    schedule: j['schedule'] as String? ?? 'SemiMonthly',
    weekday: (j['weekday'] as num?)?.toInt(),
    day: (j['day'] as num?)?.toInt(),
    isActive: (j['isActive'] == null) ? true : ((j['isActive'] == 1) || (j['isActive'] == true)),
    accountId: (j['accountId'] as num?)?.toInt() ?? (j['account_id'] as num?)?.toInt(),
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
