import type { MissionDefinition, AchievementDefinition, Localized } from './types.js';

export const CATALOG_VERSION = 1;
export const MISSIONS: readonly MissionDefinition[] = [
  {
    "key": "activation_first_account",
    "scope": "activation",
    "title": {
      "en": "Add an account",
      "es": "Añade una cuenta"
    },
    "requirement": {
      "en": "Save an active account to get started.",
      "es": "Guarda una cuenta activa para empezar."
    },
    "xp": 50,
    "metric": "accounts",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/accounts",
    "review": false,
    "priority": 45
  },
  {
    "key": "activation_first_transactions",
    "scope": "activation",
    "title": {
      "en": "Add 5 transactions",
      "es": "Añade 5 movimientos"
    },
    "requirement": {
      "en": "Record five transactions you have already made.",
      "es": "Registra cinco movimientos que ya hayas realizado."
    },
    "xp": 40,
    "metric": "transactions",
    "target": 5,
    "capability": "core",
    "pro": false,
    "deeplink": "/transactions",
    "review": false,
    "priority": 45
  },
  {
    "key": "activation_categories",
    "scope": "activation",
    "title": {
      "en": "Organize 5 transactions",
      "es": "Organiza 5 movimientos"
    },
    "requirement": {
      "en": "Choose a category for five transactions.",
      "es": "Asigna una categoría a cinco movimientos."
    },
    "xp": 40,
    "metric": "categorized",
    "target": 5,
    "capability": "core",
    "pro": false,
    "deeplink": "/categories",
    "review": false,
    "priority": 45
  },
  {
    "key": "activation_first_payment",
    "scope": "activation",
    "title": {
      "en": "Add a recurring payment",
      "es": "Añade un pago recurrente"
    },
    "requirement": {
      "en": "Save an active recurring payment you already have.",
      "es": "Guarda un pago recurrente activo que ya tengas."
    },
    "xp": 40,
    "metric": "payments",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/payments",
    "review": false,
    "priority": 45
  },
  {
    "key": "activation_first_insight",
    "scope": "activation",
    "title": {
      "en": "Explore your finances",
      "es": "Explora tus finanzas"
    },
    "requirement": {
      "en": "Check your income and expenses, then confirm your review.",
      "es": "Revisa tus ingresos y gastos, y confirma la revisión."
    },
    "xp": 30,
    "metric": "review_activation_first_insight",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "activation_weekly_review",
    "scope": "activation",
    "title": {
      "en": "Review your first week",
      "es": "Revisa tu primera semana"
    },
    "requirement": {
      "en": "Review your weekly summary and choose your next step.",
      "es": "Revisa el resumen semanal y elige tu siguiente paso."
    },
    "xp": 50,
    "metric": "weekly_reviews",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "feature_first_project",
    "scope": "feature",
    "title": {
      "en": "Create a project",
      "es": "Crea un proyecto"
    },
    "requirement": {
      "en": "Save a project you want to track.",
      "es": "Guarda un proyecto al que quieras dar seguimiento."
    },
    "xp": 40,
    "metric": "projects",
    "target": 1,
    "capability": "projects",
    "pro": true,
    "deeplink": "/projects",
    "review": false,
    "priority": 65
  },
  {
    "key": "feature_first_budget",
    "scope": "feature",
    "title": {
      "en": "Set a budget",
      "es": "Define un presupuesto"
    },
    "requirement": {
      "en": "Set a budget above zero for a subcategory.",
      "es": "Asigna un presupuesto mayor a cero a una subcategoría."
    },
    "xp": 30,
    "metric": "budgets",
    "target": 1,
    "capability": "budgets",
    "pro": true,
    "deeplink": "/categories",
    "review": false,
    "priority": 60
  },
  {
    "key": "feature_first_invoice",
    "scope": "feature",
    "title": {
      "en": "Create an invoice",
      "es": "Crea una factura"
    },
    "requirement": {
      "en": "Save an invoice for your billing activity.",
      "es": "Guarda una factura de tu actividad de facturación."
    },
    "xp": 40,
    "metric": "invoices",
    "target": 1,
    "capability": "invoices",
    "pro": true,
    "deeplink": "/invoices",
    "review": false,
    "priority": 80
  },
  {
    "key": "feature_first_invoice_payment",
    "scope": "feature",
    "title": {
      "en": "Record an invoice payment",
      "es": "Registra un cobro"
    },
    "requirement": {
      "en": "Record a payment received for one of your invoices.",
      "es": "Registra un pago recibido de una de tus facturas."
    },
    "xp": 30,
    "metric": "invoice_payments",
    "target": 1,
    "capability": "invoices",
    "pro": true,
    "deeplink": "/invoices",
    "review": false,
    "priority": 80
  },
  {
    "key": "feature_first_investment_setup",
    "scope": "feature",
    "title": {
      "en": "Add an investment",
      "es": "Añade una inversión"
    },
    "requirement": {
      "en": "Record an investment you already own.",
      "es": "Registra una inversión que ya tengas."
    },
    "xp": 30,
    "metric": "investments",
    "target": 1,
    "capability": "investments",
    "pro": true,
    "deeplink": "/investments",
    "review": false,
    "priority": 45
  },
  {
    "key": "feature_first_receipt",
    "scope": "feature",
    "title": {
      "en": "Confirm a receipt",
      "es": "Confirma un recibo"
    },
    "requirement": {
      "en": "Scan a receipt, check the details and confirm it.",
      "es": "Escanea un recibo, revisa sus datos y confírmalo."
    },
    "xp": 30,
    "metric": "receipts",
    "target": 1,
    "capability": "receipt",
    "pro": true,
    "deeplink": "/transactions",
    "review": false,
    "priority": 45
  },
  {
    "key": "feature_first_ai_question",
    "scope": "feature",
    "title": {
      "en": "Ask your assistant",
      "es": "Consulta a tu asistente"
    },
    "requirement": {
      "en": "Ask a question and receive your first answer.",
      "es": "Haz una pregunta y recibe tu primera respuesta."
    },
    "xp": 15,
    "metric": "ai_responses",
    "target": 1,
    "capability": "ai",
    "pro": false,
    "deeplink": "/ai",
    "review": false,
    "priority": 45
  },
  {
    "key": "feature_first_report",
    "scope": "feature",
    "title": {
      "en": "Export a report",
      "es": "Exporta un reporte"
    },
    "requirement": {
      "en": "Download a report of your transactions.",
      "es": "Descarga un reporte de tus movimientos."
    },
    "xp": 20,
    "metric": "reports",
    "target": 1,
    "capability": "report",
    "pro": false,
    "deeplink": "/transactions",
    "review": false,
    "priority": 45
  },
  {
    "key": "weekly_summary",
    "scope": "weekly",
    "title": {
      "en": "Review your week",
      "es": "Revisa tu semana"
    },
    "requirement": {
      "en": "Check your weekly summary and choose your next step.",
      "es": "Revisa el resumen semanal y elige tu siguiente paso."
    },
    "xp": 15,
    "metric": "weekly_reviews_period",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_categorize",
    "scope": "weekly",
    "title": {
      "en": "Organize pending transactions",
      "es": "Organiza tus movimientos"
    },
    "requirement": {
      "en": "Categorize the assigned transactions, up to five.",
      "es": "Categoriza los movimientos asignados, hasta cinco."
    },
    "xp": 20,
    "metric": "categorize_targets",
    "target": 5,
    "capability": "core",
    "pro": false,
    "deeplink": "/categories",
    "review": false,
    "priority": 90
  },
  {
    "key": "weekly_upcoming_payments",
    "scope": "weekly",
    "title": {
      "en": "Check upcoming payments",
      "es": "Revisa tus próximos pagos"
    },
    "requirement": {
      "en": "Review payments due in the next seven days and confirm.",
      "es": "Revisa los pagos de los próximos siete días y confirma."
    },
    "xp": 25,
    "metric": "review_weekly_upcoming_payments",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/payments",
    "review": true,
    "priority": 85
  },
  {
    "key": "weekly_overdue_payment",
    "scope": "weekly",
    "title": {
      "en": "Update an overdue payment",
      "es": "Actualiza un pago vencido"
    },
    "requirement": {
      "en": "Update the status of a pending overdue payment.",
      "es": "Actualiza el estado de un pago vencido pendiente."
    },
    "xp": 25,
    "metric": "overdue_resolved",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/payments",
    "review": false,
    "priority": 100
  },
  {
    "key": "weekly_recurring_review",
    "scope": "weekly",
    "title": {
      "en": "Check recurring payments",
      "es": "Revisa tus pagos recurrentes"
    },
    "requirement": {
      "en": "Review your recurring payments and confirm.",
      "es": "Revisa tus pagos recurrentes y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_recurring_review",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/payments",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_accounts_review",
    "scope": "weekly",
    "title": {
      "en": "Check your balances",
      "es": "Revisa tus saldos"
    },
    "requirement": {
      "en": "Review your active accounts and confirm.",
      "es": "Revisa tus cuentas activas y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_accounts_review",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_month_net",
    "scope": "weekly",
    "title": {
      "en": "Check your monthly balance",
      "es": "Revisa el balance del mes"
    },
    "requirement": {
      "en": "Review this month’s income, expenses and net balance, then confirm.",
      "es": "Revisa ingresos, gastos y balance del mes, y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_month_net",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_budget_review",
    "scope": "weekly",
    "title": {
      "en": "Check your budgets",
      "es": "Revisa tus presupuestos"
    },
    "requirement": {
      "en": "Compare your spending with your budgets and confirm.",
      "es": "Compara tus gastos con tus presupuestos y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_budget_review",
    "target": 1,
    "capability": "budgets",
    "pro": true,
    "deeplink": "/categories",
    "review": true,
    "priority": 60
  },
  {
    "key": "weekly_project_review",
    "scope": "weekly",
    "title": {
      "en": "Review a project",
      "es": "Revisa un proyecto"
    },
    "requirement": {
      "en": "Check an active project and confirm your review.",
      "es": "Revisa un proyecto activo y confirma."
    },
    "xp": 25,
    "metric": "review_weekly_project_review",
    "target": 1,
    "capability": "projects",
    "pro": true,
    "deeplink": "/projects",
    "review": true,
    "priority": 65
  },
  {
    "key": "weekly_project_update",
    "scope": "weekly",
    "title": {
      "en": "Update a project",
      "es": "Actualiza un proyecto"
    },
    "requirement": {
      "en": "Save a meaningful update to an active project.",
      "es": "Guarda un cambio relevante en un proyecto activo."
    },
    "xp": 25,
    "metric": "project_updates",
    "target": 1,
    "capability": "projects",
    "pro": true,
    "deeplink": "/projects",
    "review": false,
    "priority": 65
  },
  {
    "key": "weekly_invoice_review",
    "scope": "weekly",
    "title": {
      "en": "Check pending invoices",
      "es": "Revisa tus facturas pendientes"
    },
    "requirement": {
      "en": "Review open, partially paid or overdue invoices and confirm.",
      "es": "Revisa facturas abiertas, con pagos parciales o vencidas, y confirma."
    },
    "xp": 25,
    "metric": "review_weekly_invoice_review",
    "target": 1,
    "capability": "invoices",
    "pro": true,
    "deeplink": "/invoices",
    "review": true,
    "priority": 80
  },
  {
    "key": "weekly_customer_review",
    "scope": "weekly",
    "title": {
      "en": "Review customer activity",
      "es": "Revisa la actividad de clientes"
    },
    "requirement": {
      "en": "Check your customers’ invoices and confirm.",
      "es": "Revisa las facturas de tus clientes y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_customer_review",
    "target": 1,
    "capability": "invoices",
    "pro": true,
    "deeplink": "/invoices",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_investment_review",
    "scope": "weekly",
    "title": {
      "en": "Check your investments",
      "es": "Revisa tus inversiones"
    },
    "requirement": {
      "en": "Review the investments you have recorded and confirm.",
      "es": "Revisa las inversiones que tienes registradas y confirma."
    },
    "xp": 20,
    "metric": "review_weekly_investment_review",
    "target": 1,
    "capability": "investments",
    "pro": true,
    "deeplink": "/investments",
    "review": true,
    "priority": 45
  },
  {
    "key": "weekly_category_cleanup",
    "scope": "weekly",
    "title": {
      "en": "Tidy up your categories",
      "es": "Ordena tus categorías"
    },
    "requirement": {
      "en": "Categorize the assigned transactions, up to three.",
      "es": "Categoriza los movimientos asignados, hasta tres."
    },
    "xp": 20,
    "metric": "categorize_targets",
    "target": 3,
    "capability": "core",
    "pro": false,
    "deeplink": "/categories",
    "review": false,
    "priority": 45
  },
  {
    "key": "weekly_receipt_confirm",
    "scope": "weekly",
    "title": {
      "en": "Confirm a receipt",
      "es": "Confirma un recibo"
    },
    "requirement": {
      "en": "Scan and confirm a receipt this week.",
      "es": "Escanea y confirma un recibo esta semana."
    },
    "xp": 20,
    "metric": "period_receipts",
    "target": 1,
    "capability": "receipt",
    "pro": true,
    "deeplink": "/transactions",
    "review": false,
    "priority": 45
  },
  {
    "key": "weekly_ai_action",
    "scope": "weekly",
    "title": {
      "en": "Ask for a summary",
      "es": "Pide un resumen"
    },
    "requirement": {
      "en": "Ask your assistant for a summary and receive its answer this week.",
      "es": "Pide un resumen a tu asistente y recibe su respuesta esta semana."
    },
    "xp": 15,
    "metric": "period_ai_responses",
    "target": 1,
    "capability": "ai",
    "pro": false,
    "deeplink": "/ai",
    "review": false,
    "priority": 45
  },
  {
    "key": "monthly_review",
    "scope": "monthly",
    "title": {
      "en": "Review your month",
      "es": "Revisa tu mes"
    },
    "requirement": {
      "en": "Check your monthly summary and choose your next step.",
      "es": "Revisa el resumen mensual y elige tu siguiente paso."
    },
    "xp": 75,
    "metric": "monthly_reviews_period",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "monthly_uncategorized_clear",
    "scope": "monthly",
    "title": {
      "en": "Finish organizing your transactions",
      "es": "Pon tus movimientos en orden"
    },
    "requirement": {
      "en": "Categorize all your transactions and confirm a review of at least five.",
      "es": "Categoriza todos tus movimientos y confirma la revisión de al menos cinco."
    },
    "xp": 40,
    "metric": "review_monthly_uncategorized_clear",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/categories",
    "review": true,
    "priority": 90
  },
  {
    "key": "monthly_payment_check",
    "scope": "monthly",
    "title": {
      "en": "Plan next month’s payments",
      "es": "Prepara tus próximos pagos"
    },
    "requirement": {
      "en": "Review next month’s payments and confirm.",
      "es": "Revisa los pagos del próximo mes y confirma."
    },
    "xp": 40,
    "metric": "review_monthly_payment_check",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/payments",
    "review": true,
    "priority": 45
  },
  {
    "key": "monthly_budget_check",
    "scope": "monthly",
    "title": {
      "en": "Review your monthly budgets",
      "es": "Revisa tus presupuestos del mes"
    },
    "requirement": {
      "en": "Check your budgets and spending, then confirm.",
      "es": "Revisa tus presupuestos y gastos, y confirma."
    },
    "xp": 30,
    "metric": "review_monthly_budget_check",
    "target": 1,
    "capability": "budgets",
    "pro": true,
    "deeplink": "/categories",
    "review": true,
    "priority": 60
  },
  {
    "key": "monthly_project_check",
    "scope": "monthly",
    "title": {
      "en": "Check your project",
      "es": "Revisa tu proyecto"
    },
    "requirement": {
      "en": "Review an active project and confirm.",
      "es": "Revisa un proyecto activo y confirma."
    },
    "xp": 30,
    "metric": "review_monthly_project_check",
    "target": 1,
    "capability": "projects",
    "pro": true,
    "deeplink": "/projects",
    "review": true,
    "priority": 65
  },
  {
    "key": "monthly_invoice_reconcile",
    "scope": "monthly",
    "title": {
      "en": "Review your invoices",
      "es": "Revisa tus facturas"
    },
    "requirement": {
      "en": "Check the status of your invoices and confirm.",
      "es": "Revisa el estado de tus facturas y confirma."
    },
    "xp": 30,
    "metric": "review_monthly_invoice_reconcile",
    "target": 1,
    "capability": "invoices",
    "pro": true,
    "deeplink": "/invoices",
    "review": true,
    "priority": 80
  },
  {
    "key": "monthly_investment_check",
    "scope": "monthly",
    "title": {
      "en": "Review investment performance",
      "es": "Revisa cómo van tus inversiones"
    },
    "requirement": {
      "en": "Check this month’s investment performance and confirm.",
      "es": "Revisa el desempeño de tus inversiones este mes y confirma."
    },
    "xp": 25,
    "metric": "review_monthly_investment_check",
    "target": 1,
    "capability": "investments",
    "pro": true,
    "deeplink": "/investments",
    "review": true,
    "priority": 45
  },
  {
    "key": "monthly_balance_history",
    "scope": "monthly",
    "title": {
      "en": "Review your monthly balances",
      "es": "Revisa tus saldos del mes"
    },
    "requirement": {
      "en": "Check your monthly account balances and confirm.",
      "es": "Revisa los saldos de tus cuentas este mes y confirma."
    },
    "xp": 25,
    "metric": "review_monthly_balance_history",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "monthly_report",
    "scope": "monthly",
    "title": {
      "en": "Export this month’s report",
      "es": "Exporta el reporte del mes"
    },
    "requirement": {
      "en": "Download a report this month.",
      "es": "Descarga un reporte este mes."
    },
    "xp": 20,
    "metric": "period_reports",
    "target": 1,
    "capability": "report",
    "pro": false,
    "deeplink": "/transactions",
    "review": false,
    "priority": 45
  },
  {
    "key": "comeback_clarity",
    "scope": "comeback",
    "title": {
      "en": "Find your clarity again",
      "es": "Retoma tu claridad"
    },
    "requirement": {
      "en": "After two weeks away, review your accounts, transactions and upcoming payments.",
      "es": "Tras dos semanas sin actividad, revisa tus cuentas, movimientos y próximos pagos."
    },
    "xp": 50,
    "metric": "review_comeback_clarity",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": true,
    "priority": 45
  },
  {
    "key": "comeback_week",
    "scope": "comeback",
    "title": {
      "en": "Get back into your rhythm",
      "es": "Retoma tu ritmo"
    },
    "requirement": {
      "en": "Complete a weekly activity after missing a week.",
      "es": "Completa una actividad semanal después de una semana sin completarla."
    },
    "xp": 25,
    "metric": "comeback_week",
    "target": 1,
    "capability": "core",
    "pro": false,
    "deeplink": "/momentum",
    "review": false,
    "priority": 45
  }
];

export const ACHIEVEMENTS: readonly AchievementDefinition[] = [
  {
    "key": "clear_view",
    "title": {
      "en": "First Clear View",
      "es": "Primera visión clara"
    },
    "requirement": {
      "en": "Complete the six first steps.",
      "es": "Completa los seis primeros pasos."
    },
    "xp": 50,
    "metric": "activations",
    "target": 6,
    "capability": "core"
  },
  {
    "key": "account_organizer",
    "title": {
      "en": "Account Organizer",
      "es": "Organizador de cuentas"
    },
    "requirement": {
      "en": "Add your first active account.",
      "es": "Añade tu primera cuenta activa."
    },
    "xp": 0,
    "metric": "accounts",
    "target": 1,
    "capability": "core"
  },
  {
    "key": "money_mapper",
    "title": {
      "en": "Money Mapper",
      "es": "Mapa financiero"
    },
    "requirement": {
      "en": "Record five different transactions.",
      "es": "Registra cinco movimientos distintos."
    },
    "xp": 0,
    "metric": "transactions",
    "target": 5,
    "capability": "core"
  },
  {
    "key": "spending_detective_1",
    "title": {
      "en": "Spending Detective",
      "es": "Detective de gastos"
    },
    "requirement": {
      "en": "Categorize 10 different transactions.",
      "es": "Categoriza 10 movimientos distintos."
    },
    "xp": 20,
    "metric": "categorized",
    "target": 10,
    "capability": "core"
  },
  {
    "key": "spending_detective_2",
    "title": {
      "en": "Detail Finder",
      "es": "Observador de detalles"
    },
    "requirement": {
      "en": "Categorize 50 different transactions.",
      "es": "Categoriza 50 movimientos distintos."
    },
    "xp": 40,
    "metric": "categorized",
    "target": 50,
    "capability": "core"
  },
  {
    "key": "spending_detective_3",
    "title": {
      "en": "Category Expert",
      "es": "Experto en categorías"
    },
    "requirement": {
      "en": "Categorize 200 different transactions.",
      "es": "Categoriza 200 movimientos distintos."
    },
    "xp": 75,
    "metric": "categorized",
    "target": 200,
    "capability": "core"
  },
  {
    "key": "weekly_rhythm",
    "title": {
      "en": "Weekly Rhythm",
      "es": "Ritmo semanal"
    },
    "requirement": {
      "en": "Complete your first weekly review.",
      "es": "Completa tu primera revisión semanal."
    },
    "xp": 0,
    "metric": "weekly_reviews",
    "target": 1,
    "capability": "core"
  },
  {
    "key": "consistency_builder",
    "title": {
      "en": "Consistency Builder",
      "es": "Constancia"
    },
    "requirement": {
      "en": "Complete a review in four different weeks.",
      "es": "Completa una revisión en cuatro semanas distintas."
    },
    "xp": 40,
    "metric": "weekly_reviews",
    "target": 4,
    "capability": "core"
  },
  {
    "key": "momentum_keeper",
    "title": {
      "en": "Momentum Keeper",
      "es": "Momentum sostenido"
    },
    "requirement": {
      "en": "Complete a review in 12 different weeks.",
      "es": "Completa una revisión en 12 semanas distintas."
    },
    "xp": 75,
    "metric": "weekly_reviews",
    "target": 12,
    "capability": "core"
  },
  {
    "key": "half_year_clarity",
    "title": {
      "en": "Half-Year Clarity",
      "es": "Medio año de claridad"
    },
    "requirement": {
      "en": "Complete a review in 26 different weeks.",
      "es": "Completa una revisión en 26 semanas distintas."
    },
    "xp": 100,
    "metric": "weekly_reviews",
    "target": 26,
    "capability": "core"
  },
  {
    "key": "bill_guardian_1",
    "title": {
      "en": "Bill Guardian",
      "es": "Guardián de pagos"
    },
    "requirement": {
      "en": "Review your payments in three different weeks.",
      "es": "Revisa tus pagos en tres semanas distintas."
    },
    "xp": 20,
    "metric": "payment_reviews",
    "target": 3,
    "capability": "core"
  },
  {
    "key": "bill_guardian_2",
    "title": {
      "en": "Payment Planner",
      "es": "Planificador de pagos"
    },
    "requirement": {
      "en": "Review your payments in 12 different weeks.",
      "es": "Revisa tus pagos en 12 semanas distintas."
    },
    "xp": 50,
    "metric": "payment_reviews",
    "target": 12,
    "capability": "core"
  },
  {
    "key": "bill_guardian_3",
    "title": {
      "en": "Obligation Expert",
      "es": "Experto en compromisos"
    },
    "requirement": {
      "en": "Review your payments in 50 different weeks.",
      "es": "Revisa tus pagos en 50 semanas distintas."
    },
    "xp": 100,
    "metric": "payment_reviews",
    "target": 50,
    "capability": "core"
  },
  {
    "key": "subscription_sleuth",
    "title": {
      "en": "Subscription Sleuth",
      "es": "Detective de suscripciones"
    },
    "requirement": {
      "en": "Review recurring payments in five different weeks.",
      "es": "Revisa tus pagos recurrentes en cinco semanas distintas."
    },
    "xp": 30,
    "metric": "recurring_reviews",
    "target": 5,
    "capability": "core"
  },
  {
    "key": "analytics_explorer",
    "title": {
      "en": "Analytics Explorer",
      "es": "Explorador de análisis"
    },
    "requirement": {
      "en": "Confirm four different weekly or monthly summaries.",
      "es": "Confirma cuatro resúmenes semanales o mensuales distintos."
    },
    "xp": 30,
    "metric": "summary_reviews",
    "target": 4,
    "capability": "core"
  },
  {
    "key": "monthly_master_1",
    "title": {
      "en": "Monthly Reviewer",
      "es": "Revisión mensual"
    },
    "requirement": {
      "en": "Complete your first monthly review.",
      "es": "Completa tu primera revisión mensual."
    },
    "xp": 20,
    "metric": "monthly_reviews",
    "target": 1,
    "capability": "core"
  },
  {
    "key": "monthly_master_2",
    "title": {
      "en": "Quarterly Clarity",
      "es": "Claridad trimestral"
    },
    "requirement": {
      "en": "Complete a review in three different months.",
      "es": "Completa una revisión en tres meses distintos."
    },
    "xp": 50,
    "metric": "monthly_reviews",
    "target": 3,
    "capability": "core"
  },
  {
    "key": "monthly_master_3",
    "title": {
      "en": "Year in Focus",
      "es": "Un año en foco"
    },
    "requirement": {
      "en": "Complete a review in 12 different months.",
      "es": "Completa una revisión en 12 meses distintos."
    },
    "xp": 125,
    "metric": "monthly_reviews",
    "target": 12,
    "capability": "core"
  },
  {
    "key": "project_planner",
    "title": {
      "en": "Project Planner",
      "es": "Planificador de proyectos"
    },
    "requirement": {
      "en": "Create your first project.",
      "es": "Crea tu primer proyecto."
    },
    "xp": 0,
    "metric": "projects",
    "target": 1,
    "capability": "projects"
  },
  {
    "key": "goal_builder_1",
    "title": {
      "en": "Goal Builder",
      "es": "Primer avance"
    },
    "requirement": {
      "en": "Reach 25% progress on a project.",
      "es": "Alcanza el 25 % de avance en un proyecto."
    },
    "xp": 20,
    "metric": "project_progress",
    "target": 25,
    "capability": "project_milestones"
  },
  {
    "key": "goal_builder_2",
    "title": {
      "en": "Halfway There",
      "es": "A mitad de camino"
    },
    "requirement": {
      "en": "Reach 50% progress on a project.",
      "es": "Alcanza el 50 % de avance en un proyecto."
    },
    "xp": 30,
    "metric": "project_progress",
    "target": 50,
    "capability": "project_milestones"
  },
  {
    "key": "goal_builder_3",
    "title": {
      "en": "Almost Complete",
      "es": "Casi completo"
    },
    "requirement": {
      "en": "Reach 75% progress on a project.",
      "es": "Alcanza el 75 % de avance en un proyecto."
    },
    "xp": 40,
    "metric": "project_progress",
    "target": 75,
    "capability": "project_milestones"
  },
  {
    "key": "goal_builder_4",
    "title": {
      "en": "Project Complete",
      "es": "Proyecto completo"
    },
    "requirement": {
      "en": "Mark a finished project as Completed.",
      "es": "Marca un proyecto terminado como Completado."
    },
    "xp": 75,
    "metric": "completed_projects",
    "target": 1,
    "capability": "projects"
  },
  {
    "key": "invoice_ready",
    "title": {
      "en": "Invoice Ready",
      "es": "Listo para facturar"
    },
    "requirement": {
      "en": "Create your first invoice.",
      "es": "Crea tu primera factura."
    },
    "xp": 0,
    "metric": "invoices",
    "target": 1,
    "capability": "invoices"
  },
  {
    "key": "invoice_keeper",
    "title": {
      "en": "Invoice Keeper",
      "es": "Facturas al día"
    },
    "requirement": {
      "en": "Review invoices or record invoice payments in 10 different weeks.",
      "es": "Revisa facturas o registra cobros en 10 semanas distintas."
    },
    "xp": 50,
    "metric": "invoice_reviews",
    "target": 10,
    "capability": "invoices"
  },
  {
    "key": "cashflow_ready",
    "title": {
      "en": "Cash-Flow Ready",
      "es": "Flujo bajo control"
    },
    "requirement": {
      "en": "Review income and payments in four different weeks.",
      "es": "Revisa ingresos y pagos en cuatro semanas distintas."
    },
    "xp": 40,
    "metric": "cashflow_reviews",
    "target": 4,
    "capability": "core"
  },
  {
    "key": "investment_observer",
    "title": {
      "en": "Investment Observer",
      "es": "Observador de inversiones"
    },
    "requirement": {
      "en": "Review your investments in three different months.",
      "es": "Revisa tus inversiones en tres meses distintos."
    },
    "xp": 30,
    "metric": "investment_monthly_reviews",
    "target": 3,
    "capability": "investments"
  },
  {
    "key": "receipt_ready_1",
    "title": {
      "en": "Receipt Ready",
      "es": "Primer comprobante"
    },
    "requirement": {
      "en": "Confirm your first receipt.",
      "es": "Confirma tu primer recibo."
    },
    "xp": 0,
    "metric": "receipts",
    "target": 1,
    "capability": "receipt"
  },
  {
    "key": "receipt_ready_2",
    "title": {
      "en": "Receipt Organizer",
      "es": "Organizador de comprobantes"
    },
    "requirement": {
      "en": "Confirm 10 different receipts.",
      "es": "Confirma 10 recibos distintos."
    },
    "xp": 40,
    "metric": "receipts",
    "target": 10,
    "capability": "receipt"
  },
  {
    "key": "receipt_ready_3",
    "title": {
      "en": "Receipt Expert",
      "es": "Experto en comprobantes"
    },
    "requirement": {
      "en": "Confirm 50 different receipts.",
      "es": "Confirma 50 recibos distintos."
    },
    "xp": 100,
    "metric": "receipts",
    "target": 50,
    "capability": "receipt"
  },
  {
    "key": "category_curator",
    "title": {
      "en": "Category Curator",
      "es": "Curador de categorías"
    },
    "requirement": {
      "en": "Use 10 different subcategories for your transactions.",
      "es": "Usa 10 subcategorías distintas en tus movimientos."
    },
    "xp": 30,
    "metric": "used_subcategories",
    "target": 10,
    "capability": "core"
  },
  {
    "key": "report_ready",
    "title": {
      "en": "Report Ready",
      "es": "Primer reporte"
    },
    "requirement": {
      "en": "Download your first report.",
      "es": "Descarga tu primer reporte."
    },
    "xp": 0,
    "metric": "reports",
    "target": 1,
    "capability": "report"
  },
  {
    "key": "ai_explorer",
    "title": {
      "en": "AI Explorer",
      "es": "Explorador de IA"
    },
    "requirement": {
      "en": "Ask your assistant a question and receive an answer.",
      "es": "Haz una pregunta a tu asistente y recibe su respuesta."
    },
    "xp": 0,
    "metric": "ai_responses",
    "target": 1,
    "capability": "ai"
  },
  {
    "key": "comeback_strong",
    "title": {
      "en": "Comeback Strong",
      "es": "Retoma tu claridad"
    },
    "requirement": {
      "en": "Complete Find your clarity again after two weeks away.",
      "es": "Completa «Retoma tu claridad» tras dos semanas sin actividad."
    },
    "xp": 25,
    "metric": "comebacks",
    "target": 1,
    "capability": "core"
  }
];

export const LEVELS = [
  { key: 'explorer', title: { en: 'Explorer', es: 'Explorador' }, minimum_xp: 0, next_xp: 250 },
  { key: 'organizer', title: { en: 'Organizer', es: 'Organizador' }, minimum_xp: 250, next_xp: 750 },
  { key: 'planner', title: { en: 'Planner', es: 'Planificador' }, minimum_xp: 750, next_xp: 1500 },
  { key: 'strategist', title: { en: 'Strategist', es: 'Estratega' }, minimum_xp: 1500, next_xp: null },
] as const;
export function levelFor(xp: number) { return [...LEVELS].reverse().find(level => xp >= level.minimum_xp) ?? LEVELS[0]; }
export const REASONS: Record<string, Localized> = {
  unavailable: { en: 'This feature is not available yet.', es: 'Esta función aún no está disponible.' },
  project_milestones: { en: 'Project milestones are not available yet. Spending does not count as progress.', es: 'El avance por etapas aún no está disponible. Los gastos no cuentan como avance.' },
  pro_required: { en: 'This optional activity needs Pro.', es: 'Necesitas Pro para esta actividad opcional.' },
  no_data: { en: 'No data to review yet. You can skip this activity.', es: 'Aún no tienes datos para revisar. Puedes omitir esta actividad.' },
  replaced: { en: 'Another activity has replaced this one.', es: 'Hay otra actividad disponible en su lugar.' },
  no_replacement: { en: 'No replacement activity is available. Your rhythm is safe this week.', es: 'No hay otra actividad disponible. Tu ritmo se conserva esta semana.' },
};
