import 'dart:async';

import 'package:flutter/foundation.dart';

class RefreshBus extends ChangeNotifier {
  RefreshBus() {
    _instance = this;
  }

  static RefreshBus? _instance;
  static RefreshBus? get instance => _instance;

  int _accounts = 0;
  int _transactions = 0;
  int _payments = 0;
  int _projects = 0;
  int _invoices = 0;
  int _customers = 0;
  int _investments = 0;
  Timer? _notifyTimer;

  int get accounts => _accounts;
  int get transactions => _transactions;
  int get payments => _payments;
  int get projects => _projects;
  int get invoices => _invoices;
  int get customers => _customers;
  int get investments => _investments;

  void _scheduleNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  void notifyAccounts() {
    _accounts += 1;
    _scheduleNotify();
  }

  void notifyTransactions() {
    _transactions += 1;
    _scheduleNotify();
  }

  void notifyPayments() {
    _payments += 1;
    _scheduleNotify();
  }

  void notifyProjects() {
    _projects += 1;
    _scheduleNotify();
  }

  void notifyInvoices() {
    _invoices += 1;
    _scheduleNotify();
  }

  void notifyCustomers() {
    _customers += 1;
    _scheduleNotify();
  }

  void notifyInvestments() {
    _investments += 1;
    _scheduleNotify();
  }

  void notifyAll() {
    _accounts += 1;
    _transactions += 1;
    _payments += 1;
    _projects += 1;
    _invoices += 1;
    _customers += 1;
    _investments += 1;
    _scheduleNotify();
  }

  void notifyFromPath(String path) {
    if (_shouldIgnore(path)) return;
    notifyAll();
  }

  bool _shouldIgnore(String path) {
    if (path.startsWith('/api/engagement')) return true;
    if (path.startsWith('/api/analytics')) return true;
    if (path.startsWith('/api/auth')) return true;
    if (path.startsWith('/api/billing')) return true;
    if (path.startsWith('/api/ai-chat')) return true;
    if (path.startsWith('/api/device-tokens')) return true;
    return false;
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
