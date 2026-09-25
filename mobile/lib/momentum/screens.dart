import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../lang_store.dart';
import '../liquid_glass/liquid_glass.dart';
import '../screens/accounts_screen_new.dart';
import '../screens/transactions_v2_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/investments_screen.dart';
import '../screens/manage_categories_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/receipt_scan_screen.dart';
import '../services/analytics_service.dart';
import '../services/api.dart';
import '../services/client_context.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'xp_chart.dart';

Future<void> navigateMomentumMission(
  BuildContext context,
  MomentumMission mission,
) async {
  if (!mission.actionable) return;
  final uri = Uri.tryParse(mission.deeplink);
  final path = uri?.path ?? '';
  Widget? screen;
  if (mission.review) {
    final kind =
        const {
              'weekly_summary',
              'activation_weekly_review',
            }.contains(mission.key)
            ? 'weekly'
            : mission.key == 'monthly_review'
            ? 'monthly'
            : mission.key;
    screen = MomentumReviewScreen(kind: kind, missionKey: mission.key);
  } else {
    final feature = path.split('/').where((v) => v.isNotEmpty).firstOrNull;
    if (feature == 'momentum') {
      final next =
          context
              .read<MomentumStore>()
              .state
              ?.requiredWeek
              .where(
                (candidate) =>
                    candidate.actionable && candidate.key != mission.key,
              )
              .firstOrNull;
      if (next != null) await navigateMomentumMission(context, next);
      return;
    }
    screen = switch (feature) {
      'accounts' => const AccountsScreenNew(),
      'transactions' => const TransactionsScreen(),
      'payments' => const PaymentsScreen(),
      'projects' => const ProjectsScreen(),
      'invoices' => const InvoicesScreen(),
      'investments' => const InvestmentsScreen(),
      'categories' => const ManageCategoriesScreen(),
      'analytics' => const AnalyticsScreen(),
      'ai' || 'ai-chat' => const AiChatScreen(),
      'receipt' || 'receipts' => const ReceiptScanScreen(),
      _ => null,
    };
    if (feature != null) {
      AnalyticsService.instance.event('feature_used', feature: feature);
    }
  }
  if (screen == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/momentum/action'),
      builder: (_) => screen!,
    ),
  );
  if (context.mounted) {
    await context.read<MomentumStore>().refresh(force: false);
  }
}

class MomentumScreen extends StatefulWidget {
  const MomentumScreen({super.key});
  @override
  State<MomentumScreen> createState() => _MomentumScreenState();
}

class _MomentumScreenState extends State<MomentumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AnalyticsService.instance.screen('momentum');
      final store = context.read<MomentumStore>();
      unawaited(store.refresh(force: false));
      if (store.state?.week['new_week'] == true) {
        unawaited(store.event('week_presented'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    final store = context.watch<MomentumStore>();
    final state = store.state;
    String l(String en, String es) => momentumText(context, en, es);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Momentum'),
        actions: [
          IconButton(
            tooltip: l('Preferences', 'Preferencias'),
            icon: const Icon(Icons.tune_rounded),
            onPressed:
                state?.enabled == true ? () => _preferences(context) : null,
          ),
        ],
      ),
      body:
          state == null
              ? Center(
                child:
                    store.loading
                        ? const CircularProgressIndicator()
                        : TextButton(
                          style: momentumTextButtonStyle(context),
                          onPressed: () => store.refresh(),
                          child: Text(l('Retry', 'Reintentar')),
                        ),
              )
              : !state.enabled
              ? Center(
                child: Text(
                  l(
                    'Momentum is not enabled yet.',
                    'Momentum aún no está habilitado.',
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: () => store.refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _ProfileHero(state: state),
                    if (store.loading || store.offline)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          store.loading
                              ? l(
                                'Updating progress…',
                                'Actualizando progreso…',
                              )
                              : l(
                                'Offline · saved progress',
                                'Sin conexión · progreso guardado',
                              ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l('Your showcase', 'Tu vitrina'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          style: momentumTextButtonStyle(context),
                          key: const Key('momentum-open-collection'),
                          onPressed:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: '/achievements',
                                  ),
                                  builder: (_) => const AchievementsScreen(),
                                ),
                              ),
                          child: Text(l('View collection', 'Ver colección')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (state.achievements.isEmpty)
                      LGSolidCard(
                        child: Text(
                          l(
                            'Your badges will appear here.',
                            'Tus insignias aparecerán aquí.',
                          ),
                        ),
                      )
                    else
                      _AchievementGrid(
                        achievements: momentumFeaturedAchievements(state),
                      ),
                    const SizedBox(height: 24),
                    _ActivitySummary(state: state),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: momentumTextButtonStyle(context),
                        key: const Key('momentum-open-progress'),
                        icon: const Icon(Icons.insights_outlined, size: 18),
                        label: Text(l('History & XP', 'Historial y XP')),
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const _MomentumProgressScreen(),
                              ),
                            ),
                      ),
                    ),
                    if (state.backfill['unseen'] == true ||
                        !state.coachmarkSeen) ...[
                      const SizedBox(height: 16),
                      LGSolidCard(
                        tinted: true,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.backfill['unseen'] == true
                                  ? l(
                                    'Your verified progress is already part of your profile.',
                                    'Tu progreso verificado ya forma parte de tu perfil.',
                                  )
                                  : l(
                                    'Useful steps become lasting achievements. Take it at your pace.',
                                    'Los pasos útiles se convierten en logros. Avanza a tu ritmo.',
                                  ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            TextButton(
                              style: momentumTextButtonStyle(context),
                              key: const Key('momentum-notice-ack'),
                              onPressed:
                                  () => store.event(
                                    state.backfill['unseen'] == true
                                        ? 'backfill_seen'
                                        : 'coachmark_seen',
                                  ),
                              child: Text(l('Got it', 'Entendido')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.state});
  final MomentumState state;
  @override
  Widget build(BuildContext context) {
    String l(String en, String es) => momentumText(context, en, es);
    final next = state.level['next_xp'];
    final earned = state.achievements.where((a) => a.completed).length;
    return LGSolidCard(
      tinted: true,
      showBorder: false,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B8CF8).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
              child: MomentumAsset(
                assetKey: state.level['key'] as String? ?? 'explorer',
                size: 112,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l('YOUR LEVEL', 'TU NIVEL'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.8,
              color: LGColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localized(state.level['title'], momentumLanguage(context)),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            '${state.xp} XP',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.levelProgress,
              minHeight: 4,
              color: const Color(0xFF7775DD),
              backgroundColor: LGColors.textSecondary(
                context,
              ).withValues(alpha: 0.12),
              semanticsLabel:
                  '${l('Level progress', 'Progreso de nivel')}: ${state.xp} XP',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? l('Highest level reached', 'Has alcanzado el nivel más alto')
                : l(
                  '${(count(next) - state.xp).clamp(0, count(next))} XP to the next level',
                  '${(count(next) - state.xp).clamp(0, count(next))} XP para el siguiente nivel',
                ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: LGColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                '$earned/${state.achievements.length} ${l('badges', 'insignias')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${state.rhythm} ${l('weeks of rhythm', 'semanas de ritmo')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.state});
  final MomentumState state;
  @override
  Widget build(BuildContext context) {
    String l(String en, String es) => momentumText(context, en, es);
    final weekly = state.week['assigned'] == true;
    final activation =
        state.missions.where((m) => m.scope == 'activation').toList();
    final completed =
        weekly
            ? count(state.week['completed'])
            : activation.where((m) => m.completed).length;
    final total = weekly ? count(state.week['total']) : activation.length;
    return LGSolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MomentumAsset(assetKey: 'weekly_review', size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  weekly
                      ? l('This week', 'Esta semana')
                      : l('Getting started', 'Primeros pasos'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completed/$total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: total > 0 ? (completed / total).clamp(0, 1).toDouble() : 0,
            minHeight: 3,
            semanticsLabel:
                '${l('Activities completed', 'Actividades completadas')}: $completed/$total',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: momentumTextButtonStyle(context),
              key: const Key('momentum-open-activities'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MomentumActivitiesScreen(),
                    ),
                  ),
              child: Text(l('View activities', 'Ver actividades')),
            ),
          ),
        ],
      ),
    );
  }
}

class MomentumActivitiesScreen extends StatelessWidget {
  const MomentumActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    final store = context.watch<MomentumStore>();
    final state = store.state;
    String l(String en, String es) => momentumText(context, en, es);
    final weekly = state?.week['assigned'] == true;
    final missions =
        state == null
            ? <MomentumMission>[]
            : weekly
            ? state.requiredWeek
            : state.activation;
    final groups = <String, List<MomentumMission>>{};
    if (state != null) {
      for (final entry
          in {
            'weekly': l('Something to explore', 'Algo por explorar'),
            'comeback': l('Welcome back', 'Retoma tu ritmo'),
            'feature': l('Useful discoveries', 'Descubrimientos útiles'),
            'monthly': l('This month', 'Este mes'),
          }.entries) {
        final group =
            state.missions
                .where(
                  (m) =>
                      m.scope == entry.key &&
                      m.status != 'replaced' &&
                      (entry.key != 'weekly' || m.slot == null) &&
                      (m.actionable || m.scope == 'monthly' && m.completed),
                )
                .toList();
        if (group.isNotEmpty &&
            (weekly || entry.key == 'comeback' || entry.key == 'monthly')) {
          groups[entry.value] = group;
        }
      }
    }
    final pendingMissions = missions.where((m) => !m.completed).toList();
    final completed = [
      ...missions.where((m) => m.completed),
      ...groups.values.expand((items) => items).where((m) => m.completed),
    ];
    final pendingGroups = groups.entries
        .map(
          (group) => MapEntry(
            group.key,
            group.value.where((m) => !m.completed).toList(),
          ),
        )
        .where((group) => group.value.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(l('Activities', 'Actividades'))),
      body: RefreshIndicator(
        onRefresh: () => store.refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children:
              state?.enabled != true
                  ? [
                    Text(
                      l(
                        'Activities are not available yet.',
                        'Las actividades aún no están disponibles.',
                      ),
                    ),
                  ]
                  : [
                    Text(
                      weekly
                          ? l('This week', 'Esta semana')
                          : l('Getting started', 'Primeros pasos'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (state!.week['unavailable'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l(
                            'An activity is unavailable. Your rhythm is protected.',
                            'Una actividad no está disponible. Tu ritmo está protegido.',
                          ),
                        ),
                      ),
                    if (state.week['grace_applied'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l(
                            'A grace week preserved your rhythm without adding XP.',
                            'Una semana de gracia conservó tu ritmo sin sumar XP.',
                          ),
                        ),
                      ),
                    for (final mission in pendingMissions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MissionCard(mission: mission),
                      ),
                    if (pendingMissions.isEmpty)
                      Text(
                        completed.isNotEmpty
                            ? l('All done for now.', 'Todo listo por ahora.')
                            : l(
                              'Your next steps will appear here.',
                              'Tus próximos pasos aparecerán aquí.',
                            ),
                      ),
                    for (final group in pendingGroups) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          group.key,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final mission in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MissionCard(mission: mission),
                        ),
                    ],
                    if (completed.isNotEmpty)
                      ExpansionTile(
                        key: const PageStorageKey(
                          'momentum-completed-activities',
                        ),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '${l('Completed', 'Completadas')} (${completed.length})',
                        ),
                        children: [
                          for (final mission in completed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MissionCard(mission: mission),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
        ),
      ),
    );
  }
}

class _MomentumProgressScreen extends StatelessWidget {
  const _MomentumProgressScreen();
  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    final state = context.watch<MomentumStore>().state;
    String l(String en, String es) => momentumText(context, en, es);
    return Scaffold(
      appBar: AppBar(title: Text(l('History & XP', 'Historial y XP'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state?.enabled == true) ...[
            MomentumXpChart(
              history:
                  (state!.json['xp_history'] as List? ?? [])
                      .map(object)
                      .toList(),
            ),
            LGSolidCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l('How XP adds up', 'Cómo se suman los XP'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l('Weekly activities', 'Actividades semanales')}: ${count(state.week['repeatable_xp'])}/${count(state.week['cap'])} XP',
                  ),
                  Text(
                    '${l('Monthly activities', 'Actividades mensuales')}: ${count(state.month['repeatable_xp'])}/${count(state.month['cap'])} XP',
                  ),
                  Text(
                    '${l('Weekly bonus awarded', 'Bono semanal concedido')}: ${count(state.week['bonus_xp'])} XP',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l(
                      'Repeatable activities have a limit. Achievements are counted separately.',
                      'Las actividades repetibles tienen un límite. Los logros se suman aparte.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (state.credits['available'] == true) ...[
              const SizedBox(height: 16),
              LGSolidCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MomentumAsset(assetKey: 'ai_credit', size: 40),
                    const SizedBox(height: 8),
                    Text(
                      '${state.creditBalance} ${l('AI questions available', 'preguntas IA disponibles')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_momentumDate(context, state.credits['expires_at'])
                        case final String date)
                      Text('${l('Expires', 'Vence')}: $date'),
                    TextButton(
                      style: momentumTextButtonStyle(context),
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AiChatScreen(),
                            ),
                          ),
                      child: Text(l('Open assistant', 'Abrir asistente')),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});
  final MomentumMission mission;
  @override
  Widget build(BuildContext context) {
    final language = momentumLanguage(context);
    String l(String en, String es) => momentumText(context, en, es);
    return LGSolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MomentumAsset(
                assetKey:
                    mission.scope == 'comeback'
                        ? 'comeback'
                        : mission.slot == 'review'
                        ? 'mission_review'
                        : mission.slot == 'goal'
                        ? 'mission_goal'
                        : 'mission_maintenance',
              ),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Text(
                  mission.title(language),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (mission.completed) const Icon(Icons.check_circle_outline),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          Text(
            '${mission.progress}/${mission.target}'
            '${mission.completed
                ? ' · ${l('Completed', 'Completada')}'
                : !mission.actionable
                ? ' · ${l('Not available', 'No disponible')}'
                : ''}',
          ),
          const SizedBox(height: LGSpacing.sm),
          LinearProgressIndicator(
            value:
                mission.target <= 0
                    ? 0
                    : (mission.progress / mission.target)
                        .clamp(0, 1)
                        .toDouble(),
            semanticsLabel:
                '${mission.title(language)}: ${mission.progress}/${mission.target}',
          ),
          ExpansionTile(
            key: PageStorageKey('momentum-mission-details-${mission.key}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: LGSpacing.sm),
            minTileHeight: 44,
            title: Text(
              l('Details', 'Detalles'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: momentumLinkColor(context),
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.requirement(language)),
                    if (mission.reason(language).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: LGSpacing.sm),
                        child: Text(mission.reason(language)),
                      ),
                    const SizedBox(height: LGSpacing.sm),
                    Text(
                      mission.completed
                          ? '${mission.grantedXp} XP ${l('earned', 'obtenidos')}'
                          : '${l('Up to', 'Hasta')} ${mission.nominalXp} XP',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mission.actionable)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: momentumLinkColor(context),
                  minimumSize: const Size(0, 44),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => navigateMomentumMission(context, mission),
                child: Text(
                  l('Continue', 'Continuar'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _filter = 'all';
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('achievements');
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    final store = context.watch<MomentumStore>();
    final state = store.state;
    String l(String en, String es) => momentumText(context, en, es);
    final all =
        state?.enabled == true
            ? momentumOrderedAchievements(state!)
            : <MomentumAchievement>[];
    final achievements =
        all
            .where(
              (a) => switch (_filter) {
                'earned' => a.completed,
                'locked' => !a.completed,
                'available' => a.available,
                _ => true,
              },
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l('My collection', 'Mi colección'))),
      body: RefreshIndicator(
        onRefresh: () => store.refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              '${all.where((a) => a.completed).length}/${all.length} ${l('badges earned', 'insignias obtenidas')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry
                    in {
                      'all': l('All', 'Todas'),
                      'earned': l('Earned', 'Obtenidas'),
                      'locked': l('Locked', 'Pendientes'),
                      'available': l('Available', 'Disponibles'),
                    }.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (state == null && store.loading) const LGLoadingState(),
            if (achievements.isEmpty && !store.loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l(
                    'No badges in this view yet.',
                    'Aún no hay insignias en esta vista.',
                  ),
                ),
              ),
            _AchievementGrid(achievements: achievements),
          ],
        ),
      ),
    );
  }
}

String _achievementStatus(
  BuildContext context,
  MomentumAchievement achievement,
) =>
    achievement.completed
        ? momentumText(context, 'Earned', 'Obtenida')
        : !achievement.available
        ? momentumText(context, 'Not available', 'No disponible')
        : achievement.progress > 0
        ? momentumText(context, 'In progress', 'En progreso')
        : momentumText(context, 'To discover', 'Por descubrir');

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.achievements});
  final List<MomentumAchievement> achievements;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = (constraints.maxWidth / (largeText ? 188 : 144))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final achievement in achievements)
            SizedBox(
              width: width,
              child: _AchievementTile(achievement: achievement),
            ),
        ],
      );
    },
  );
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});
  final MomentumAchievement achievement;
  @override
  Widget build(BuildContext context) {
    final title = achievement.title(momentumLanguage(context));
    final status = _achievementStatus(context, achievement);
    final fresh = achievement.completed && !achievement.seen;
    void open() => showAchievement(context, achievement);
    return Semantics(
      key: ValueKey('momentum-badge-${achievement.key}'),
      button: true,
      label:
          '$title. $status${fresh ? '. ${momentumText(context, 'New', 'Nueva')}' : ''}',
      onTap: open,
      excludeSemantics: true,
      child: LGSolidCard(
        onTap: open,
        tinted: achievement.completed,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            MomentumAsset(
              assetKey: achievement.key,
              locked: !achievement.completed,
              size: 80,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: LGColors.textSecondary(context),
              ),
            ),
            if (fresh)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  momentumText(context, 'New', 'Nueva'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: momentumLinkColor(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _momentumDate(BuildContext context, dynamic value) {
  final date = value is DateTime ? value : DateTime.tryParse('$value');
  return date == null
      ? null
      : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
}

Future<void> showAchievement(
  BuildContext context,
  MomentumAchievement achievement,
) async {
  final store = context.read<MomentumStore>();
  if (store.presentationOpen) return;
  store.presentationOpen = true;
  store.presented.add(achievement.key);
  final language = momentumLanguage(context);
  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final reduced = MediaQuery.of(ctx).disableAnimations;
        return LGDialogShell(
          title: achievement.title(language),
          footer: LGButton(
            label: momentumText(context, 'Done', 'Listo'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: reduced ? 0 : 420),
                tween: Tween(begin: reduced ? 1 : 0.88, end: 1),
                builder:
                    (_, value, child) => Transform.scale(
                      scale: value,
                      child: Opacity(opacity: value, child: child),
                    ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow:
                        achievement.completed
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF7C83FD,
                                ).withValues(alpha: 0.14),
                                blurRadius: 20,
                                spreadRadius: 6,
                              ),
                            ]
                            : null,
                  ),
                  child: MomentumAsset(
                    assetKey: achievement.key,
                    locked: !achievement.completed,
                    size: 112,
                  ),
                ),
              ),
              const SizedBox(height: LGSpacing.lg),
              Text(
                _achievementStatus(context, achievement),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: LGSpacing.md),
              Text(
                achievement.requirement(language),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LGSpacing.md),
              Text(
                '${achievement.progress}/${achievement.target} · ${achievement.xp} XP',
              ),
              const SizedBox(height: LGSpacing.sm),
              LinearProgressIndicator(
                value:
                    achievement.target > 0
                        ? (achievement.progress / achievement.target)
                            .clamp(0, 1)
                            .toDouble()
                        : 0,
                minHeight: 4,
                semanticsLabel:
                    '${achievement.title(language)}: ${achievement.progress}/${achievement.target}',
              ),
              if (_momentumDate(context, achievement.json['completed_at'])
                  case final String date)
                Padding(
                  padding: const EdgeInsets.only(top: LGSpacing.md),
                  child: Text(
                    '${momentumText(context, 'Earned on', 'Obtenida el')} $date',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!achievement.available &&
                  achievement.reason(language).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: LGSpacing.md),
                  child: Text(
                    achievement.reason(language),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (achievement.completed && !achievement.seen) {
      try {
        await store.markSeen(achievement.key);
      } catch (_) {
        /* Shown again only after a future explicit visit. */
      }
    }
  } finally {
    store.presentationOpen = false;
  }
}

class MomentumReviewScreen extends StatefulWidget {
  const MomentumReviewScreen({super.key, required this.kind, this.missionKey});
  final String kind;
  final String? missionKey;
  @override
  State<MomentumReviewScreen> createState() => _MomentumReviewScreenState();
}

class _MomentumReviewScreenState extends State<MomentumReviewScreen> {
  Json? _snapshot;
  final Set<String> _confirmed = {};
  String? _nextStep;
  String? _error;
  bool _loading = true, _submitting = false;
  String _eventId = clientEventId();
  DateTime _occurred = DateTime.now().toUtc();
  Timer? _expiryTimer;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<MomentumStore>().service;
    if (service == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _confirmed.clear();
    });
    try {
      final snapshot = await service.review(widget.kind);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _eventId = clientEventId();
        _occurred = DateTime.now().toUtc();
      });
      _expiryTimer?.cancel();
      _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'load');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _expired {
    final at = DateTime.tryParse(_snapshot?['expires_at'] as String? ?? '');
    return at == null || !DateTime.now().toUtc().isBefore(at);
  }

  List<Json> get _sections =>
      (_snapshot?['sections'] as List? ?? []).map(object).toList();
  Future<void> _confirm() async {
    if (_expired || _submitting) return;
    final store = context.read<MomentumStore>();
    final service = store.service;
    if (service == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = {
        'snapshot_id': _snapshot!['snapshot_id'],
        'confirmed_sections': _confirmed.toList(),
      };
      if (widget.kind == 'weekly' || widget.kind == 'monthly') {
        await store.acceptReview(
          service.confirm(widget.kind, {...payload, 'next_step': _nextStep}),
        );
      } else {
        await store.acceptReview(
          service.event({
            ...payload,
            'event_id': _eventId,
            'type': 'review_confirmed',
            'mission_key': widget.missionKey ?? widget.kind,
            'occurred_at': _occurred.toIso8601String(),
          }),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            momentumText(context, 'Review complete', 'Revisión completada'),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e.statusCode == 409 || e.statusCode == 400
                      ? 'stale'
                      : 'network',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'network');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    String l(String en, String es) => momentumText(context, en, es);
    final applicable =
        _sections
            .where((s) => s['applicable'] == true)
            .map((s) => s['key'].toString())
            .toSet();
    final ready =
        _snapshot != null &&
        !_expired &&
        _error != 'stale' &&
        (!(widget.kind == 'weekly' || widget.kind == 'monthly') ||
            _nextStep != null) &&
        applicable.difference(_confirmed).isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.kind == 'monthly'
              ? l('Monthly review', 'Revisión mensual')
              : l('Review your finances', 'Revisa tus finanzas'),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(LGSpacing.lg),
                children: [
                  Text(
                    l(
                      'Review and confirm each section.',
                      'Revisa y confirma cada sección.',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('momentum-review-help'),
                      style: momentumTextButtonStyle(context),
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: Text(
                                    l('How it works', 'Cómo funciona'),
                                  ),
                                  scrollable: true,
                                  content: Text(
                                    l(
                                      'Read the current data and confirm every applicable section. For a weekly or monthly review, choose your next step. Only the final confirmation records the review; opening this page gives no XP. If the data changes or the review expires, reload before confirming.',
                                      'Lee los datos actuales y confirma cada sección aplicable. En la revisión semanal o mensual, elige tu siguiente paso. Sólo la confirmación final registra la revisión; abrir esta pantalla no da XP. Si los datos cambian o la revisión caduca, actualízala antes de confirmar.',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      style: momentumTextButtonStyle(ctx),
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: Text(l('Done', 'Listo')),
                                    ),
                                  ],
                                ),
                          ),
                      child: Text(l('How it works', 'Cómo funciona')),
                    ),
                  ),
                  for (final section in _sections)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: LGSpacing.sm,
                      ),
                      child: LGSolidCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              localized(
                                section['title'],
                                momentumLanguage(context),
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (section['applicable'] != true)
                              Text(
                                l(
                                  'Not applicable: no eligible data.',
                                  'No aplicable: no hay datos elegibles.',
                                ),
                              )
                            else ...[
                              for (final record in (section['data'] as List? ??
                                      [])
                                  .map(object))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: LGSpacing.sm,
                                  ),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children:
                                        record.entries
                                            .where(
                                              (e) =>
                                                  e.key != 'id' &&
                                                  !e.key.endsWith('_id'),
                                            )
                                            .map(
                                              (e) => Text(
                                                '${reviewFieldLabel(e.key, momentumLanguage(context))}: ${reviewFieldValue(e.key, e.value, momentumLanguage(context))}',
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  l(
                                    'I reviewed this section',
                                    'He revisado esta sección',
                                  ),
                                ),
                                value: _confirmed.contains(section['key']),
                                onChanged:
                                    _submitting
                                        ? null
                                        : (value) => setState(() {
                                          if (value == true) {
                                            _confirmed.add(
                                              section['key'] as String,
                                            );
                                          } else {
                                            _confirmed.remove(section['key']);
                                          }
                                          _eventId = clientEventId();
                                          _occurred = DateTime.now().toUtc();
                                        }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (_snapshot != null &&
                      (widget.kind == 'weekly' ||
                          widget.kind == 'monthly')) ...[
                    const SizedBox(height: LGSpacing.md),
                    Text(
                      l('Next step', 'Siguiente paso'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _nextStep,
                      hint: Text(
                        l('Choose a next step', 'Elige un siguiente paso'),
                      ),
                      isExpanded: true,
                      items:
                          {
                                'review_spending': l(
                                  'Review spending',
                                  'Revisar gastos',
                                ),
                                'organize_categories': l(
                                  'Organize categories',
                                  'Organizar categorías',
                                ),
                                'check_obligations': l(
                                  'Check obligations',
                                  'Consultar obligaciones',
                                ),
                                'review_goal': l(
                                  'Review a goal',
                                  'Revisar un objetivo',
                                ),
                                'keep_plan': l(
                                  'Keep my current plan',
                                  'Mantener mi plan',
                                ),
                              }.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _submitting
                              ? null
                              : (value) => setState(() => _nextStep = value),
                    ),
                  ],
                  if (_error != null || _snapshot != null && _expired) ...[
                    const SizedBox(height: LGSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error == 'network'
                            ? l(
                              'Not confirmed. Reconnect and retry before this snapshot expires.',
                              'No se ha confirmado. Reconecta y reintenta antes de que caduque la revisión.',
                            )
                            : l(
                              'Reload current data before confirming. This snapshot may have expired or changed.',
                              'Actualiza los datos antes de confirmar. La revisión puede haber caducado o cambiado.',
                            ),
                        style: const TextStyle(color: LGColors.danger),
                      ),
                    ),
                    TextButton(
                      style: momentumTextButtonStyle(context),
                      onPressed: _submitting ? null : _load,
                      child: Text(l('Reload data', 'Actualizar datos')),
                    ),
                  ],
                  const SizedBox(height: LGSpacing.lg),
                  LGButton(
                    label: l('Confirm review', 'Confirmar revisión'),
                    fullWidth: true,
                    loading: _submitting,
                    onPressed: ready && !_submitting ? _confirm : null,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
    );
  }
}

String reviewFieldLabel(String key, String language) {
  const labels = <String, List<String>>{
    'name': ['Name', 'Nombre'],
    'type': ['Type', 'Tipo'],
    'balance': ['Balance', 'Saldo'],
    'date': ['Date', 'Fecha'],
    'start_date': ['Start date', 'Fecha de inicio'],
    'end_date': ['End date', 'Fecha de fin'],
    'description': ['Description', 'Descripción'],
    'amount': ['Amount', 'Importe'],
    'category': ['Category', 'Categoría'],
    'status': ['Status', 'Estado'],
    'next_date': ['Next date', 'Próxima fecha'],
    'due_date': ['Due date', 'Vencimiento'],
    'total': ['Total', 'Total'],
    'income': ['Income', 'Ingresos'],
    'expense': ['Expenses', 'Gastos'],
    'expenses': ['Expenses', 'Gastos'],
    'net': ['Net', 'Neto'],
    'budget': ['Budget', 'Presupuesto'],
    'spent': ['Spent', 'Gasto'],
    'count': ['Records', 'Registros'],
    'records': ['Records', 'Registros'],
    'account': ['Account', 'Cuenta'],
    'currency': ['Currency', 'Moneda'],
    'principal': ['Principal', 'Capital'],
    'annual_rate': ['Annual rate', 'Tasa anual'],
    'frequency': ['Frequency', 'Frecuencia'],
    'amount_due': ['Due', 'Pendiente'],
    'number': ['Number', 'Número'],
    'is_active': ['Active', 'Activo'],
    'category_name': ['Category', 'Categoría'],
    'subcategory_name': ['Subcategory', 'Subcategoría'],
    'total_balance': ['Total balance', 'Saldo total'],
  };
  return labels[key]?[language == 'es' ? 1 : 0] ?? key.replaceAll('_', ' ');
}

String reviewFieldValue(String key, dynamic value, String language) {
  if (value == null) return '—';
  if (value is bool) {
    return language == 'es' ? (value ? 'Sí' : 'No') : (value ? 'Yes' : 'No');
  }
  final text = value.toString();
  if (const {
        'date',
        'start_date',
        'end_date',
        'due_date',
        'next_date',
      }.contains(key) &&
      RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
    return text.substring(0, 10);
  }
  if (language == 'es' && const {'type', 'status', 'frequency'}.contains(key)) {
    const translated = {
      'Income': 'Ingreso',
      'Expense': 'Gasto',
      'Transfer': 'Transferencia',
      'Active': 'Activo',
      'Completed': 'Completado',
      'Daily': 'Diario',
      'Weekly': 'Semanal',
      'Monthly': 'Mensual',
      'Yearly': 'Anual',
      'Biweekly': 'Quincenal',
      'Quarterly': 'Trimestral',
      'draft': 'Borrador',
      'sent': 'Enviada',
      'paid': 'Pagada',
      'partial': 'Parcial',
      'void': 'Anulada',
      'overdue': 'Vencida',
      'Checking': 'Cuenta corriente',
      'Savings': 'Ahorro',
      'Credit': 'Crédito',
      'Cash': 'Efectivo',
    };
    return translated[text] ?? text;
  }
  return text;
}

Future<void> _preferences(BuildContext context) async {
  final store = context.read<MomentumStore>();
  final state = store.state;
  if (state == null) return;
  bool enabled = state.preferences['notifications_enabled'] == true;
  int start = count(state.preferences['quiet_start']),
      end = count(state.preferences['quiet_end']);
  String zone =
      state.preferences['timezone_name'] as String? ??
      state.week['timezone'] as String? ??
      ClientContext.timezone ??
      'UTC';
  final zones =
      {
        zone,
        'UTC',
        'America/Mexico_City',
        'America/New_York',
        'America/Los_Angeles',
        'Europe/Madrid',
        'Asia/Jerusalem',
      }.toList();
  bool busy = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) {
            String l(String en, String es) => momentumText(context, en, es);
            return LGBottomSheetShell(
              title: l('Momentum preferences', 'Preferencias de Momentum'),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      l('Mission notifications', 'Notificaciones de misiones'),
                    ),
                    value: enabled,
                    onChanged: busy ? null : (v) => setLocal(() => enabled = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: zone,
                    isExpanded: true,
                    decoration: LGForm.solidInputDecoration(
                      ctx,
                      labelText: l('Time zone', 'Zona horaria'),
                    ),
                    items:
                        zones
                            .map(
                              (z) => DropdownMenuItem(value: z, child: Text(z)),
                            )
                            .toList(),
                    onChanged:
                        busy ? null : (v) => setLocal(() => zone = v ?? zone),
                  ),
                  Text(
                    l(
                      'An assigned period keeps its original time boundaries.',
                      'Un período asignado conserva sus límites horarios originales.',
                    ),
                  ),
                  for (final isStart in [true, false])
                    DropdownButtonFormField<int>(
                      initialValue: (isStart ? start : end).clamp(0, 23),
                      decoration: LGForm.solidInputDecoration(
                        ctx,
                        labelText:
                            isStart
                                ? l('Quiet hours start', 'Inicio de silencio')
                                : l('Quiet hours end', 'Fin de silencio'),
                      ),
                      items: List.generate(
                        24,
                        (hour) => DropdownMenuItem(
                          value: hour,
                          child: Text('${hour.toString().padLeft(2, '0')}:00'),
                        ),
                      ),
                      onChanged:
                          busy
                              ? null
                              : (v) => setLocal(() {
                                if (isStart) {
                                  start = v ?? start;
                                } else {
                                  end = v ?? end;
                                }
                              }),
                    ),
                  const SizedBox(height: LGSpacing.lg),
                  LGButton(
                    label: l('Save', 'Guardar'),
                    loading: busy,
                    fullWidth: true,
                    onPressed:
                        busy
                            ? null
                            : () async {
                              setLocal(() => busy = true);
                              try {
                                await store.acceptReview(
                                  store.service!.preferences({
                                    'notifications_enabled': enabled,
                                    'quiet_start': start,
                                    'quiet_end': end,
                                    'locale': momentumLanguage(context),
                                    'timezone_name': zone,
                                    'timezone_offset_min':
                                        DateTime.now().timeZoneOffset.inMinutes,
                                  }),
                                );
                                ClientContext.timezone = zone;
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              } catch (_) {
                                if (ctx.mounted) {
                                  setLocal(() => busy = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l(
                                          'Unable to save. Try again.',
                                          'No se pudo guardar. Reintenta.',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                  ),
                ],
              ),
            );
          },
        ),
  );
}
