import 'dart:convert';
import 'dart:typed_data';

import '../models.dart';
import 'api.dart';

class DataService {
  DataService(this.api);
  final ApiClient api;

  Future<List<Account>> getAccounts() async {
    final res = await api.get('/api/accounts');
    return (res as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Account> createAccount({
    required String name,
    String? type,
    double balance = 0,
    String? bankName,
    String? accountNumber,
    bool isActive = true,
  }) async {
    final res = await api.post(
      '/api/accounts',
      body: {
        'name': name,
        'type': type,
        'balance': balance,
        'bank_name': bankName,
        'account_number': accountNumber,
        'is_active': isActive,
      },
    );
    return Account.fromJson(res as Map<String, dynamic>);
  }

  Future<Account> updateAccount(int id, Map<String, dynamic> account) async {
    final res = await api.put('/api/accounts/$id', body: account);
    return Account.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteAccount(int id) async {
    await api.delete('/api/accounts/$id');
  }

  Future<List<TransactionItem>> getTransactions() async {
    final res = await api.get('/api/transactions');
    return (res as List)
        .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionItem> createTransaction({
    required int accountId,
    required DateTime date,
    required String description,
    required double amount,
    required String type, // 'Income' | 'Expense'
    String? category,
    int? categoryId,
    int? subcategoryId,
    int? projectId,
  }) async {
    final res = await api.post(
      '/api/transactions',
      body: {
        'account_id': accountId,
        'date': date.toIso8601String().substring(0, 10),
        'description': description,
        'amount': type == 'Expense' ? -amount.abs() : amount.abs(),
        'type': type,
        if (category != null) 'category': category,
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        if (projectId != null) 'project_id': projectId,
      },
    );
    return TransactionItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> transferFunds({
    required Account fromAccount,
    required Account toAccount,
    required DateTime date,
    required double amount,
    String? description,
  }) async {
    final note = (description ?? '').trim();
    final transferLabel = note.isEmpty ? 'Fund transfer' : note;

    await createTransaction(
      accountId: fromAccount.id,
      date: date,
      description: 'Transfer to ${toAccount.name}: $transferLabel',
      amount: amount,
      type: 'Expense',
      category: 'Transfer',
    );

    await createTransaction(
      accountId: toAccount.id,
      date: date,
      description: 'Transfer from ${fromAccount.name}: $transferLabel',
      amount: amount,
      type: 'Income',
      category: 'Transfer',
    );
  }

  Future<TransactionItem> updateTransaction({
    required int id,
    required int accountId,
    required DateTime date,
    required String description,
    required double amount,
    required String type, // 'Income' | 'Expense'
    String? category,
    int? categoryId,
    int? subcategoryId,
    int? projectId,
  }) async {
    final res = await api.put(
      '/api/transactions/$id',
      body: {
        'account_id': accountId,
        'date': date.toIso8601String().substring(0, 10),
        'description': description,
        'amount': type == 'Expense' ? -amount.abs() : amount.abs(),
        'type': type,
        if (category != null) 'category': category,
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        if (projectId != null) 'project_id': projectId,
      },
    );
    return TransactionItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(int id) async {
    await api.delete('/api/transactions/$id');
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final res = await api.get('/api/expense-categories');
    return (res as List<dynamic>)
        .map(
          (e) => ExpenseCategory.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<ExpenseCategory> createExpenseCategory({
    required String name,
    required String icon,
  }) async {
    final res = await api.post(
      '/api/expense-categories',
      body: {'name': name, 'icon': icon},
    );
    return ExpenseCategory.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<ExpenseCategory> updateExpenseCategory({
    required int id,
    required String name,
    required String icon,
  }) async {
    final res = await api.put(
      '/api/expense-categories/$id',
      body: {'name': name, 'icon': icon},
    );
    return ExpenseCategory.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> deleteExpenseCategory(int id) async {
    await api.delete('/api/expense-categories/$id');
  }

  Future<ExpenseCategory> createExpenseSubcategory({
    required int categoryId,
    required String name,
    required String icon,
    double budget = 0,
  }) async {
    final res = await api.post(
      '/api/expense-subcategories',
      body: {
        'category_id': categoryId,
        'name': name,
        'icon': icon,
        'budget': budget,
      },
    );
    return ExpenseCategory.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<ExpenseCategory> updateExpenseSubcategory({
    required int id,
    required String name,
    required String icon,
    int? categoryId,
    double? budget,
  }) async {
    final res = await api.put(
      '/api/expense-subcategories/$id',
      body: {
        'name': name,
        'icon': icon,
        if (categoryId != null) 'category_id': categoryId,
        if (budget != null) 'budget': budget,
      },
    );
    return ExpenseCategory.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<ExpenseCategory?> deleteExpenseSubcategory(int id) async {
    final res = await api.delete('/api/expense-subcategories/$id');
    if (res == null) return null;
    return ExpenseCategory.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<List<Project>> getProjects() async {
    final res = await api.get('/api/projects');
    return (res as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject({
    required String name,
    String? description,
    double budget = 0,
    double spent = 0,
    String status = 'Active',
    String? startDate,
    String? endDate,
  }) async {
    final res = await api.post(
      '/api/projects',
      body: {
        'name': name,
        'description': description,
        'budget': budget,
        'spent': spent,
        'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return Project.fromJson(res as Map<String, dynamic>);
  }

  Future<Project> updateProject({
    required int id,
    required String name,
    String? description,
    double budget = 0,
    double spent = 0,
    String status = 'Active',
    String? startDate,
    String? endDate,
  }) async {
    final res = await api.put(
      '/api/projects/$id',
      body: {
        'name': name,
        'description': description,
        'budget': budget,
        'spent': spent,
        'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return Project.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteProject(int id) async {
    await api.delete('/api/projects/$id');
  }

  Future<List<InvoiceSummary>> getInvoices() async {
    final res = await api.get('/api/invoices');
    return (res as List)
        .map((e) => InvoiceSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InvoiceDetail> getInvoice(int id) async {
    final res = await api.get('/api/invoices/$id');
    return InvoiceDetail.fromJson(res as Map<String, dynamic>);
  }

  // Customers
  Future<List<Customer>> getCustomers() async {
    final res = await api.get('/api/customers');
    return (res as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> createCustomer({
    required String name,
    String? email,
    String? company,
    String? taxId,
    String? address,
  }) async {
    final res = await api.post(
      '/api/customers',
      body: {
        'name': name,
        'email': email,
        'company': company,
        'tax_id': taxId,
        'address': address,
      },
    );
    return Customer.fromJson(res as Map<String, dynamic>);
  }

  Future<Customer> updateCustomer({
    required int id,
    required String name,
    String? email,
    String? company,
    String? taxId,
    String? address,
  }) async {
    final res = await api.put(
      '/api/customers/$id',
      body: {
        'name': name,
        'email': email,
        'company': company,
        'tax_id': taxId,
        'address': address,
      },
    );
    return Customer.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(int id) async {
    await api.delete('/api/customers/$id');
  }

  // Invoices CRUD and payments
  Future<Map<String, dynamic>> createInvoice({
    required int customerId,
    required String issueDate, // YYYY-MM-DD
    required String dueDate, // YYYY-MM-DD
    String? number,
    String currency = 'MXN',
    String? notes,
    List<Map<String, dynamic>> items = const [],
    int? projectId,
    int? accountId,
    double? discount,
    double? tax,
  }) async {
    final res = await api.post(
      '/api/invoices',
      body: {
        'customer_id': customerId,
        'project_id': projectId,
        'account_id': accountId,
        'number': number,
        'issue_date': issueDate,
        'due_date': dueDate,
        'currency': currency,
        'notes': notes,
        'discount': discount,
        'tax': tax,
        'items': items,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateInvoice({
    required int id,
    required int customerId,
    required String issueDate,
    required String dueDate,
    String? number,
    String currency = 'MXN',
    String? notes,
    List<Map<String, dynamic>> items = const [],
    int? projectId,
    int? accountId,
    double? discount,
    double? tax,
  }) async {
    final res = await api.put(
      '/api/invoices/$id',
      body: {
        'customer_id': customerId,
        'project_id': projectId,
        'account_id': accountId,
        'number': number,
        'issue_date': issueDate,
        'due_date': dueDate,
        'currency': currency,
        'notes': notes,
        'discount': discount,
        'tax': tax,
        'items': items,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<void> payInvoice({
    required int id,
    required String date, // YYYY-MM-DD
    required double amount,
    required int accountId,
    String? method,
    String? reference,
  }) async {
    await api.post(
      '/api/invoices/$id/payments',
      body: {
        'date': date,
        'amount': amount,
        'account_id': accountId,
        'method': method,
        'reference': reference,
      },
    );
  }

  Future<void> deleteInvoice(int id) async {
    await api.delete('/api/invoices/$id');
  }

  Future<Map<String, dynamic>> emailInvoice({
    required int id,
    required String filename,
    required Uint8List pdfBytes,
  }) async {
    final res = await api.post(
      '/api/invoices/$id/email',
      body: {'filename': filename, 'pdf_base64': base64Encode(pdfBytes)},
    );
    return res as Map<String, dynamic>;
  }

  // Payments
  Future<List<PaymentItem>> getPayments() async {
    final res = await api.get('/api/payments');
    return (res as List)
        .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentItem> createPayment({
    required int accountId,
    required String name,
    required double amount,
    String frequency = 'Monthly',
    required String nextDate,
    bool isActive = true,
    String? description,
    String? category,
    int? categoryId,
    int? subcategoryId,
    int? projectId,
  }) async {
    final res = await api.post(
      '/api/payments',
      body: {
        'account_id': accountId,
        'name': name,
        'description': description,
        'amount': amount,
        'frequency': frequency,
        'next_date': nextDate,
        'is_active': isActive,
        'category': category,
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        'project_id': projectId,
      },
    );
    return PaymentItem.fromJson(res as Map<String, dynamic>);
  }

  Future<PaymentItem> updatePayment({
    required int id,
    required int accountId,
    required String name,
    required double amount,
    String frequency = 'Monthly',
    required String nextDate,
    bool isActive = true,
    String? description,
    String? category,
    int? categoryId,
    int? subcategoryId,
    int? projectId,
  }) async {
    final res = await api.put(
      '/api/payments/$id',
      body: {
        'account_id': accountId,
        'name': name,
        'description': description,
        'amount': amount,
        'frequency': frequency,
        'next_date': nextDate,
        'is_active': isActive,
        'category': category,
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        'project_id': projectId,
      },
    );
    return PaymentItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deletePayment(int id) async {
    await api.delete('/api/payments/$id');
  }

  Future<Map<String, dynamic>> processOverduePayments() async {
    final res = await api.post('/api/payments/process-overdue', body: {});
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processPayment(int id) async {
    final res = await api.post('/api/payments/$id/process', body: {});
    return res as Map<String, dynamic>;
  }

  // Create a finite credit installment plan (server computes monthly amount)
  Future<PaymentItem> createInstallmentPlan({
    required int account_id,
    int? project_id,
    required String name,
    String? description,
    required double total_amount,
    required int months,
    required String first_due_date, // YYYY-MM-DD
    String? category,
    int? categoryId,
    int? subcategoryId,
  }) async {
    final res = await api.post(
      '/api/credit/installments',
      body: {
        'account_id': account_id,
        'project_id': project_id,
        'name': name,
        'description': description,
        'total_amount': total_amount,
        'months': months,
        'first_due_date': first_due_date,
        'category': category,
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
      },
    );
    return PaymentItem.fromJson(res as Map<String, dynamic>);
  }

  // Analytics
  Future<List<BalanceHistoryItem>> getBalanceHistory() async {
    final res = await api.get('/api/balance-history');
    return (res as List)
        .map((e) => BalanceHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> rebuildBalanceHistory() async {
    await api.post('/api/balance-history/rebuild', body: {});
  }

  // Notifications (computed by server)
  Future<List<Map<String, dynamic>>> getNotifications({int days = 7}) async {
    final res = await api.get('/api/notifications?days=$days');
    return (res as List).map((e) => (e as Map<String, dynamic>)).toList();
  }

  Future<void> registerDeviceToken({
    required String token,
    String? platform,
    int? timezoneOffsetMin,
    String? timezoneName,
  }) async {
    await api.post(
      '/api/device-tokens',
      body: {
        'token': token,
        'platform': platform,
        if (timezoneOffsetMin != null) 'timezone_offset_min': timezoneOffsetMin,
        if (timezoneName != null) 'timezone_name': timezoneName,
      },
    );
  }

  Future<Map<String, dynamic>> pushNotificationsNow() async {
    final res = await api.post('/api/notifications/push-now', body: {});
    return res as Map<String, dynamic>;
  }

  Future<String> aiChat({required List<Map<String, String>> messages}) async {
    final res = await api.post('/api/ai-chat', body: {'messages': messages});
    if (res is Map && res['reply'] != null) {
      return res['reply'] as String? ?? '';
    }
    throw Exception(
      res is Map && res['message'] != null ? res['message'] : 'AI chat failed',
    );
  }

  // Activate Pro on the server after a successful store purchase
  Future<void> activatePro() async {
    await api.post('/api/pro/activate', body: {});
  }

  // Investments
  Future<List<Map<String, dynamic>>> getInvestments() async {
    final res = await api.get('/api/investments');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getInvestmentDetail(int id) async {
    final res = await api.get('/api/investments/$id');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createInvestment({
    required String name,
    required double principal,
    required double annualRate,
    required String startDate, // YYYY-MM-DD
  }) async {
    final res = await api.post(
      '/api/investments',
      body: {
        'name': name,
        'principal': principal,
        'annual_rate': annualRate,
        'start_date': startDate,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateInvestment({
    required int id,
    required String name,
    required double principal,
    required double annualRate,
    required String startDate,
  }) async {
    final res = await api.put(
      '/api/investments/$id',
      body: {
        'name': name,
        'principal': principal,
        'annual_rate': annualRate,
        'start_date': startDate,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<void> deleteInvestment(int id) async {
    await api.delete('/api/investments/$id');
  }

  Future<Map<String, dynamic>> addInvestmentContribution({
    required int investmentId,
    required double amount,
    required String date, // YYYY-MM-DD
  }) async {
    final res = await api.post(
      '/api/investments/$investmentId/contributions',
      body: {'amount': amount, 'date': date},
    );
    return res as Map<String, dynamic>;
  }

  // Link Play Billing purchase token
  Future<void> linkPlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    await api.post(
      '/api/play/link',
      body: {'productId': productId, 'purchaseToken': purchaseToken},
    );
  }

  // Sync Play Billing status for current user
  Future<void> syncPlay() async {
    await api.post('/api/play/sync', body: {});
  }

  Future<void> stripeSync() async {
    await api.post('/api/stripe/sync', body: {});
  }

  Future<Map<String, dynamic>> cancelSubscription() async {
    final res = await api.post('/api/stripe/cancel', body: {});
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await api.get('/api/me');
    return res as Map<String, dynamic>;
  }

  // Salary rules (automated income)
  Future<List<Map<String, dynamic>>> getSalaryRules() async {
    final res = await api.get('/api/salaries');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSalaryRule({
    required String name,
    required double amount,
    String schedule = 'SemiMonthly',
    int? weekday,
    int? day,
    int? accountId,
    bool isActive = true,
  }) async {
    final res = await api.post(
      '/api/salaries',
      body: {
        'name': name,
        'amount': amount,
        'schedule': schedule,
        'weekday': weekday,
        'day': day,
        'account_id': accountId,
        'is_active': isActive,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSalaryRule({
    required int id,
    String? name,
    double? amount,
    String? schedule,
    int? weekday,
    int? day,
    int? accountId,
    bool? isActive,
  }) async {
    final res = await api.put(
      '/api/salaries/$id',
      body: {
        'name': name,
        'amount': amount,
        'schedule': schedule,
        'weekday': weekday,
        'day': day,
        'account_id': accountId,
        'is_active': isActive,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<void> deleteSalaryRule(int id) async {
    await api.delete('/api/salaries/$id');
  }
}
