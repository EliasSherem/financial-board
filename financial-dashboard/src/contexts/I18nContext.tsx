import { createContext, useContext, useEffect, useMemo, useState } from 'react';

type Lang = 'en' | 'es';

type Dict = Record<string, { en: string; es: string }>;

const dict: Dict = {
  // Generic
  'common.cancel': { en: 'Cancel', es: 'Cancelar' },
  'common.update': { en: 'Update', es: 'Actualizar' },
  'common.more': { en: 'More', es: 'Más' },
  'common.pro': { en: 'Pro', es: 'Pro' },
  'common.today': { en: 'Today', es: 'Hoy' },
  'common.tomorrow': { en: 'Tomorrow', es: 'Mañana' },
  'common.inDays': { en: 'In {days} days', es: 'En {days} días' },
  'common.loading': { en: 'Loading...', es: 'Cargando...' },
  'common.failedLoad': { en: 'Failed to load data', es: 'Error al cargar datos' },
  'common.delete': { en: 'Delete', es: 'Eliminar' },
  'common.confirmDelete': { en: 'Delete this item?', es: 'Eliminar este elemento?' },

  // Navbar / Profile
  'nav.updateProfile': { en: 'Update Profile', es: 'Actualizar Perfil' },
  'nav.logout': { en: 'Logout', es: 'Cerrar sesión' },
  'nav.switchTo': { en: 'Switch to {mode} mode', es: 'Cambiar a modo {mode}' },
  'nav.mode.light': { en: 'light', es: 'claro' },
  'nav.mode.dark': { en: 'dark', es: 'oscuro' },

  // Sidebar
  'sidebar.dashboard': { en: 'Dashboard', es: 'Panel' },
  'sidebar.analytics': { en: 'Analytics', es: 'Analítica' },
  'sidebar.projects': { en: 'Projects', es: 'Proyectos' },
  'sidebar.transactions': { en: 'Transactions', es: 'Transacciones' },
  'sidebar.invoices': { en: 'Invoices', es: 'Facturas' },
  'sidebar.payments': { en: 'Payments', es: 'Pagos' },
  'sidebar.categories': { en: 'Categories', es: 'Categorias' },
  'sidebar.accounts': { en: 'Accounts', es: 'Cuentas' },
  'sidebar.investments': { en: 'Investments', es: 'Inversiones' },
  'sidebar.upgradeCta': { en: 'Upgrade to Pro', es: 'Mejorar a Pro' },
  'sidebar.upgradeNote': { en: 'Unlock analytics, projects & invoices — $10/mo', es: 'Desbloquea analítica, proyectos y facturas — $10/mes' },

  // Update Profile Modal
  'profile.title': { en: 'Update Profile', es: 'Actualizar Perfil' },
  'profile.username': { en: 'Username', es: 'Nombre de usuario' },
  'profile.email': { en: 'Email', es: 'Correo electrónico' },
  'profile.language': { en: 'Language', es: 'Idioma' },
  'profile.lang.en': { en: 'English', es: 'Inglés' },
  'profile.lang.es': { en: 'Spanish', es: 'Español' },
  'profile.changePassword': { en: 'Change Password (Optional)', es: 'Cambiar contraseña (opcional)' },
  'profile.currentPassword': { en: 'Current Password', es: 'Contraseña actual' },
  'profile.newPassword': { en: 'New Password', es: 'Nueva contraseña' },
  'profile.confirmNewPassword': { en: 'Confirm New Password', es: 'Confirmar nueva contraseña' },
  'profile.updating': { en: 'Updating...', es: 'Actualizando...' },
  'profile.successUpdated': { en: 'Profile updated successfully!', es: '¡Perfil actualizado con éxito!' },
  'profile.failedUpdate': { en: 'Failed to update profile', es: 'Error al actualizar el perfil' },
  'profile.subscription': { en: 'Subscription', es: 'Suscripcion' },
  'profile.plan.pro': { en: 'You are on the FinSight Pro plan.', es: 'Estas en el plan FinSight Pro.' },
  'profile.plan.free': { en: 'You are on the free plan.', es: 'Estas en el plan gratuito.' },
  'profile.cancelSubscription': { en: 'Cancel subscription', es: 'Cancelar suscripcion' },
  'profile.cancelConfirm': { en: 'Cancel your subscription? This will end Pro access immediately.', es: 'Cancelar tu suscripcion? Esto terminara el acceso Pro de inmediato.' },
  'profile.cancelSuccess': { en: 'Subscription cancelled. Your account is back on the free plan.', es: 'Suscripcion cancelada. Tu cuenta volvio al plan gratuito.' },
  'profile.cancelFailed': { en: 'Failed to cancel the subscription. Try again or contact support.', es: 'No se pudo cancelar la suscripcion. Intenta de nuevo o contacta soporte.' },
  'profile.cancelAlready': { en: 'Your subscription is already cancelled.', es: 'Tu suscripcion ya esta cancelada.' },
  'profile.canceling': { en: 'Cancelling...', es: 'Cancelando...' },
  'profile.err.noMatch': { en: 'New passwords do not match', es: 'Las nuevas contraseñas no coinciden' },
  'profile.err.tooShort': { en: 'Password must be at least 6 characters', es: 'La contraseña debe tener al menos 6 caracteres' },
  'profile.err.currentRequired': { en: 'Current password is required to change password', es: 'Se requiere la contraseña actual para cambiarla' },

  // Login
  'login.title': { en: 'Sign in to manage your finances', es: 'Inicia sesión para gestionar tus finanzas' },
  'login.username': { en: 'Username', es: 'Nombre de usuario' },
  'login.password': { en: 'Password', es: 'Contraseña' },
  'login.placeholder.username': { en: 'Enter your username', es: 'Ingresa tu nombre de usuario' },
  'login.placeholder.password': { en: 'Enter your password', es: 'Ingresa tu contraseña' },
  'login.signIn': { en: 'Sign In', es: 'Iniciar sesión' },
  'login.signingIn': { en: 'Signing in...', es: 'Iniciando sesión...' },
  'login.noAccount': { en: "Don't have an account?", es: '¿No tienes una cuenta?' },
  'login.signupFree': { en: 'Sign up for free', es: 'Regístrate gratis' },
  'login.err.failed': { en: 'Login failed', es: 'Error al iniciar sesión' },
  'login.err.unreachable': { en: 'Unable to connect to server', es: 'No se puede conectar al servidor' },

  // Signup
  'signup.createAccount': { en: 'Create Account', es: 'Crear cuenta' },
  'signup.subtitle': { en: 'Join us to manage your finances', es: 'Únete para gestionar tus finanzas' },
  'signup.username': { en: 'Username', es: 'Nombre de usuario' },
  'signup.email': { en: 'Email Address', es: 'Correo electrónico' },
  'signup.password': { en: 'Password', es: 'Contraseña' },
  'signup.confirmPassword': { en: 'Confirm Password', es: 'Confirmar contraseña' },
  'signup.placeholder.username': { en: 'Choose a username', es: 'Elige un nombre de usuario' },
  'signup.placeholder.email': { en: 'your@email.com', es: 'tu@email.com' },
  'signup.placeholder.password': { en: 'Minimum 6 characters', es: 'Mínimo 6 caracteres' },
  'signup.placeholder.confirm': { en: 'Re-enter your password', es: 'Reingresa tu contraseña' },
  'signup.creating': { en: 'Creating account...', es: 'Creando cuenta...' },
  'signup.signUp': { en: 'Sign Up', es: 'Registrarse' },
  'signup.alreadyHave': { en: 'Already have an account?', es: '¿Ya tienes una cuenta?' },
  'signup.backToLogin': { en: 'Back to login', es: 'Volver a iniciar sesión' },
  'signup.err.noMatch': { en: 'Passwords do not match', es: 'Las contraseñas no coinciden' },
  'signup.err.tooShort': { en: 'Password must be at least 6 characters long', es: 'La contraseña debe tener al menos 6 caracteres' },
  'signup.err.failed': { en: 'Signup failed', es: 'Error al registrarse' },
  'signup.err.unreachable': { en: 'Unable to connect to server', es: 'No se puede conectar al servidor' },

  // Dashboard
  'dashboard.title': { en: 'Dashboard', es: 'Panel' },
  'dashboard.subtitle': { en: 'Welcome to your financial overview', es: 'Bienvenido a tu resumen financiero' },
  'dashboard.totalBalance': { en: 'Total Balance', es: 'Saldo total' },
  'dashboard.totalAccounts': { en: 'Total Accounts', es: 'Cuentas totales' },
  'dashboard.thisMonthExpenses': { en: 'This Month Expenses', es: 'Gastos de este mes' },
  'dashboard.activeProjects': { en: 'Active Projects', es: 'Proyectos activos' },
  'dashboard.accountSummary': { en: 'Account Summary', es: 'Resumen de cuentas' },
  'dashboard.addAccount': { en: 'Add Account', es: 'Añadir cuenta' },
  'dashboard.more': { en: 'More', es: 'Más' },
  'dashboard.recentTransactions': { en: 'Recent Transactions', es: 'Transacciones recientes' },
  'dashboard.viewAllTransactions': { en: 'View All Transactions', es: 'Ver todas las transacciones' },
  'dashboard.upcomingEvents': { en: 'Upcoming Events', es: 'Próximos eventos' },
  'dashboard.noUpcoming': { en: 'No upcoming payments scheduled', es: 'No hay pagos próximos programados' },
  'dashboard.projectSummaries': { en: 'Project Summaries', es: 'Resumen de proyectos' },
  'dashboard.noProjects': { en: 'No projects available', es: 'No hay proyectos disponibles' },
  'dashboard.budget': { en: 'Budget', es: 'Presupuesto' },
  'dashboard.spent': { en: 'Spent', es: 'Gastado' },
  'dashboard.ofBudget': { en: 'of budget', es: 'del presupuesto' },
  'dashboard.changeFromLastMonth': { en: '{pct}% from last month', es: '{pct}% respecto al mes pasado' },

  // Accounts page
  'accounts.subtitle': { en: 'Manage your financial accounts and transfer funds', es: 'Administra tus cuentas y transfiere fondos' },
  'accounts.transferFunds': { en: 'Transfer Funds', es: 'Transferir fondos' },
  'accounts.activeAccounts': { en: 'Active Accounts', es: 'Cuentas activas' },
  'accounts.highestBalance': { en: 'Highest Balance', es: 'Saldo más alto' },
  'accounts.currentBalance': { en: 'Current Balance', es: 'Saldo actual' },

  // Transactions page
  'transactions.title': { en: 'Transactions', es: 'Transacciones' },
  'transactions.subtitle': { en: 'Track all your financial transactions', es: 'Registra todas tus transacciones financieras' },
  'transactions.add': { en: 'Add Transaction', es: 'Agregar transacción' },
  'transactions.filters': { en: 'Filters:', es: 'Filtros:' },
  'transactions.allTypes': { en: 'All Types', es: 'Todos los tipos' },
  'transactions.income': { en: 'Income', es: 'Ingreso' },
  'transactions.expense': { en: 'Expense', es: 'Gasto' },
  'transactions.allAccounts': { en: 'All Accounts', es: 'Todas las cuentas' },
  'transactions.clearFilters': { en: 'Clear Filters', es: 'Limpiar filtros' },
  'transactions.table.date': { en: 'Date', es: 'Fecha' },
  'transactions.table.description': { en: 'Description', es: 'Descripción' },
  'transactions.table.category': { en: 'Category', es: 'Categoría' },
  'transactions.table.account': { en: 'Account', es: 'Cuenta' },
  'transactions.table.project': { en: 'Project', es: 'Proyecto' },
  'transactions.table.amount': { en: 'Amount', es: 'Monto' },
  'transactions.table.actions': { en: 'Actions', es: 'Acciones' },
  'transactions.modal.edit': { en: 'Edit Transaction', es: 'Editar transacción' },
  'transactions.modal.new': { en: 'Add New Transaction', es: 'Agregar nueva transacción' },
  'transactions.form.date': { en: 'Date', es: 'Fecha' },
  'transactions.form.description': { en: 'Description', es: 'Descripción' },
  'transactions.form.type': { en: 'Type', es: 'Tipo' },
  'transactions.form.amount': { en: 'Amount', es: 'Monto' },
  'transactions.form.category': { en: 'Category', es: 'Categoría' },
  'transactions.form.account': { en: 'Account', es: 'Cuenta' },
  'transactions.form.projectOpt': { en: 'Project (Optional)', es: 'Proyecto (opcional)' },
  'transactions.form.noProject': { en: 'No Project', es: 'Sin proyecto' },
  'transactions.form.update': { en: 'Update', es: 'Actualizar' },
  'transactions.form.create': { en: 'Create', es: 'Crear' },

  // Payments page
  'payments.title': { en: 'Recurring Payments', es: 'Pagos recurrentes' },
  'payments.subtitle': { en: 'Manage your scheduled payments and subscriptions', es: 'Administra tus pagos programados y suscripciones' },
  'payments.processOverdue': { en: 'Process Overdue', es: 'Procesar vencidos' },
  'payments.add': { en: 'Add Payment', es: 'Agregar pago' },
  'payments.card.active': { en: 'Active Payments', es: 'Pagos activos' },
  'payments.card.paused': { en: 'Paused Payments', es: 'Pagos en pausa' },
  'payments.card.monthlyTotal': { en: 'Monthly Total', es: 'Total mensual' },
  'payments.card.dueThisWeek': { en: 'Due This Week', es: 'Vencen esta semana' },
  'payments.table.payment': { en: 'Payment', es: 'Pago' },
  'payments.table.amount': { en: 'Amount', es: 'Monto' },
  'payments.table.frequency': { en: 'Frequency', es: 'Frecuencia' },
  'payments.table.nextPayment': { en: 'Next Payment', es: 'Próximo pago' },
  'payments.table.account': { en: 'Account', es: 'Cuenta' },
  'payments.table.project': { en: 'Project', es: 'Proyecto' },
  'payments.table.status': { en: 'Status', es: 'Estado' },
  'payments.table.actions': { en: 'Actions', es: 'Acciones' },
  'payments.status.active': { en: 'Active', es: 'Activo' },
  'payments.status.paused': { en: 'Paused', es: 'En pausa' },
  'payments.status.overdue': { en: 'Overdue', es: 'Vencido' },
  'payments.noDate': { en: 'No date set', es: 'Sin fecha' },
  'payments.invalidDate': { en: 'Invalid date', es: 'Fecha inválida' },
  'payments.tooltip.pause': { en: 'Pause Payment', es: 'Pausar pago' },
  'payments.tooltip.activate': { en: 'Activate Payment', es: 'Activar pago' },
  'payments.noProject': { en: 'No project', es: 'Sin proyecto' },
  'payments.left': { en: 'left', es: 'restantes' },
  'payments.installmentsNote': { en: 'Monthly charge is computed automatically. The last installment adjusts for rounding.', es: 'El cargo mensual se calcula automáticamente. La última cuota se ajusta por redondeo.' },
  'payments.frequency.weekly': { en: 'Weekly', es: 'Semanal' },
  'payments.frequency.monthly': { en: 'Monthly', es: 'Mensual' },
  'payments.frequency.quarterly': { en: 'Quarterly', es: 'Trimestral' },
  'payments.frequency.yearly': { en: 'Yearly', es: 'Anual' },
  'payments.modal.edit': { en: 'Edit Payment', es: 'Editar pago' },
  'payments.modal.new': { en: 'Add New Payment', es: 'Agregar nuevo pago' },
  'payments.form.name': { en: 'Payment Name', es: 'Nombre del pago' },
  'payments.form.description': { en: 'Description', es: 'Descripción' },
  'payments.form.amount': { en: 'Amount', es: 'Monto' },
  'payments.form.frequency': { en: 'Frequency', es: 'Frecuencia' },
  'payments.form.category': { en: 'Category', es: 'Categoría' },
  'payments.form.selectCategory': { en: 'Select Category', es: 'Seleccionar categoría' },
  'payments.form.nextDate': { en: 'Next Payment Date', es: 'Fecha del próximo pago' },
  'payments.form.account': { en: 'Account', es: 'Cuenta' },
  'payments.form.projectOpt': { en: 'Project (Optional)', es: 'Proyecto (opcional)' },
  'payments.form.activePayment': { en: 'Active Payment', es: 'Pago activo' },
  'payments.form.update': { en: 'Update', es: 'Actualizar' },
  'payments.form.create': { en: 'Create', es: 'Crear' },

  // Categories page
  'categories.title': { en: 'Manage Categories', es: 'Administrar categorias' },
  'categories.subtitle': { en: 'Organize the categories and subcategories used across your finances.', es: 'Organiza las categorias y subcategorias usadas en tus finanzas.' },
  'categories.totalSummary': { en: 'Total: {categories} categories / {subcategories} subcategories', es: 'Total: {categories} categorias / {subcategories} subcategorias' },
  'categories.refresh': { en: 'Refresh', es: 'Actualizar' },
  'categories.addCategory': { en: 'New Category', es: 'Nueva categoria' },
  'categories.addSubcategory': { en: 'Add Subcategory', es: 'Agregar subcategoria' },
  'categories.editCategory': { en: 'Edit Category', es: 'Editar categoria' },
  'categories.editSubcategory': { en: 'Edit Subcategory', es: 'Editar subcategoria' },
  'categories.delete': { en: 'Delete', es: 'Eliminar' },
  'categories.deleteCategoryConfirm': { en: 'Delete this category? Its subcategories will also be removed.', es: 'Eliminar esta categoria? Sus subcategorias tambien se eliminaran.' },
  'categories.deleteSubcategoryConfirm': { en: 'Delete this subcategory?', es: 'Eliminar esta subcategoria?' },
  'categories.deleteSubcategory': { en: 'Delete subcategory', es: 'Eliminar subcategoria' },
  'categories.emptyState': { en: 'No categories yet', es: 'Aun no hay categorias' },
  'categories.emptyStateHint': { en: 'Create your first category to start tracking transactions with more context.', es: 'Crea tu primera categoria para comenzar a clasificar tus transacciones.' },
  'categories.subcategory.none': { en: 'No subcategories', es: 'Sin subcategorias' },
  'categories.subcategory.single': { en: '1 subcategory', es: '1 subcategoria' },
  'categories.subcategory.plural': { en: '{count} subcategories', es: '{count} subcategorias' },
  'categories.subcategory.noneLong': { en: 'No subcategories yet. Add one to break this category into smaller groups.', es: 'Aun no hay subcategorias. Agrega una para dividir esta categoria en grupos mas pequenos.' },
  'categories.subcategory.forCategory': { en: 'Parent category: {name}', es: 'Categoria principal: {name}' },
  'categories.modal.createCategory': { en: 'Create Category', es: 'Crear categoria' },
  'categories.modal.createSubcategory': { en: 'Create Subcategory', es: 'Crear subcategoria' },
  'categories.form.name': { en: 'Name', es: 'Nombre' },
  'categories.form.namePlaceholder': { en: 'Enter a name', es: 'Ingresa un nombre' },
  'categories.form.subcategoryPlaceholder': { en: 'Enter subcategory name', es: 'Ingresa el nombre de la subcategoria' },
  'categories.form.icon': { en: 'Icon', es: 'Icono' },
  'categories.form.save': { en: 'Save', es: 'Guardar' },
  'categories.form.saving': { en: 'Saving...', es: 'Guardando...' },
  'categories.manageLink': { en: 'Manage categories', es: 'Administrar categorias' },
  'categories.errorRequired': { en: 'Please select a category', es: 'Selecciona una categoria' },
  'categories.feedback.saved': { en: 'Changes saved', es: 'Cambios guardados' },
  'categories.feedback.deleted': { en: 'Item deleted', es: 'Elemento eliminado' },
  'categories.feedback.error': { en: 'Something went wrong. Try again.', es: 'Algo salio mal. Intenta de nuevo.' },

  // Invoices page
  'invoices.title': { en: 'Invoices', es: 'Facturas' },
  'invoices.subtitle': { en: 'Create and track invoices, and record payments', es: 'Crea y administra facturas, y registra pagos' },
  'invoices.newCustomer': { en: 'New Customer', es: 'Nuevo cliente' },
  'invoices.newInvoice': { en: 'New Invoice', es: 'Nueva factura' },
  'invoices.table.number': { en: 'Number', es: 'Número' },
  'invoices.table.customer': { en: 'Customer', es: 'Cliente' },
  'invoices.table.issue': { en: 'Issue', es: 'Emisión' },
  'invoices.table.due': { en: 'Due', es: 'Vencimiento' },
  'invoices.table.total': { en: 'Total', es: 'Total' },
  'invoices.table.amountDue': { en: 'Due', es: 'Pendiente' },
  'invoices.table.status': { en: 'Status', es: 'Estado' },
  'invoices.table.actions': { en: 'Actions', es: 'Acciones' },
  'invoices.status.draft': { en: 'Draft', es: 'Borrador' },
  'invoices.status.sent': { en: 'Sent', es: 'Enviada' },
  'invoices.status.partial': { en: 'Partial', es: 'Parcial' },
  'invoices.status.paid': { en: 'Paid', es: 'Pagada' },
  'invoices.status.void': { en: 'Void', es: 'Anulada' },

  // Projects page
  'projects.title': { en: 'Projects', es: 'Proyectos' },
  'projects.subtitle': { en: 'Manage your project spending and budgets', es: 'Administra el gasto y presupuesto de tus proyectos' },
  'projects.add': { en: 'Add Project', es: 'Agregar proyecto' },
  'projects.table.project': { en: 'Project', es: 'Proyecto' },
  'projects.table.budget': { en: 'Budget', es: 'Presupuesto' },
  'projects.table.spent': { en: 'Spent', es: 'Gastado' },
  'projects.table.status': { en: 'Status', es: 'Estado' },
  'projects.table.period': { en: 'Period', es: 'Periodo' },
  'projects.table.actions': { en: 'Actions', es: 'Acciones' },
  'projects.modal.edit': { en: 'Edit Project', es: 'Editar proyecto' },
  'projects.modal.new': { en: 'Add New Project', es: 'Agregar nuevo proyecto' },
  'projects.form.name': { en: 'Project Name', es: 'Nombre del proyecto' },
  'projects.form.description': { en: 'Description', es: 'Descripción' },
  'projects.form.budget': { en: 'Budget', es: 'Presupuesto' },
  'projects.form.spent': { en: 'Spent', es: 'Gastado' },
  'projects.form.status': { en: 'Status', es: 'Estado' },
  'projects.form.startDate': { en: 'Start Date', es: 'Fecha de inicio' },
  'projects.form.endDate': { en: 'End Date', es: 'Fecha de fin' },
  'projects.form.update': { en: 'Update', es: 'Actualizar' },
  'projects.form.create': { en: 'Create', es: 'Crear' },
  'projects.to': { en: 'to', es: 'a' },

  // Analytics page
  'analytics.title': { en: 'Analytics', es: 'Analítica' },
  'analytics.totalBalanceOverTime': { en: 'Total Balance Over Time', es: 'Saldo total a lo largo del tiempo' },
  'analytics.accountBalancesOverTime': { en: 'Account Balances Over Time', es: 'Saldos por cuenta a lo largo del tiempo' },
  'analytics.expensesByCategory': { en: 'Expenses by Category (This Month)', es: 'Gastos por categoría (este mes)' },
  'analytics.incomeByCategory': { en: 'Income by Category (This Month)', es: 'Ingresos por categoría (este mes)' },
  'analytics.noBalanceData': { en: 'No balance data available', es: 'No hay datos de saldo disponibles' },
  'analytics.noAccountBalanceData': { en: 'No account balance data available', es: 'No hay datos de saldo por cuenta disponibles' },
  'analytics.noExpenseData': { en: 'No expense data this month', es: 'No hay gastos este mes' },
  'analytics.noIncomeData': { en: 'No income data this month', es: 'No hay ingresos este mes' },
  'analytics.balance': { en: 'Balance', es: 'Saldo' },
  'analytics.month': { en: 'Month', es: 'Mes' },

  // Investments page
  'investments.title': { en: 'Investments', es: 'Inversiones' },
  'investments.totalInvested': { en: 'Total Invested', es: 'Total invertido' },
  'investments.totalContrib': { en: 'Total Contributions', es: 'Contribuciones totales' },
  'investments.totalValue': { en: 'Total Value', es: 'Valor total' },
  'investments.totalRevenue': { en: 'Total Revenue', es: 'Ganancia total' },
  'investments.start': { en: 'Start', es: 'Inicio' },
  'investments.rate': { en: 'Rate', es: 'Tasa' },
  'investments.amountInvested': { en: 'Amount Invested', es: 'Monto invertido' },
  'investments.estimatedValue': { en: 'Estimated Value', es: 'Valor estimado' },
  'investments.addTitle': { en: 'Add Investment', es: 'Agregar inversión' },
  'investments.form.name': { en: 'Name', es: 'Nombre' },
  'investments.form.amount': { en: 'Amount', es: 'Monto' },
  'investments.form.rate': { en: 'Interest Rate (%)', es: 'Tasa de interés (%)' },
  'investments.form.startDate': { en: 'Initial Date', es: 'Fecha inicial' },
  'investments.form.submit': { en: 'Create Investment', es: 'Crear inversión' },
  'investments.form.errorName': { en: 'Name is required', es: 'El nombre es obligatorio' },
  'investments.form.errorAmount': { en: 'Enter a valid amount', es: 'Ingresa un monto válido' },
  'investments.form.errorRate': { en: 'Enter a valid interest rate', es: 'Ingresa una tasa de interés válida' },
  'investments.form.errorDate': { en: 'Initial date is required', es: 'La fecha inicial es obligatoria' },
  'investments.form.errorGeneric': { en: 'Failed to create investment', es: 'No se pudo crear la inversión' },
  'investments.form.success': { en: 'Investment created successfully.', es: 'Inversión creada con éxito.' },
  'investments.empty': { en: 'No investments yet. Create your first one above.', es: 'Aún no hay inversiones. Crea la primera arriba.' },
};

type I18nContextType = {
  language: Lang;
  setLanguage: (l: Lang) => void;
  t: (key: string, vars?: Record<string, string | number>) => string;
  locale: string; // e.g., 'en-US', 'es-ES'
};

const I18nContext = createContext<I18nContextType | undefined>(undefined);

function getInitialLang(): Lang {
  try {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    return (user.language as Lang) || 'en';
  } catch {
    return 'en';
  }
}

function langToLocale(lang: Lang): string {
  return lang === 'es' ? 'es-ES' : 'en-US';
}

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = useState<Lang>(getInitialLang());

  const setLanguage = (l: Lang) => {
    setLanguageState(l);
    try {
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      localStorage.setItem('user', JSON.stringify({ ...user, language: l }));
    } catch {}
  };

  // react to storage events (in case another tab changes language)
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === 'user' && e.newValue) {
        try {
          const u = JSON.parse(e.newValue);
          if (u.language && (u.language === 'en' || u.language === 'es')) {
            setLanguageState(u.language);
          }
        } catch {}
      }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const t = (key: string, vars?: Record<string, string | number>) => {
    const entry = dict[key];
    const raw = entry ? entry[language] : key;
    if (!vars) return raw;
    return Object.entries(vars).reduce((acc, [k, v]) => acc.replace(`{${k}}`, String(v)), raw);
  };

  const value = useMemo(() => ({ language, setLanguage, t, locale: langToLocale(language) }), [language]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used within I18nProvider');
  return ctx;
}


