import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../momentum/store.dart';
import '../screens/password_recovery_screen.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import 'analytics_service.dart';
import 'push_service.dart';

final sessionNavigatorKey = GlobalKey<NavigatorState>();
final sessionRouteObserver = SessionRouteObserver();

class SessionRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  String? current;

  void _updateCurrent() {
    current = _routes.isEmpty ? null : _routes.last.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // This observer is reused when the application navigator is recreated.
    if (previousRoute == null) _routes.clear();
    _routes.add(route);
    _updateCurrent();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _updateCurrent();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _updateCurrent();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _updateCurrent();
  }

  void removeProtectedRoutes(NavigatorState navigator) {
    // Recovery must remain usable without exposing a protected route below it.
    // Use the current handles, including links received since lock was scheduled.
    final protected =
        _routes
            .skip(1)
            .where((route) => route.settings.name != '/reset-password')
            .toList();
    for (final route in protected.reversed) {
      if (_routes.contains(route) && route.navigator == navigator) {
        navigator.removeRoute(route);
      }
    }
  }
}

/// Owns authenticated foreground work; background notification delivery creates no usage.
class SessionLifecycle extends StatefulWidget {
  const SessionLifecycle({super.key, required this.child});
  final Widget child;
  @override
  State<SessionLifecycle> createState() => _SessionLifecycleState();
}

class _SessionLifecycleState extends State<SessionLifecycle>
    with WidgetsBindingObserver {
  AuthStore? _auth;
  RefreshBus? _bus;
  MomentumStore? _momentum;
  bool _foreground = true;
  bool _active = false;
  int _generation = 0;
  int? _lastUser;
  bool _wasLocked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthStore>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_changed);
    _bus?.removeListener(_mutation);
    _auth = auth;
    _bus = context.read<RefreshBus>();
    _momentum = context.read<MomentumStore>();
    auth.addListener(_changed);
    _bus!.addListener(_mutation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  void _changed() {
    if (!mounted) return;
    final generation = ++_generation;
    final auth = _auth!;
    if (!auth.isInitialized) return;
    if (!_foreground &&
        auth.biometricEnabled &&
        auth.isAuthenticated &&
        !auth.isExternalActivityActive) {
      // lock notifies synchronously; its reentrant change performs suspension.
      // This also locks a native handoff that finishes while still backgrounded.
      unawaited(auth.lock());
      return;
    }
    final identityChanged = _lastUser != null && auth.userId != _lastUser;
    final locking = auth.isLocked && !_wasLocked;
    if (identityChanged || locking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!identityChanged && !auth.isLocked) return;
        final navigator = sessionNavigatorKey.currentState;
        if (navigator != null) {
          sessionRouteObserver.removeProtectedRoutes(navigator);
        }
      });
    }
    _lastUser = auth.userId;
    _wasLocked = auth.isLocked;
    final active = auth.isAuthenticated && _foreground;
    final wasActive = _active;
    _active = active;
    if (!active) {
      _momentum!.suspend();
      AnalyticsService.instance.background();
      if (!auth.hasToken) {
        unawaited(_momentum!.bind(auth));
        unawaited(AnalyticsService.instance.bind(auth));
      }
      return;
    }
    if (!wasActive) {
      unawaited(PushService.instance.syncTokenWithBackend());
    }
    unawaited(() async {
      unawaited(_momentum!.bind(auth));
      await AnalyticsService.instance.bind(auth);
      if (!mounted || generation != _generation) return;
      if (_active && !AnalyticsService.instance.isForeground) {
        AnalyticsService.instance.foreground();
        unawaited(_momentum!.refresh(force: false));
      }
    }());
  }

  void _mutation() {
    if (_auth?.isAuthenticated == true) _momentum?.financialMutation();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (uri.path != '/reset-password' && uri.host != 'reset-password') {
      return false;
    }
    // Handle the original URI before WidgetsApp removes its scheme and host.
    final token = recoveryTokenFromUri(uri);
    void openRecovery() {
      if (!mounted) return;
      final navigator = sessionNavigatorKey.currentState;
      if (navigator == null) return;
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/reset-password'),
            builder: (_) => ResetPasswordScreen(token: token),
          ),
        ),
      );
    }

    if (sessionNavigatorKey.currentState == null) {
      // Let the root navigator finish mounting before adding the recovery route.
      WidgetsBinding.instance.addPostFrameCallback((_) => openRecovery());
    } else {
      openRecovery();
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _changed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_changed);
    _bus?.removeListener(_mutation);
    AnalyticsService.instance.background();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
