import LegalPage from '../components/LegalPage';
import { Link } from 'react-router-dom';
import { useI18n } from '../contexts/I18nContext';

export default function Guide() {
  const { language } = useI18n();
  const lastUpdated = new Date().toLocaleDateString(language === 'es' ? 'es-ES' : undefined, {
    year: 'numeric', month: 'long', day: 'numeric',
  });
  const L = (k: keyof typeof STR) => STR[k][language];

  return (
    <LegalPage title={L('title')} lastUpdated={lastUpdated}>
      <p className="text-sm text-slate-600 dark:text-slate-300">{L('lead')}</p>

      <h2 className="text-xl font-semibold mt-8">1) {L('s1')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s1_li1')} <Link to="/signup" className="text-blue-600 hover:text-blue-700">{L('signup')}</Link>.</li>
        <li>{L('s1_li2')}</li>
        <li>{L('s1_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">2) {L('s2')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s2_li1')}</li>
        <li>{L('s2_li2')}</li>
        <li>{L('s2_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">3) {L('s3')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s3_li1')}</li>
        <li>{L('s3_li2')}</li>
        <li>{L('s3_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">4) {L('s4')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s4_li1')}</li>
        <li>{L('s4_li2')}</li>
        <li>{L('s4_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">5) {L('s5')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s5_li1')}</li>
        <li>{L('s5_li2')}</li>
        <li>{L('s5_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">6) {L('s6')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s6_li1')}</li>
        <li>{L('s6_li2')}</li>
        <li>{L('s6_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">7) {L('s7')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s7_li1')}</li>
        <li>{L('s7_li2')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">8) {L('s8')}</h2>
      <ol className="list-decimal pl-6 space-y-1">
        <li>{L('s8_li1')}</li>
        <li>{L('s8_li2')}</li>
        <li>{L('s8_li3')}</li>
      </ol>

      <h2 className="text-xl font-semibold mt-8">{L('tips')}</h2>
      <ul className="list-disc pl-6">
        <li>{L('tips_li1')}</li>
        <li>{L('tips_li2')}</li>
        <li>{L('tips_li3')}</li>
      </ul>
    </LegalPage>
  );
}

const STR = {
  title: { en: 'User Guide – FinSight', es: 'Guía de uso – FinSight' },
  lead: { en: 'This guide walks you through every core workflow in FinSight — from your first login to advanced Pro features.', es: 'Esta guía te acompaña por los flujos clave de FinSight — desde el primer acceso hasta funciones Pro.' },
  signup: { en: 'Sign up', es: 'Registrarte' },
  s1: { en: 'First Login & Onboarding', es: 'Primer acceso y onboarding' },
  s1_li1: { en: 'Create an account on the', es: 'Crea una cuenta en la página de' },
  s1_li2: { en: 'After signup you will see a short tour. Use Next and Finish to proceed.', es: 'Tras registrarte verás un tour corto. Usa Siguiente y Finalizar para continuar.' },
  s1_li3: { en: 'On the Dashboard you will see total balance, accounts, recent transactions and events.', es: 'En el Dashboard verás saldo total, cuentas, transacciones recientes y eventos.' },
  s2: { en: 'Accounts', es: 'Cuentas' },
  s2_li1: { en: 'Go to Accounts. Click Add Account.', es: 'Ve a Cuentas. Haz clic en Agregar cuenta.' },
  s2_li2: { en: 'Enter name, type (checking/savings/credit) and starting balance; save.', es: 'Ingresa nombre, tipo (cheques/ahorros/crédito) y saldo inicial; guarda.' },
  s2_li3: { en: 'Edit balances anytime. Pro allows unlimited accounts.', es: 'Edita saldos cuando quieras. Pro permite cuentas ilimitadas.' },
  s3: { en: 'Transactions', es: 'Transacciones' },
  s3_li1: { en: 'Open Transactions and click Add.', es: 'Abre Transacciones y haz clic en Agregar.' },
  s3_li2: { en: 'Choose type (Income/Expense/Transfer), account, amount, date and category.', es: 'Elige tipo (Ingreso/Gasto/Transferencia), cuenta, monto, fecha y categoría.' },
  s3_li3: { en: 'Filter by date, account and category to analyze and export.', es: 'Filtra por fecha, cuenta y categoría para analizar y exportar.' },
  s4: { en: 'Recurring Payments', es: 'Pagos Recurrentes' },
  s4_li1: { en: 'Go to Payments. Click Add Payment.', es: 'Ve a Pagos. Haz clic en Agregar pago.' },
  s4_li2: { en: 'Choose frequency, next date and account.', es: 'Elige frecuencia, próxima fecha y cuenta.' },
  s4_li3: { en: 'Use Process Overdue to catch up and review monthly total.', es: 'Usa “Process Overdue” para ponerte al día y revisa el total mensual.' },
  s5: { en: 'Projects & Budgets (Pro)', es: 'Proyectos y Presupuestos (Pro)' },
  s5_li1: { en: 'Open Projects and click Add Project.', es: 'Abre Proyectos y haz clic en Agregar proyecto.' },
  s5_li2: { en: 'Set budget, timeframe and description. Link transactions to track Spent vs Budget.', es: 'Define presupuesto, periodo y descripción. Vincula transacciones para seguir Gastado vs Presupuesto.' },
  s5_li3: { en: 'Use progress bars and status chips to monitor performance.', es: 'Usa barras de progreso y estados para monitorear.' },
  s6: { en: 'Invoices', es: 'Facturas' },
  s6_li1: { en: 'Go to Invoices. Create customers with New Customer.', es: 'Ve a Facturas. Crea clientes con “Nuevo cliente”.' },
  s6_li2: { en: 'Click New Invoice, add items and select a customer.', es: 'Haz clic en Nueva factura, agrega ítems y selecciona un cliente.' },
  s6_li3: { en: 'Mark as Paid or record a payment to update totals.', es: 'Márcala como Pagada o registra un pago para actualizar totales.' },
  s7: { en: 'Analytics', es: 'Analítica' },
  s7_li1: { en: 'View spending by category, income by account and trends.', es: 'Consulta gasto por categoría, ingresos por cuenta y tendencias.' },
  s7_li2: { en: 'Refine with filters to find savings opportunities.', es: 'Refina con filtros para hallar oportunidades de ahorro.' },
  s8: { en: 'Upgrade to Pro & Billing', es: 'Mejorar a Pro y facturación' },
  s8_li1: { en: 'Start checkout from Upgrade to Pro or Pro banners.', es: 'Inicia el pago desde “Mejorar a Pro” o banners Pro.' },
  s8_li2: { en: 'Web pricing: MX$200 + tax/month. After payment your account becomes Pro.', es: 'Precio web: MX$200 + impuestos/mes. Tras el pago, tu cuenta pasa a Pro.' },
  s8_li3: { en: 'Manage your subscription from Payments (billing portal).', es: 'Gestiona tu suscripción desde Pagos (portal de facturación).' },
  tips: { en: 'Tips & Support', es: 'Consejos y soporte' },
  tips_li1: { en: 'Reconcile accounts by matching real statements.', es: 'Concilia cuentas ajustando al estado real.' },
  tips_li2: { en: 'Use Projects to group spend by initiative.', es: 'Usa Proyectos para agrupar gasto por iniciativa.' },
  tips_li3: { en: 'Questions? Contact support at sheremelias@gmail.com.', es: '¿Dudas? Escribe a sheremelias@gmail.com.' },
} as const;
