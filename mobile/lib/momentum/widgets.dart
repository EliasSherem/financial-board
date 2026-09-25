import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../lang_store.dart';
import '../liquid_glass/liquid_glass.dart';
import '../services/analytics_service.dart';
import 'models.dart';
import 'screens.dart';
import 'store.dart';

String momentumLanguage(BuildContext context) => context.read<LangStore>().lang;
String momentumText(BuildContext context, String en, String es) =>
    momentumLanguage(context) == 'es' ? es : en;

Color momentumLinkColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF93C5FD)
        : LGColors.primaryBlue;

ButtonStyle momentumTextButtonStyle(BuildContext context) =>
    TextButton.styleFrom(foregroundColor: momentumLinkColor(context));

List<MomentumAchievement> momentumOrderedAchievements(MomentumState state) {
  final items = List<MomentumAchievement>.of(state.achievements);
  items.sort((a, b) {
    if (a.completed != b.completed) return a.completed ? -1 : 1;
    if (a.completed) {
      return '${b.json['completed_at']}'.compareTo('${a.json['completed_at']}');
    }
    if (a.available != b.available) return a.available ? -1 : 1;
    final aProgress = a.target > 0 ? a.progress / a.target : 0.0;
    final bProgress = b.target > 0 ? b.progress / b.target : 0.0;
    return bProgress.compareTo(aProgress);
  });
  return items;
}

List<MomentumAchievement> momentumFeaturedAchievements(MomentumState state) =>
    momentumOrderedAchievements(state).take(4).toList();

class MomentumAsset extends StatelessWidget {
  const MomentumAsset({
    super.key,
    required this.assetKey,
    this.size = 40,
    this.locked = false,
    this.label,
  });
  final String assetKey;
  final double size;
  final bool locked;
  final String? label;
  static Future<Map<String, Json>>? _manifest;
  static Future<Map<String, Json>> loadManifest() => _manifest ??= _load();
  static Future<Map<String, Json>> _load() async {
    final manifest = object(
      jsonDecode(
        await rootBundle.loadString('assets/momentum/assets/manifest.json'),
      ),
    );
    final result = <String, Json>{};
    for (final value in manifest.values.whereType<List>()) {
      for (final row in value) {
        final item = object(row);
        result[item['key'] as String] = object(item['files']);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: FutureBuilder<Map<String, Json>>(
      future: loadManifest(),
      builder: (context, snapshot) {
        final files = snapshot.data?[assetKey];
        if (files == null) return const SizedBox.shrink();
        final dark = Theme.of(context).brightness == Brightness.dark;
        final variant = '${locked ? 'locked_' : ''}${dark ? 'dark' : 'light'}';
        final path = files[variant] ?? files[dark ? 'dark' : 'light'];
        if (path is! String) return const SizedBox.shrink();
        return SvgPicture.asset(
          'assets/momentum/$path',
          width: size,
          height: size,
          semanticsLabel: label,
          excludeFromSemantics: label == null,
        );
      },
    ),
  );
}

class MomentumHomeCard extends StatelessWidget {
  const MomentumHomeCard({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    final store = context.watch<MomentumStore>();
    final state = store.state;
    if (state == null || !state.enabled) {
      if (!store.loading && store.error == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: LGSpacing.md),
        child: LGSolidCard(
          child:
              store.loading
                  ? const MomentumSkeleton()
                  : TextButton(
                    style: momentumTextButtonStyle(context),
                    onPressed: () => store.refresh(),
                    child: Text(
                      momentumText(
                        context,
                        'Momentum is unavailable. Retry',
                        'Momentum no está disponible. Reintentar',
                      ),
                    ),
                  ),
        ),
      );
    }
    final language = momentumLanguage(context);
    final featured = momentumFeaturedAchievements(state).take(3);
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.md),
      child: LGGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MomentumAsset(
                  assetKey: state.level['key'] as String? ?? 'explorer',
                  size: 48,
                ),
                const SizedBox(width: LGSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Momentum',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        localized(state.level['title'], language),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (state.week['new_week'] == true)
                  Semantics(
                    label: momentumText(context, 'New week', 'Nueva semana'),
                    child: const Badge(
                      backgroundColor: Color(0xFF2563EB),
                      textColor: Colors.white,
                      label: Text('•'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LGSpacing.md),
            Wrap(
              spacing: LGSpacing.md,
              runSpacing: LGSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${state.xp} XP'),
                if (featured.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final achievement in featured)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: MomentumAsset(
                            assetKey: achievement.key,
                            locked: !achievement.completed,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: LGSpacing.sm),
            Semantics(
              label:
                  '${localized(state.level['title'], language)} ${state.xp} XP',
              child: LinearProgressIndicator(
                value: state.levelProgress,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: LGSpacing.sm),
            if (store.offline)
              Text(
                momentumText(
                  context,
                  'Offline · cached progress',
                  'Sin conexión · progreso guardado',
                ),
              ),
            const SizedBox(height: LGSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: momentumTextButtonStyle(context),
                label: Text(
                  momentumText(context, 'View my profile', 'Ver mi perfil'),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                onPressed: () => openMomentum(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openMomentum(BuildContext context) async {
  final store = context.read<MomentumStore>();
  if (store.momentumOpen || store.presentationOpen) return;
  store.momentumOpen = true;
  try {
    AnalyticsService.instance.screen('momentum');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/momentum'),
        builder: (_) => const MomentumScreen(),
      ),
    );
  } finally {
    store.momentumOpen = false;
  }
}

class MomentumSkeleton extends StatelessWidget {
  const MomentumSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: momentumText(context, 'Loading Momentum', 'Cargando Momentum'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [180.0, 260.0, 140.0])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              width: width,
              height: 14,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Same strip for all financial features; only shows an actually assigned relevant mission.
class MomentumContextStrip extends StatelessWidget {
  const MomentumContextStrip({super.key, required this.feature});
  final String feature;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<MomentumStore>().state;
    context.watch<LangStore>();
    if (state == null || !state.enabled) return const SizedBox.shrink();
    final match =
        state.missions
            .where(
              (m) =>
                  m.actionable &&
                  ((feature == 'analytics' && m.review) ||
                      (Uri.tryParse(
                            m.deeplink,
                          )?.path.split('/').contains(feature) ??
                          false)),
            )
            .firstOrNull;
    if (match == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.md),
      child: LGSolidCard(
        tinted: true,
        child: Row(
          children: [
            const MomentumAsset(assetKey: 'momentum_mark', size: 24),
            const SizedBox(width: LGSpacing.sm),
            Expanded(
              child: Text(
                '${match.title(momentumLanguage(context))} · ${match.progress}/${match.target}',
              ),
            ),
            TextButton(
              style: momentumTextButtonStyle(context),
              onPressed: () => openMomentum(context),
              child: Text(momentumText(context, 'View', 'Ver')),
            ),
          ],
        ),
      ),
    );
  }
}

class MomentumProgressRing extends StatelessWidget {
  const MomentumProgressRing({
    super.key,
    required this.completed,
    required this.total,
  });
  final int completed, total;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$completed/$total ${momentumText(context, "required missions complete", "misiones requeridas completadas")}',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: total <= 0 ? 0 : (completed / total).clamp(0, 1),
                strokeWidth: 5,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
                color: const Color(0xFF22B66F),
              ),
            ),
            Text(
              '$completed/$total',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
