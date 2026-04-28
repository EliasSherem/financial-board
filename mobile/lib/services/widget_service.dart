import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Thin wrapper around [home_widget] so the rest of the app does not need to
/// know about platform specific identifiers or storage keys.
class NativeWidgetBridge {
  static const String _androidQualifiedName =
      'com.example.mobile.FinancialBoardWidgetProvider';
  static const String _iosWidgetName = 'FinancialBoardWidget';
  static const String _appGroupId = 'group.mx.com.finsight';

  static const String actionCreateTransaction = 'create-transaction';
  static const String actionCreateRecurringPayment = 'create-recurring-payment';

  static const String _keyDisplay = 'kpi_spent_display';
  static const String _keyMonthLabel = 'kpi_spent_month_label';
  static const String _keyUpdatedAt = 'kpi_spent_updated_at';
  static const String _keyAmount = 'kpi_spent_amount';

  static bool _initialised = false;
  static final StreamController<Uri> _uriController =
      StreamController<Uri>.broadcast();
  static Uri? _initialUri;

  static Stream<Uri> get widgetEvents => _uriController.stream;

  static Future<void> ensureInitialized() async {
    if (_initialised) return;
    _initialised = true;

    if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId(_appGroupId);
      } catch (e, stack) {
        debugPrint('HomeWidget setAppGroupId failed: $e\n$stack');
      }
    }

    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _initialUri = initialUri;
      }
    } catch (e) {
      debugPrint('HomeWidget initial launch query failed: $e');
    }

    HomeWidget.widgetClicked.listen(
      (uri) {
        if (uri != null) {
          _uriController.add(uri);
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('HomeWidget click stream error: $error\n$stack');
      },
    );
  }

  static Future<void> updateMonthlySpend({
    required String displayValue,
    required String monthLabel,
    required double rawAmount,
  }) async {
    try {
      await HomeWidget.saveWidgetData(_keyDisplay, displayValue);
      await HomeWidget.saveWidgetData(_keyMonthLabel, monthLabel);
      await HomeWidget.saveWidgetData(
        _keyUpdatedAt,
        DateTime.now().toIso8601String(),
      );
      await HomeWidget.saveWidgetData(_keyAmount, rawAmount);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidQualifiedName,
        iOSName: _iosWidgetName,
      );
    } catch (e, stack) {
      debugPrint('Failed updating home widget: $e\n$stack');
    }
  }

  static String? actionFromUri(Uri uri) {
    final List<String> tokens = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
    final queryAction = uri.queryParameters['action'];
    if (queryAction != null && queryAction.isNotEmpty) {
      tokens.add(queryAction);
    }
    if (tokens.contains(actionCreateTransaction))
      return actionCreateTransaction;
    if (tokens.contains(actionCreateRecurringPayment)) {
      return actionCreateRecurringPayment;
    }
    return null;
  }

  static bool shouldOpenQuickTransaction(Uri uri) {
    return actionFromUri(uri) == actionCreateTransaction;
  }

  static Uri? consumeInitialUri() {
    final uri = _initialUri;
    _initialUri = null;
    return uri;
  }
}
