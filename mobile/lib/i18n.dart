import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'lang_store.dart';

class I18n {
  static const Map<String, Map<String, String>> _dict = {
    // Navigation
    'nav.stats': {'en': 'Stats', 'es': 'Estad\u00EDsticas'},
    'nav.projects': {'en': 'Projects', 'es': 'Proyectos'},
    'nav.transactions': {'en': 'Transactions', 'es': 'Transacciones'},
    'nav.home': {'en': 'Home', 'es': 'Inicio'},
    'nav.invoices': {'en': 'Invoices', 'es': 'Facturas'},
    'nav.payments': {'en': 'Payments', 'es': 'Pagos'},
    'nav.account': {'en': 'Account', 'es': 'Cuenta'},
    'nav.calendar': {'en': 'Calendar', 'es': 'Calendario'},
    'nav.aiChat': {'en': 'AI Chat', 'es': 'Chat AI'},

    // Titles
    'title.accounts': {'en': 'Accounts', 'es': 'Cuentas'},
    'title.analytics': {'en': 'Analytics', 'es': 'Anal\u00EDtica'},
    'title.recurringPayments': {
      'en': 'Recurring Payments',
      'es': 'Pagos recurrentes',
    },
    'title.projects': {'en': 'Projects', 'es': 'Proyectos'},
    'title.investments': {'en': 'Investments', 'es': 'Inversiones'},
    'title.invoices': {'en': 'Invoices', 'es': 'Facturas'},
    'title.customers': {'en': 'Customers', 'es': 'Clientes'},
    'title.calendar': {'en': 'Calendar', 'es': 'Calendario'},
    'title.updateProfile': {'en': 'Update Profile', 'es': 'Actualizar perfil'},
    'title.settings': {'en': 'Settings', 'es': 'Ajustes'},
    'title.aiChat': {'en': 'AI Consultant', 'es': 'Consultor AI'},

    // Labels
    'label.currentBalance': {'en': 'Current Balance', 'es': 'Saldo actual'},
    'label.transactions': {'en': 'Transactions', 'es': 'Transacciones'},
    'label.add': {'en': 'Add', 'es': 'Agregar'},
    'label.addAccount': {'en': 'Add Account', 'es': 'A\u00F1adir cuenta'},
    'label.name': {'en': 'Name', 'es': 'Nombre'},
    'label.cancel': {'en': 'Cancel', 'es': 'Cancelar'},
    'label.save': {'en': 'Save', 'es': 'Guardar'},
    'label.clear': {'en': 'Clear', 'es': 'Limpiar'},
    'label.edit': {'en': 'Edit', 'es': 'Editar'},
    'label.delete': {'en': 'Delete', 'es': 'Eliminar'},
    'label.export': {'en': 'Export', 'es': 'Exportar'},
    'label.process': {'en': 'Process', 'es': 'Procesar'},
    'label.processed': {'en': 'Processed', 'es': 'Procesado'},
    'label.active': {'en': 'Active', 'es': 'Activo'},
    'forms.descriptionOptional': {
      'en': 'Description (optional)',
      'es': 'Descripci\u00F3n (opcional)',
    },
    'forms.emailOptional': {
      'en': 'Email (optional)',
      'es': 'Correo (opcional)',
    },

    // Add menu
    'add.newTransaction': {
      'en': 'New transaction',
      'es': 'Nueva transacci\u00F3n',
    },
    'add.newRecurringPayment': {
      'en': 'New recurring payment',
      'es': 'Nuevo pago recurrente',
    },
    'add.newAccount': {'en': 'New account', 'es': 'Nueva cuenta'},
    'add.newInvestment': {'en': 'New investment', 'es': 'Nueva inversi\u00F3n'},
    'add.newProject': {'en': 'New project', 'es': 'Nuevo proyecto'},
    'add.newInvoice': {'en': 'New invoice', 'es': 'Nueva factura'},
    'add.newCustomer': {'en': 'New client', 'es': 'Nuevo cliente'},
    'label.update': {'en': 'Update Profile', 'es': 'Actualizar perfil'},
    'label.manageInPlay': {
      'en': 'Manage in Google Play',
      'es': 'Gestionar en Google Play',
    },
    'label.updating': {'en': 'Updating...', 'es': 'Actualizando...'},
    'label.failed': {'en': 'Failed', 'es': 'Error'},
    'label.createAccount': {'en': 'Create Account', 'es': 'Crear cuenta'},

    // Calendar
    'calendar.noEvents': {
      'en': 'No events for this day',
      'es': 'Sin eventos para este d\u00EDa',
    },
    'calendar.addToCalendar': {
      'en': 'Add to calendar',
      'es': 'Agregar al calendario',
    },
    'calendar.duePayment': {'en': 'Payment due', 'es': 'Pago programado'},

    // Greeting / Dashboard
    'greet.morning': {'en': 'Good morning', 'es': 'Buenos d\u00EDas'},
    'greet.afternoon': {'en': 'Good afternoon', 'es': 'Buenas tardes'},
    'greet.night': {'en': 'Good night', 'es': 'Buenas noches'},
    'dashboard.subtitle': {
      'en': 'Welcome to your financial overview',
      'es': 'Bienvenido a tu resumen financiero',
    },
    'dashboard.subcategoryBudgets': {
      'en': 'Top subcategory budgets',
      'es': 'Top presupuestos por subcategoria',
    },
    'savingsGoal.title': {
      'en': 'Monthly savings goal',
      'es': 'Meta de ahorro mensual',
    },
    'savingsGoal.saved': {'en': 'Saved', 'es': 'Ahorrado'},
    'aiChat.placeholder': {
      'en': 'Ask about your budget, spending, or goals',
      'es': 'Pregunta sobre tu presupuesto, gastos o metas',
    },
    'aiChat.newChat': {'en': 'New chat', 'es': 'Nuevo chat'},
    'aiChat.chats': {'en': 'Chats', 'es': 'Chats'},
    'aiChat.disclaimer': {
      'en': 'AI suggestions are informational and not financial advice.',
      'es': 'Las sugerencias son informativas y no son asesoria financiera.',
    },
    'aiChat.empty': {
      'en': 'Ask me anything about your finances.',
      'es': 'Pregunta lo que quieras sobre tus finanzas.',
    },
    'aiChat.deleteTitle': {
      'en': 'Delete chat?',
      'es': '\u00BFEliminar chat?',
    },
    'aiChat.deleteBody': {
      'en': 'This will remove the chat history from this device.',
      'es': 'Esto eliminara el historial del chat en este dispositivo.',
    },
    'kpi.totalBalance': {'en': 'Total Balance', 'es': 'Saldo total'},
    'kpi.accounts': {'en': 'Accounts', 'es': 'Cuentas'},
    'kpi.netThisMonth': {'en': 'Monthly net', 'es': 'Neto mensual'},
    'kpi.thisMonthExpenses': {
      'en': 'This Month Expenses',
      'es': 'Gastos de este mes',
    },
    'kpi.budgetOverview': {
      'en': 'Budget usage',
      'es': 'Uso de presupuesto',
    },
    'kpi.budgetUsed': {
      'en': '{percent}% used',
      'es': '{percent}% usado',
    },
    'kpi.used': {'en': 'used', 'es': 'usado'},
    'kpi.activeProjects': {'en': 'Active Projects', 'es': 'Proyectos activos'},
    'kpi.balanceGrowth': {'en': 'Balance growth', 'es': 'Crecimiento de saldo'},
    'kpi.vsLastMonth': {'en': 'vs last month', 'es': 'vs el mes pasado'},
    'label.ok': {'en': 'OK', 'es': 'Aceptar'},
    'onboarding.finishSetup': {
      'en': 'Finish setup to continue.',
      'es': 'Completa la configuracion para continuar.',
    },
    'onboarding.createFirstAccount': {
      'en': 'Create your first account to continue.',
      'es': 'Crea tu primera cuenta para continuar.',
    },
    'onboarding.tapAccount': {
      'en': 'Tap Account to create your first account.',
      'es': 'Toca Cuenta para crear tu primera cuenta.',
    },
    'onboarding.tapCategories': {
      'en': 'Open the menu and choose Manage Categories.',
      'es': 'Abre el menu y elige Administrar categorias.',
    },
    'onboarding.tapTransactions': {
      'en': 'Tap Transactions to add your first transaction.',
      'es': 'Toca Transacciones para agregar tu primera transaccion.',
    },
    'onboarding.createFirstCategory': {
      'en': 'Create your first category to continue.',
      'es': 'Crea tu primera categoria para continuar.',
    },
    'onboarding.createFirstSubcategory': {
      'en': 'Add your first subcategory to continue.',
      'es': 'Agrega tu primera subcategoria para continuar.',
    },

    // Payments KPIs / sections
    'payments.kpi.active': {'en': 'Active Payments', 'es': 'Pagos activos'},
    'payments.kpi.paused': {'en': 'Paused Payments', 'es': 'Pagos en pausa'},
    'payments.kpi.monthly': {'en': 'Monthly Total', 'es': 'Total mensual'},
    'payments.kpi.dueWeek': {'en': 'Due This Week', 'es': 'Vencen esta semana'},
    'payments.scheduled': {
      'en': 'Scheduled Payments',
      'es': 'Pagos programados',
    },
    'payments.due': {'en': 'Due', 'es': 'Vence'},
    'payments.today': {'en': 'Today', 'es': 'Hoy'},
    'payments.tomorrow': {'en': 'Tomorrow', 'es': 'Ma\u00F1ana'},
    'payments.overdue': {'en': 'Overdue', 'es': 'Atrasado'},
    'payments.inDays': {'en': 'in {days} days', 'es': 'en {days} d\u00EDas'},
    'payments.dueIn': {'en': 'Due in', 'es': 'Vence en'},
    'payments.pastDue': {'en': 'past due', 'es': 'atrasado'},
    'payments.account': {'en': 'Account', 'es': 'Cuenta'},
    'payments.project': {'en': 'Project', 'es': 'Proyecto'},
    'payments.nextPayment': {'en': 'Next Payment', 'es': 'Pr\u00F3ximo pago'},
    'payments.frequency': {'en': 'Frequency', 'es': 'Frecuencia'},
    'payments.amount': {'en': 'Amount', 'es': 'Monto'},
    'payments.createPlanTitle': {
      'en': 'Create payment plan',
      'es': 'Crear plan de pagos',
    },
    'payments.createPlanSubtitle': {
      'en': 'Split a total into monthly payments',
      'es': 'Divide un total en pagos mensuales',
    },
    'payments.totalAmount': {'en': 'Total amount', 'es': 'Monto total'},
    'payments.months': {'en': 'Months', 'es': 'Meses'},
    'payments.approxMonthly': {
      'en': 'Approx. monthly',
      'es': 'Aprox. mensual',
    },
    'payments.nextDate': {'en': 'Next date', 'es': 'Pr\u00F3xima fecha'},
    'payments.freq.weekly': {'en': 'Weekly', 'es': 'Semanal'},
    'payments.freq.monthly': {'en': 'Monthly', 'es': 'Mensual'},
    'payments.freq.quarterly': {'en': 'Quarterly', 'es': 'Trimestral'},
    'payments.freq.yearly': {'en': 'Yearly', 'es': 'Anual'},
    'status.active': {'en': 'active', 'es': 'activo'},
    'status.paused': {'en': 'paused', 'es': 'en pausa'},

    // Analytics
    'analytics.currentTotalBalance': {
      'en': 'Current Total Balance',
      'es': 'Saldo total actual',
    },
    'analytics.highestBalanceAccount': {
      'en': 'Highest Balance Account',
      'es': 'Cuenta con mayor saldo',
    },
    'analytics.balanceGrowth': {
      'en': 'Balance Growth',
      'es': 'Crecimiento del saldo',
    },
    'analytics.totalOverTime': {
      'en': 'Total Balance Over Time',
      'es': 'Saldo total en el tiempo',
    },
    'analytics.accountsOverTime': {
      'en': 'Account Balances Over Time',
      'es': 'Saldos por cuenta en el tiempo',
    },
    'analytics.expensesByCatCM': {
      'en': 'Expenses by Category (current month)',
      'es': 'Gastos por categor\u00EDa (mes actual)',
    },
    'analytics.incomeByCatCM': {
      'en': 'Income by Category (current month)',
      'es': 'Ingresos por categor\u00EDa (mes actual)',
    },
    'analytics.noBalanceData': {
      'en': 'No balance data',
      'es': 'Sin datos de saldo',
    },
    'analytics.noAccBalanceData': {
      'en': 'No account balance data',
      'es': 'Sin datos de saldos por cuenta',
    },
    'analytics.noExpenseData': {'en': 'No expense data', 'es': 'Sin gastos'},
    'analytics.noIncomeData': {'en': 'No income data', 'es': 'Sin ingresos'},
    'analytics.accountSummary': {
      'en': 'Account Summary',
      'es': 'Resumen de cuentas',
    },

    // Transactions / Filters
    'tx.filters': {'en': 'Filters', 'es': 'Filtros'},
    'tx.clearFilters': {'en': 'Clear Filters', 'es': 'Limpiar filtros'},
    'tx.none': {'en': 'No transactions', 'es': 'Sin transacciones'},
    'tx.reports': {'en': 'Reports', 'es': 'Reportes'},
    'tx.reportTitle': {
      'en': 'Transactions Report',
      'es': 'Reporte de transacciones',
    },
    'tx.reportPickMonth': {'en': 'Select month', 'es': 'Selecciona mes'},
    'tx.reportMonth': {'en': 'Month', 'es': 'Mes'},
    'tx.reportEmpty': {
      'en': 'No transactions for the selected month',
      'es': 'Sin transacciones para el mes seleccionado',
    },
    'tx.reportFailed': {
      'en': 'Failed to generate report',
      'es': 'Error al generar el reporte',
    },
    'tx.reportIncome': {'en': 'Income', 'es': 'Ingresos'},
    'tx.reportExpense': {'en': 'Expenses', 'es': 'Gastos'},
    'tx.reportNet': {'en': 'Net', 'es': 'Neto'},
    'tx.reportBalances': {
      'en': 'Account balances',
      'es': 'Saldos por cuenta',
    },
    'tx.reportAllTransactions': {
      'en': 'All transactions',
      'es': 'Todas las transacciones',
    },
    'tx.reportAccountTransactions': {
      'en': 'Transactions by account',
      'es': 'Transacciones por cuenta',
    },
    'tx.reportNoAccountTransactions': {
      'en': 'No transactions for this account',
      'es': 'Sin transacciones para esta cuenta',
    },
    'tx.deleteTitle': {
      'en': 'Delete transaction?',
      'es': '\u00BFEliminar transacci\u00F3n?',
    },
    'tx.type': {'en': 'Type', 'es': 'Tipo'},
    'tx.income': {'en': 'Income', 'es': 'Ingreso'},
    'tx.expense': {'en': 'Expense', 'es': 'Gasto'},
    'tx.allTypes': {'en': 'All Types', 'es': 'Todos los tipos'},
    'tx.categories': {'en': 'Categories', 'es': 'Categor\u00EDas'},
    'tx.allCategories': {
      'en': 'All Categories',
      'es': 'Todas las categor\u00EDas',
    },
    'tx.accounts': {'en': 'Accounts', 'es': 'Cuentas'},
    'tx.allAccounts': {'en': 'All Accounts', 'es': 'Todas las cuentas'},
    'tx.allProjects': {'en': 'All Projects', 'es': 'Todos los proyectos'},
    'tx.startDate': {'en': 'Start date', 'es': 'Fecha inicio'},
    'tx.endDate': {'en': 'End date', 'es': 'Fecha fin'},
    'tx.noDescription': {
      'en': '(No description)',
      'es': '(Sin descripci\u00F3n)',
    },

    // Transaction dialog
    'tx.addTitle': {
      'en': 'Add New Transaction',
      'es': 'Nueva transacci\u00F3n',
    },
    'tx.editTitle': {'en': 'Edit Transaction', 'es': 'Editar transacci\u00F3n'},
    'tx.date': {'en': 'Date', 'es': 'Fecha'},
    'tx.description': {'en': 'Description', 'es': 'Descripci\u00F3n'},
    'tx.amount': {'en': 'Amount', 'es': 'Monto'},
    'tx.category': {'en': 'Category', 'es': 'Categor\u00EDa'},
    'tx.optional': {'en': 'Optional', 'es': 'Opcional'},
    'tx.selectCategory': {
      'en': 'Select Category',
      'es': 'Selecciona categor\u00EDa',
    },
    'tx.account': {'en': 'Account', 'es': 'Cuenta'},
    'tx.projectOptional': {
      'en': 'Project (Optional)',
      'es': 'Proyecto (opcional)',
    },
    'tx.noProject': {'en': 'No Project', 'es': 'Sin proyecto'},
    'tx.validationDescAccount': {
      'en': 'Please fill description and choose account',
      'es': 'Completa la descripci\u00F3n y elige una cuenta',
    },
    'tx.saveChanges': {'en': 'Save Changes', 'es': 'Guardar cambios'},
    'tx.create': {'en': 'Create Transaction', 'es': 'Crear transacci\u00F3n'},

    // Home widgets
    'home.recentTransactions': {
      'en': 'Recent Transactions',
      'es': 'Transacciones recientes',
    },
    'home.viewAll': {'en': 'View All', 'es': 'Ver todo'},
    'home.noProjects': {
      'en': 'No projects yet',
      'es': 'A\u00FAn no hay proyectos',
    },
    'home.spent': {'en': 'Spent', 'es': 'Gastado'},

    // Accounts
    'accounts.addNew': {'en': 'Add New Account', 'es': 'Agregar cuenta nueva'},
    'accounts.edit': {'en': 'Edit Account', 'es': 'Editar cuenta'},
    'accounts.name': {'en': 'Account Name', 'es': 'Nombre de la cuenta'},
    'accounts.type': {'en': 'Account Type', 'es': 'Tipo de cuenta'},
    'accounts.type.checking': {'en': 'Checking', 'es': 'Cuenta de cheques'},
    'accounts.type.savings': {'en': 'Savings', 'es': 'Cuenta de ahorros'},
    'accounts.type.business': {'en': 'Business', 'es': 'Cuenta empresarial'},
    'accounts.type.investment': {'en': 'Investment', 'es': 'Inversión'},
    'accounts.type.credit': {'en': 'Credit', 'es': 'Crédito'},
    'accounts.initialBalance': {'en': 'Initial Balance', 'es': 'Saldo inicial'},
    'accounts.bankNameOptional': {
      'en': 'Bank Name (Optional)',
      'es': 'Banco (opcional)',
    },
    'accounts.accountNumberOptional': {
      'en': 'Account Number (last 4 digits, Optional)',
      'es': 'N\u00FAmero de cuenta (\u00FAltimos 4 d\u00EDgitos, opcional)',
    },
    'accounts.active': {'en': 'Active Account', 'es': 'Cuenta activa'},
    'accounts.details.estimatedValue': {
      'en': 'Estimated Value',
      'es': 'Valor estimado',
    },
    'accounts.details.updateSuccess': {
      'en': 'Account updated',
      'es': 'Cuenta actualizada',
    },
    'accounts.details.deleteTitle': {
      'en': 'Delete account?',
      'es': '¿Eliminar cuenta?',
    },
    'accounts.details.deleteConfirm': {
      'en': 'This will permanently remove the account.',
      'es': 'Esto eliminará la cuenta de forma permanente.',
    },
    'accounts.details.delete': {'en': 'Delete', 'es': 'Eliminar'},
    'accounts.details.deleted': {
      'en': 'Account deleted',
      'es': 'Cuenta eliminada',
    },
    'accounts.details.edit': {'en': 'Edit', 'es': 'Editar'},
    'accounts.details.quickActions': {
      'en': 'Quick actions',
      'es': 'Acciones rápidas',
    },
    'accounts.details.newTransaction': {
      'en': 'New transaction',
      'es': 'Nueva transacción',
    },
    'accounts.details.recurring': {
      'en': 'Recurring payment',
      'es': 'Pago recurrente',
    },
    'accounts.details.metrics': {'en': 'Metrics', 'es': 'Métricas'},
    'accounts.details.count30': {
      'en': 'Transactions (30d)',
      'es': 'Transacciones (30d)',
    },
    'accounts.details.inflow30': {'en': 'Inflow (30d)', 'es': 'Entradas (30d)'},
    'accounts.details.outflow30': {
      'en': 'Outflow (30d)',
      'es': 'Salidas (30d)',
    },
    'accounts.details.net30': {'en': 'Net (30d)', 'es': 'Neto (30d)'},
    'accounts.details.avgTicket': {
      'en': 'Average ticket',
      'es': 'Ticket promedio',
    },
    'accounts.details.accountInfo': {
      'en': 'Account info',
      'es': 'Información de la cuenta',
    },
    'accounts.details.bank': {'en': 'Bank', 'es': 'Banco'},
    'accounts.details.accountNumber': {
      'en': 'Account number',
      'es': 'Número de cuenta',
    },
    'accounts.details.type': {'en': 'Type', 'es': 'Tipo'},
    'accounts.details.status': {'en': 'Status', 'es': 'Estado'},
    'accounts.details.notSet': {'en': 'Not set', 'es': 'Sin definir'},
    'accounts.details.transactions': {
      'en': 'Transactions',
      'es': 'Transacciones',
    },
    'accounts.details.error': {
      'en': 'Unable to load transactions',
      'es': 'No se pudieron cargar las transacciones',
    },
    'accounts.details.retry': {'en': 'Retry', 'es': 'Reintentar'},
    'accounts.details.noTransactions': {
      'en': 'No recent transactions',
      'es': 'Sin transacciones recientes',
    },

    // Projects
    'projects.subtitle': {
      'en': 'Manage your project spending and budgets',
      'es': 'Administra el gasto y presupuesto de tus proyectos',
    },
    'projects.add': {'en': 'Add', 'es': 'Agregar'},
    'projects.none': {
      'en': 'No projects yet',
      'es': 'A\u00FAn no hay proyectos',
    },
    'projects.deleteTitle': {
      'en': 'Delete project?',
      'es': '\u00BFEliminar proyecto?',
    },
    'projects.deletePrefix': {
      'en': 'This will delete',
      'es': 'Esto eliminar\u00E1',
    },
    'projects.deleted': {'en': 'Deleted', 'es': 'Eliminado'},
    'projects.deleteFailed': {'en': 'Delete failed', 'es': 'Error al eliminar'},
    'projects.edit': {'en': 'Edit', 'es': 'Editar'},
    'projects.delete': {'en': 'Delete', 'es': 'Eliminar'},
    'projects.budget': {'en': 'Budget', 'es': 'Presupuesto'},
    'projects.progress': {'en': 'Progress', 'es': 'Progreso'},
    'projects.period': {'en': 'Period', 'es': 'Periodo'},
    'projects.to': {'en': 'to', 'es': 'a'},
    'projects.remaining': {'en': 'Remaining', 'es': 'Restante'},
    'projects.latestTransactions': {
      'en': 'Latest Transactions',
      'es': 'Transacciones recientes',
    },
    'projects.noTransactions': {
      'en': 'No transactions for this project yet',
      'es': 'A\u00FAn no hay transacciones para este proyecto',
    },
    'projects.status': {'en': 'Status', 'es': 'Estado'},
    'projects.statusActive': {'en': 'Active', 'es': 'Activo'},
    'projects.statusOnHold': {'en': 'On hold', 'es': 'En pausa'},
    'projects.startOptional': {
      'en': 'Start date (optional)',
      'es': 'Fecha de inicio (opcional)',
    },
    'projects.endOptional': {
      'en': 'End date (optional)',
      'es': 'Fecha de fin (opcional)',
    },
    'projects.refresh': {'en': 'Refresh', 'es': 'Actualizar'},

    // Auth / Signup / Login
    'auth.signInSubtitle': {
      'en': 'Sign in to manage your finances',
      'es': 'Inicia sesi\u00F3n para administrar tus finanzas',
    },
    'auth.username': {'en': 'Username', 'es': 'Usuario'},
    'auth.password': {'en': 'Password', 'es': 'Contrase\u00F1a'},
    'auth.enterUsername': {
      'en': 'Enter your username',
      'es': 'Ingresa tu usuario',
    },
    'auth.enterPassword': {
      'en': 'Enter your password',
      'es': 'Ingresa tu contrase\u00F1a',
    },
    'auth.signIn': {'en': 'Sign In', 'es': 'Iniciar sesi\u00F3n'},
    'auth.signInBiometric': {
      'en': 'Sign in with biometrics',
      'es': 'Iniciar con biometr\u00EDa',
    },
    'auth.biometricReason': {
      'en': 'Authenticate to sign in',
      'es': 'Autentica para iniciar sesi\u00F3n',
    },
    'auth.biometricNotEnrolled': {
      'en': 'No biometrics enrolled. Set one up in device settings.',
      'es': 'No hay biometria registrada. Configura una en ajustes.',
    },
    'auth.biometricUnavailable': {
      'en': 'Biometric login is unavailable on this device.',
      'es': 'El inicio biometrico no esta disponible en este dispositivo.',
    },
    'auth.biometricFailed': {
      'en': 'Biometric authentication failed',
      'es': 'Fall\u00F3 la autenticaci\u00F3n biom\u00E9trica',
    },
    'auth.signingIn': {'en': 'Signing in', 'es': 'Iniciando sesi\u00F3n'},
    'auth.invalidCredentials': {
      'en': 'Username or password is incorrect',
      'es': 'Usuario o contrase\u00F1a incorrectos',
    },
    'auth.or': {'en': 'or', 'es': 'o'},
    'auth.signupCta': {
      'en': "Don't have an account?",
      'es': '\u00BFNo tienes cuenta?',
    },
    'auth.signupFree': {
      'en': 'Sign up for free',
      'es': 'Reg\u00EDstrate gratis',
    },
    'auth.createAccount': {'en': 'Create Account', 'es': 'Crear cuenta'},
    'auth.signupSubtitle': {
      'en': 'Join us to manage your finances',
      'es': '\uFFFDsnete para administrar tus finanzas',
    },
    'auth.email': {'en': 'Email Address', 'es': 'Correo electr\u00F3nico'},
    'auth.emailPlaceholder': {
      'en': 'name@example.com',
      'es': 'correo@ejemplo.com',
    },
    'auth.validEmailRequired': {
      'en': 'Valid email required',
      'es': 'Correo v\u00E1lido requerido',
    },
    'auth.minimum6': {
      'en': 'Minimum 6 characters',
      'es': 'M\u00EDnimo 6 caracteres',
    },
    'auth.confirmPassword': {
      'en': 'Confirm Password',
      'es': 'Confirmar contrase\u00F1a',
    },
    'auth.passwordsNoMatch': {
      'en': 'Passwords do not match',
      'es': 'Las contrase\u00F1as no coinciden',
    },
    'auth.reenterPassword': {
      'en': 'Re-enter your password',
      'es': 'Reingresa tu contrase\u00F1a',
    },
    'auth.backToLogin': {
      'en': 'Back to login',
      'es': 'Volver a iniciar sesi\u00F3n',
    },
    'auth.alreadyHave': {
      'en': 'Already have an account?',
      'es': '\u00BFYa tienes una cuenta?',
    },

    // Invoices
    'invoices.add': {'en': 'Add Invoice', 'es': 'Agregar factura'},
    'invoices.addCustomer': {'en': 'Add Customer', 'es': 'Agregar cliente'},
    'invoices.searchCustomers': {
      'en': 'Search customers',
      'es': 'Buscar clientes',
    },
    'invoices.customer': {'en': 'Customer', 'es': 'Cliente'},
    'invoices.markPaid': {'en': 'Mark paid', 'es': 'Marcar pagada'},
    'invoices.paid': {'en': 'paid', 'es': 'pagada'},
    'invoices.date': {'en': 'Date', 'es': 'Fecha'},
    'invoices.due': {'en': 'Due', 'es': 'Vence'},
    'invoices.total': {'en': 'Total', 'es': 'Total'},
    'invoices.dueAmount': {'en': 'Due Amount', 'es': 'Monto pendiente'},
    'invoices.invoice': {'en': 'Invoice', 'es': 'Factura'},
    'invoices.editInvoice': {'en': 'Edit Invoice', 'es': 'Editar factura'},
    'invoices.items': {'en': 'Items', 'es': 'Conceptos'},
    'invoices.addItem': {'en': 'Add item', 'es': 'Agregar concepto'},
    'invoices.description': {'en': 'Description', 'es': 'Descripci\u00F3n'},
    'invoices.qty': {'en': 'Qty', 'es': 'Cant.'},
    'invoices.unitPrice': {'en': 'Unit Price', 'es': 'Precio unitario'},
    'invoices.amount': {'en': 'Amount', 'es': 'Monto'},
    'invoices.subtotal': {'en': 'Subtotal', 'es': 'Subtotal'},
    'invoices.discount': {'en': 'Discount', 'es': 'Descuento'},
    'invoices.tax': {'en': 'Tax', 'es': 'Impuesto'},
    'invoices.share': {'en': 'Share', 'es': 'Compartir'},
    'invoices.sentBy': {'en': 'Sent by', 'es': 'Enviada por'},
    'invoices.emailSending': {
      'en': 'Sending invoice...',
      'es': 'Enviando factura...',
    },
    'invoices.emailSent': {
      'en': 'Invoice emailed to',
      'es': 'Factura enviada a',
    },
    'invoices.emailFailed': {
      'en': 'Failed to email invoice',
      'es': 'No se pudo enviar la factura',
    },
    'invoices.customerEmailMissing': {
      'en': 'Customer email is required to share the invoice',
      'es': 'Se requiere el correo del cliente para compartir la factura',
    },

    // Investments
    'invest.add': {'en': 'Add Investment', 'es': 'Agregar inversi\u00F3n'},
    'invest.name': {'en': 'Name', 'es': 'Nombre'},
    'invest.amount': {'en': 'Amount Invested', 'es': 'Monto invertido'},
    'invest.rate': {'en': 'Annual Interest %', 'es': 'Inter\u00E9s anual %'},
    'invest.startDate': {'en': 'Start Date', 'es': 'Fecha de inicio'},
    'invest.estimatedValue': {'en': 'Estimated Value', 'es': 'Valor estimado'},
    'invest.none': {
      'en': 'No investments yet',
      'es': 'A\u00FAn no hay inversiones',
    },

    // Profile / Settings
    'profile.username': {'en': 'Username', 'es': 'Usuario'},
    'profile.email': {'en': 'Email', 'es': 'Correo'},
    'profile.changePassword': {
      'en': 'Change Password (Optional)',
      'es': 'Cambiar contrase\u00F1a (opcional)',
    },
    'profile.currentPassword': {
      'en': 'Current Password',
      'es': 'Contrase\u00F1a actual',
    },
    'profile.newPassword': {
      'en': 'New Password',
      'es': 'Nueva contrase\u00F1a',
    },
    'profile.confirmNewPassword': {
      'en': 'Confirm New Password',
      'es': 'Confirmar nueva contrase\u00F1a',
    },
    'profile.subscription': {'en': 'Subscription', 'es': 'Suscripci\u00F3n'},
    'profile.proPlanText': {
      'en': 'You are on the FinSight Pro plan.',
      'es': 'Est\u00E1s en el plan FinSight Pro.',
    },
    'profile.freePlanText': {
      'en': 'You are on the free plan.',
      'es': 'Est\u00E1s en el plan gratuito.',
    },

    // Validation / feedback
    'validation.required': {'en': 'Required', 'es': 'Requerido'},
    'error.passwordMin6': {
      'en': 'Password must be at least 6 characters',
      'es': 'La contrase\u00F1a debe tener al menos 6 caracteres',
    },
    'error.passwordsDontMatch': {
      'en': 'New passwords do not match',
      'es': 'Las nuevas contrase\u00F1as no coinciden',
    },
    'error.currentPasswordRequired': {
      'en': 'Current password is required to change password',
      'es':
          'Se requiere la contrase\u00F1a actual para cambiar la contrase\u00F1a',
    },
    'feedback.profileUpdated': {
      'en': 'Profile updated',
      'es': 'Perfil actualizado',
    },
    'error.unableOpenPlay': {
      'en': 'Unable to open Google Play',
      'es': 'No se pudo abrir Google Play',
    },
    'categories.manageTitle': {
      'en': 'Manage Categories',
      'es': 'Gestionar categorias',
    },
    'categories.selectCategoryTitle': {
      'en': 'Select a category',
      'es': 'Selecciona una categoria',
    },
    'categories.newCategory': {'en': 'New Category', 'es': 'Nueva categoria'},
    'categories.editCategory': {
      'en': 'Edit Category',
      'es': 'Editar categoria',
    },
    'categories.newSubcategory': {
      'en': 'New Subcategory',
      'es': 'Nueva subcategoria',
    },
    'categories.editSubcategory': {
      'en': 'Edit Subcategory',
      'es': 'Editar subcategoria',
    },
    'categories.deleteCategory': {
      'en': 'Delete Category',
      'es': 'Eliminar categoria',
    },
    'categories.deleteCategoryConfirm': {
      'en':
          'Delete this category? Transactions assigned to it will keep their history.',
      'es':
          '\u00BFEliminar esta categoria? Las transacciones conservaran su historial.',
    },
    'categories.deleteSubcategory': {
      'en': 'Delete Subcategory',
      'es': 'Eliminar subcategoria',
    },
    'categories.deleteSubcategoryConfirm': {
      'en':
          'Delete this subcategory? Transactions will remain but without this assignment.',
      'es':
          '\u00BFEliminar esta subcategoria? Las transacciones quedaran sin esta asignacion.',
    },
    'categories.addSubcategory': {
      'en': 'Add subcategory',
      'es': 'Agregar subcategoria',
    },
    'categories.noSubcategories': {
      'en': 'No subcategories yet',
      'es': 'Sin subcategorias',
    },
    'categories.useCategoryOnly': {
      'en': 'Just use this category',
      'es': 'Solo usar esta categoria',
    },
    'categories.empty': {
      'en': 'No categories yet. Create your first one.',
      'es': 'Sin categorias. Crea la primera.',
    },
    'categories.none': {'en': 'No category', 'es': 'Sin categoria'},
    'categories.noneSelected': {
      'en': 'Select a category to see details',
      'es': 'Selecciona una categoria para ver detalles',
    },
    'categories.selectSubcategory': {
      'en': 'Select subcategory',
      'es': 'Selecciona subcategoria',
    },
    'categories.monthlyBudget': {
      'en': 'Monthly budget',
      'es': 'Presupuesto mensual',
    },
    'categories.monthlyBudgetHint': {
      'en': 'Optional',
      'es': 'Opcional',
    },
    'categories.budgetProOnly': {
      'en': 'Monthly budgets require Pro',
      'es': 'El presupuesto mensual requiere Pro',
    },
    'categories.iconLabel': {'en': 'Icon', 'es': 'Icono'},
    'categories.validationName': {
      'en': 'Name is required',
      'es': 'El nombre es obligatorio',
    },
    'categories.validationBudget': {
      'en': 'Budget must be a number',
      'es': 'El presupuesto debe ser un numero',
    },
  };

  // Menu
  // Placed outside main map for organization but accessible via t() as well
  static const Map<String, Map<String, String>> _menu = {
    'menu.guide': {'en': 'Guide', 'es': 'Gu\u00EDa'},
    'menu.settings': {'en': 'Settings', 'es': 'Ajustes'},
    'menu.manageCategories': {
      'en': 'Manage Categories',
      'es': 'Gestionar categorias',
    },
    'menu.privacy': {'en': 'Privacy', 'es': 'Privacidad'},
    'menu.terms': {
      'en': 'Terms & Conditions',
      'es': 'T\u00E9rminos y condiciones',
    },
    'menu.logout': {'en': 'Logout', 'es': 'Cerrar sesi\u00F3n'},
  };

  static String t(BuildContext context, String key) {
    final lang = context.watch<LangStore>().lang;
    final m = _dict[key] ?? _menu[key];
    if (m == null) return key;
    return m[lang] ?? m['en'] ?? key;
  }

  // Non-listening translation for use in overlays, callbacks, etc.
  static String tr(BuildContext context, String key) {
    final lang = context.read<LangStore>().lang;
    final m = _dict[key] ?? _menu[key];
    if (m == null) return key;
    return m[lang] ?? m['en'] ?? key;
  }
}
