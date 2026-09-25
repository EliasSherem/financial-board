import '../services/api.dart';
import '../services/client_context.dart';
import 'models.dart';

class MomentumService {
  MomentumService(String token) : api = ApiClient()..setToken(token);
  final ApiClient api;
  // Evaluating progress can exceed the normal 15s request deadline when the
  // development API connects to the remote database. Keep this bound local to
  // Momentum evaluation; ordinary financial requests retain their deadline.
  static const _evaluationTimeout = Duration(seconds: 90);
  Future<MomentumState> me() async {
    await ClientContext.refresh();
    return MomentumState(
      object(
        await api.get(
          '/api/engagement/me',
          timeout: _evaluationTimeout,
          query: {
            if (ClientContext.timezone != null)
              'timezone_name': ClientContext.timezone,
            'timezone_offset_min': DateTime.now().timeZoneOffset.inMinutes,
          },
        ),
      ),
    );
  }

  Future<Json> review(String kind) async => object(
    await api.get(
      '/api/engagement/review/${Uri.encodeComponent(kind)}',
      timeout: _evaluationTimeout,
    ),
  );
  Future<MomentumState> confirm(String kind, Json payload) async =>
      MomentumState(
        object(
          await api.post(
            '/api/engagement/$kind-review',
            body: payload,
            timeout: _evaluationTimeout,
          ),
        ),
      );
  Future<MomentumState> event(Json payload) async => MomentumState(
    object(
      await api.post(
        '/api/engagement/client-events',
        body: payload,
        timeout: _evaluationTimeout,
      ),
    ),
  );
  Future<void> seen(String key) async => api.post(
    '/api/engagement/achievements/${Uri.encodeComponent(key)}/seen',
    body: {},
  );
  Future<MomentumState> preferences(Json values) async => MomentumState(
    object(
      await api.post(
        '/api/engagement/preferences',
        body: values,
        timeout: _evaluationTimeout,
      ),
    ),
  );
}
