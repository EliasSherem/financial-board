import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../liquid_glass/liquid_glass.dart';
import 'models.dart';
import 'widgets.dart';

/// Daily XP granted by the immutable server ledger, never synthesized from usage.
class MomentumXpChart extends StatelessWidget {
  const MomentumXpChart({super.key, required this.history});
  final List<Json> history;
  @override
  Widget build(BuildContext context) {
    String l(String en, String es) => momentumText(context, en, es);
    final points =
        history.where((p) => p['period'] is String && p['xp'] is num).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LGSpacing.md),
      child: LGSolidCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l('XP awarded · last 30 days', 'XP concedidos · últimos 30 días'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LGSpacing.md),
            if (points.isEmpty)
              Text(
                l(
                  'No XP awarded in this period.',
                  'No se concedieron XP en este período.',
                ),
              )
            else ...[
              Semantics(
                label: l(
                  'Daily XP chart. Exact values are listed below.',
                  'Gráfica de XP diarios. Los valores exactos se muestran debajo.',
                ),
                child: SizedBox(
                  height: 120,
                  child: ExcludeSemantics(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        barTouchData: BarTouchData(enabled: false),
                        barGroups: List.generate(
                          points.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: count(points[i]['xp']).toDouble(),
                                width: points.length > 15 ? 5 : 12,
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      duration: Duration.zero,
                    ),
                  ),
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l('Exact values', 'Valores exactos')),
                children: [
                  for (final point in points)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(point['period'] as String)),
                          Text('${count(point['xp'])} XP'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
