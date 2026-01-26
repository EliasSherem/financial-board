import 'package:shared_preferences/shared_preferences.dart';

class SavingsGoalStore {
  SavingsGoalStore._();

  static String _key(int? userId) => 'savings_goal_${userId ?? 'anon'}';

  static Future<double?> load(int? userId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_key(userId));
  }

  static Future<void> save(int? userId, double? amount) async {
    final sp = await SharedPreferences.getInstance();
    if (amount == null || !amount.isFinite || amount <= 0) {
      await sp.remove(_key(userId));
    } else {
      await sp.setDouble(_key(userId), amount);
    }
  }
}
