typedef Json = Map<String, dynamic>;

Json object(dynamic value) => value is Map ? value.cast<String, dynamic>() : {};
int count(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String localized(dynamic value, String language) {
  if (value is String) return value;
  final map = object(value);
  return (map[language] ?? map['en'] ?? map['es'] ?? '').toString();
}

class MomentumMission {
  MomentumMission(this.json);
  final Json json;
  String get key => json['key'] as String? ?? '';
  String get scope => json['scope'] as String? ?? '';
  String get status => json['status'] as String? ?? 'unavailable';
  String get deeplink => json['deeplink'] as String? ?? '';
  String? get slot => json['slot'] as String?;
  int get progress => count(json['progress']);
  int get target => count(json['target']);
  int get nominalXp => count(json['nominal_xp']);
  int get grantedXp => count(json['granted_xp']);
  bool get review => json['review'] == true;
  bool get completed => status == 'completed';
  bool get actionable => status == 'active' && json['reason'] == null;
  String title(String language) => localized(json['title'], language);
  String requirement(String language) =>
      localized(json['requirement'], language);
  String reason(String language) => localized(json['reason'], language);
}

class MomentumAchievement {
  MomentumAchievement(this.json);
  final Json json;
  String get key => json['key'] as String? ?? '';
  bool get completed => json['completed_at'] != null;
  bool get seen => json['seen_at'] != null;
  bool get available => json['available'] == true;
  int get progress => count(json['progress']);
  int get target => count(json['target']);
  int get xp => count(json['xp']);
  String title(String language) => localized(json['title'], language);
  String requirement(String language) =>
      localized(json['requirement'], language);
  String reason(String language) => localized(json['reason'], language);
}

class MomentumState {
  MomentumState(this.json);
  final Json json;
  bool get enabled => json['enabled'] == true;
  int get userId => count(json['user_id']);
  int get xp => count(json['lifetime_xp']);
  int get rhythm => count(json['rhythm']);
  Json get level => object(json['level']);
  Json get week => object(json['week']);
  Json get month => object(json['month']);
  Json get preferences => object(json['preferences']);
  Json get credits => object(json['ai_credits']);
  Json get backfill => object(json['backfill']);
  bool get coachmarkSeen => json['coachmark_seen'] == true;
  List<MomentumMission> get missions =>
      (json['missions'] as List? ?? [])
          .map((e) => MomentumMission(object(e)))
          .toList();
  List<MomentumAchievement> get achievements =>
      (json['achievements'] as List? ?? [])
          .map((e) => MomentumAchievement(object(e)))
          .toList();
  int get creditBalance => count(credits['balance']);
  bool get canUseCredits => credits['available'] == true && creditBalance > 0;
  List<MomentumMission> get activation =>
      missions
          .where((m) => m.scope == 'activation' && m.actionable)
          .take(3)
          .toList();
  List<MomentumMission> get requiredWeek =>
      missions
          .where(
            (m) =>
                m.scope == 'weekly' && m.slot != null && m.status != 'replaced',
          )
          .toList();
  double get levelProgress {
    final minimum = count(level['minimum_xp']);
    final next = level['next_xp'] == null ? null : count(level['next_xp']);
    return next == null || next <= minimum
        ? 1
        : ((xp - minimum) / (next - minimum)).clamp(0, 1).toDouble();
  }
}
