double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

class Account {
  final int id;
  final String name;
  final String? type;
  final double balance;
  final double? rawBalance;
  final String? accountNumber;
  final String? bankName;
  final bool isActive;
  final int? investmentId;
  final double? investmentPrincipal;
  final double? investmentAnnualRate;
  final double? investmentContributionTotal;
  final double? investmentEstimatedValue;
  final DateTime? investmentStartDate;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.rawBalance,
    this.type,
    this.accountNumber,
    this.bankName,
    required this.isActive,
    this.investmentId,
    this.investmentPrincipal,
    this.investmentAnnualRate,
    this.investmentContributionTotal,
    this.investmentEstimatedValue,
    this.investmentStartDate,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as int,
    name: j['name'] as String,
    type: j['type'] as String?,
    balance: _asDouble(j['balance']),
    rawBalance: j['raw_balance'] != null ? _asDouble(j['raw_balance']) : null,
    accountNumber: j['account_number'] as String?,
    bankName: j['bank_name'] as String?,
    isActive: (j['is_active'] == 1) || (j['is_active'] == true),
    investmentId: j['investment_id'] as int?,
    investmentPrincipal:
        j['investment_principal'] != null
            ? _asDouble(j['investment_principal'])
            : null,
    investmentAnnualRate:
        j['investment_annual_rate'] != null
            ? _asDouble(j['investment_annual_rate'])
            : null,
    investmentContributionTotal:
        j['investment_total_contributions'] != null
            ? _asDouble(j['investment_total_contributions'])
            : null,
    investmentEstimatedValue:
        j['investment_estimated_value'] != null
            ? _asDouble(j['investment_estimated_value'])
            : null,
    investmentStartDate:
        j['investment_start_date'] != null
            ? DateTime.tryParse(j['investment_start_date'] as String)
            : null,
  );

  bool get isInvestment => investmentId != null;
  double get displayBalance => investmentEstimatedValue ?? balance;
  double get editableBalance => rawBalance ?? balance;
}

class TransactionItem {
  final int id;
  final int accountId;
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final String? category;
  final int? categoryId;
  final int? subcategoryId;
  final String? categoryName;
  final String? subcategoryName;
  final String? categoryIcon;
  final String? subcategoryIcon;
  final String? accountName;
  final int? projectId;
  final String? projectName;

  TransactionItem({
    required this.id,
    required this.accountId,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.category,
    this.categoryId,
    this.subcategoryId,
    this.categoryName,
    this.subcategoryName,
    this.categoryIcon,
    this.subcategoryIcon,
    this.accountName,
    this.projectId,
    this.projectName,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> j) {
    final rawProjectId = j['project_id'];
    int? projectId;
    if (rawProjectId is num) {
      projectId = rawProjectId.toInt();
    } else if (rawProjectId is String) {
      projectId = int.tryParse(rawProjectId);
    }
    return TransactionItem(
      id: j['id'] as int,
      accountId: j['account_id'] as int,
      date: DateTime.parse(j['date'] as String),
      description: j['description'] as String? ?? '',
      amount: _asDouble(j['amount']),
      type:
          j['type'] as String? ??
          (_asDouble(j['amount']) >= 0 ? 'Income' : 'Expense'),
      category: j['category'] as String?,
      categoryId: (j['category_id'] as num?)?.toInt(),
      subcategoryId: (j['subcategory_id'] as num?)?.toInt(),
      categoryName: j['category_name'] as String?,
      subcategoryName: j['subcategory_name'] as String?,
      categoryIcon: j['category_icon'] as String?,
      subcategoryIcon: j['subcategory_icon'] as String?,
      accountName: j['account_name'] as String?,
      projectId: projectId,
      projectName: j['project_name'] as String?,
    );
  }

  String? get effectiveCategory => subcategoryName ?? categoryName ?? category;
}

class ExpenseSubcategory {
  final int id;
  final String name;
  final String icon;
  final double budget;

  const ExpenseSubcategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.budget,
  });

  factory ExpenseSubcategory.fromJson(Map<String, dynamic> j) =>
      ExpenseSubcategory(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? 'subcategory',
        budget: _asDouble(j['budget']),
      );
}

class ExpenseCategory {
  final int id;
  final String name;
  final String icon;
  final List<ExpenseSubcategory> subcategories;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.subcategories,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    icon: j['icon'] as String? ?? 'category',
    subcategories:
        (j['subcategories'] as List<dynamic>? ?? const [])
            .map(
              (e) => ExpenseSubcategory.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
  );
}

class Project {
  final int id;
  final String name;
  final String? description;
  final double budget;
  final double spent;
  final String status;
  final String? startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.budget,
    required this.spent,
    required this.status,
    this.startDate,
    this.endDate,
  });

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as int,
    name: j['name'] as String,
    description: j['description'] as String?,
    budget: _asDouble(j['budget']),
    spent: _asDouble(j['spent']),
    status: j['status'] as String? ?? 'Active',
    startDate: j['start_date'] as String?,
    endDate: j['end_date'] as String?,
  );
}

class InvoiceSummary {
  final int id;
  final String number;
  final String customerName;
  final String? customerEmail;
  final String? customerCompany;
  final String? customerTaxId;
  final String? customerAddress;
  final String status;
  final String currency;
  final String? notes;
  final DateTime issueDate;
  final DateTime dueDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double amountDue;

  InvoiceSummary({
    required this.id,
    required this.number,
    required this.customerName,
    this.customerEmail,
    this.customerCompany,
    this.customerTaxId,
    this.customerAddress,
    required this.status,
    required this.currency,
    this.notes,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.amountDue,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> j) => InvoiceSummary(
    id: j['id'] as int,
    number: j['number'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? '',
    customerEmail: j['customer_email'] as String?,
    customerCompany: j['customer_company'] as String?,
    customerTaxId: j['customer_tax_id'] as String?,
    customerAddress: j['customer_address'] as String?,
    status: j['status'] as String? ?? 'draft',
    currency: j['currency'] as String? ?? 'MXN',
    notes: j['notes'] as String?,
    issueDate: DateTime.parse(j['issue_date'] as String),
    dueDate: DateTime.parse(j['due_date'] as String),
    subtotal: _asDouble(j['subtotal']),
    discount: _asDouble(j['discount']),
    tax: _asDouble(j['tax']),
    total: _asDouble(j['total']),
    amountDue: _asDouble(j['amount_due']),
  );
}

class InvoiceDetail {
  final InvoiceSummary invoice;
  final List<InvoiceItem> items;
  final List<InvoicePayment> payments;
  InvoiceDetail({
    required this.invoice,
    required this.items,
    required this.payments,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> j) => InvoiceDetail(
    invoice: InvoiceSummary.fromJson(j['invoice'] as Map<String, dynamic>),
    items:
        (j['items'] as List<dynamic>)
            .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
    payments:
        (j['payments'] as List<dynamic>)
            .map((e) => InvoicePayment.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
}

// Simple customer model for invoices page
class Customer {
  final int id;
  final String name;
  final String? email;
  final String? company;
  final String? taxId;
  final String? address;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.company,
    this.taxId,
    this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    email: j['email'] as String?,
    company: j['company'] as String?,
    taxId: j['tax_id'] as String?,
    address: j['address'] as String?,
  );
}

class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;
  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });
  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
    description: j['description'] as String? ?? '',
    quantity: _asDouble(j['quantity']),
    unitPrice: _asDouble(j['unit_price']),
    amount: _asDouble(j['amount']),
  );
}

class InvoicePayment {
  final String date;
  final double amount;
  final String? accountName;
  InvoicePayment({required this.date, required this.amount, this.accountName});
  factory InvoicePayment.fromJson(Map<String, dynamic> j) => InvoicePayment(
    date: j['date'] as String? ?? '',
    amount: _asDouble(j['amount']),
    accountName: j['account_name'] as String?,
  );
}

class PaymentItem {
  final int id;
  final int accountId;
  final String name;
  final String? description;
  final double amount;
  final String frequency; // Weekly | Monthly | Quarterly | Yearly
  final String nextDate; // YYYY-MM-DD
  final bool isActive;
  final String? category;
  final int? categoryId;
  final int? subcategoryId;
  final String? categoryName;
  final String? subcategoryName;
  final String? categoryIcon;
  final String? subcategoryIcon;
  final int? projectId;
  final String? accountName;
  final String? projectName;
  final int? installmentsTotal;
  final int? installmentsRemaining;
  final double? installmentTotalAmount;

  PaymentItem({
    required this.id,
    required this.accountId,
    required this.name,
    this.description,
    required this.amount,
    required this.frequency,
    required this.nextDate,
    required this.isActive,
    this.category,
    this.categoryId,
    this.subcategoryId,
    this.categoryName,
    this.subcategoryName,
    this.categoryIcon,
    this.subcategoryIcon,
    this.projectId,
    this.accountName,
    this.projectName,
    this.installmentsTotal,
    this.installmentsRemaining,
    this.installmentTotalAmount,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> j) => PaymentItem(
    id: j['id'] as int,
    accountId: j['account_id'] as int,
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    amount: _asDouble(j['amount']),
    frequency: j['frequency'] as String? ?? 'Monthly',
    nextDate: (j['next_date'] as String?) ?? '',
    isActive: (j['is_active'] == 1) || (j['is_active'] == true),
    category: j['category'] as String?,
    categoryId: j['category_id'] as int?,
    subcategoryId: j['subcategory_id'] as int?,
    categoryName: j['category_name'] as String?,
    subcategoryName: j['subcategory_name'] as String?,
    categoryIcon: j['category_icon'] as String?,
    subcategoryIcon: j['subcategory_icon'] as String?,
    projectId: j['project_id'] == null ? null : (j['project_id'] as int),
    accountName: j['account_name'] as String?,
    projectName: j['project_name'] as String?,
    installmentsTotal: (j['installments_total'] as num?)?.toInt(),
    installmentsRemaining: (j['installments_remaining'] as num?)?.toInt(),
    installmentTotalAmount:
        (j['installment_total_amount'] != null)
            ? _asDouble(j['installment_total_amount'])
            : null,
  );
}

class BalanceHistoryItem {
  final int accountId;
  final int year;
  final int month; // 1-12
  final double balance;
  final String? accountName;

  BalanceHistoryItem({
    required this.accountId,
    required this.year,
    required this.month,
    required this.balance,
    this.accountName,
  });

  factory BalanceHistoryItem.fromJson(Map<String, dynamic> j) =>
      BalanceHistoryItem(
        accountId: j['account_id'] as int,
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        balance: _asDouble(j['balance']),
        accountName: j['account_name'] as String?,
      );
}
