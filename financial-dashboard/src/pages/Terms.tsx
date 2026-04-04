import { Link } from 'react-router-dom';
import LegalPage from '../components/LegalPage';
import { useI18n } from '../contexts/I18nContext';

const LAST_UPDATED = {
  en: 'April 4, 2026',
  es: '4 de abril de 2026',
} as const;

export default function Terms() {
  const { language } = useI18n();
  const L = (key: keyof typeof STR) => STR[key][language];

  return (
    <LegalPage title={L('title')} lastUpdated={LAST_UPDATED[language]}>
      <p>{L('intro')}</p>

      <h2 className="text-xl font-semibold mt-8">1. {L('sec1')}</h2>
      <p>{L('sec1_p')}</p>

      <h2 className="text-xl font-semibold mt-8">2. {L('sec2')}</h2>
      <p>{L('sec2_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec2_li1')}</li>
        <li>{L('sec2_li2')}</li>
        <li>{L('sec2_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">3. {L('sec3')}</h2>
      <p>{L('sec3_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec3_li1')}</li>
        <li>{L('sec3_li2')}</li>
        <li>{L('sec3_li3')}</li>
        <li>{L('sec3_li4')}</li>
        <li>{L('sec3_li5')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">4. {L('sec4')}</h2>
      <ul className="list-disc pl-6">
        <li>{L('sec4_li1')}</li>
        <li>{L('sec4_li2')}</li>
        <li>{L('sec4_li3')}</li>
        <li>{L('sec4_li4')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">5. {L('sec5')}</h2>
      <p>{L('sec5_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec5_li1')}</li>
        <li>{L('sec5_li2')}</li>
        <li>{L('sec5_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">6. {L('sec6')}</h2>
      <p>{L('sec6_p')}</p>

      <h2 className="text-xl font-semibold mt-8">7. {L('sec7')}</h2>
      <p>{L('sec7_p')}</p>

      <h2 className="text-xl font-semibold mt-8">8. {L('sec8')}</h2>
      <p>{L('sec8_p')}</p>

      <h2 className="text-xl font-semibold mt-8">9. {L('sec9')}</h2>
      <p>{L('sec9_p')}</p>

      <h2 className="text-xl font-semibold mt-8">10. {L('sec10')}</h2>
      <p>{L('sec10_p')}</p>

      <div className="mt-10 text-sm text-gray-600 dark:text-gray-300">
        <p>{L('contact')}</p>
        <p className="mt-2">
          {L('privacy_lead')}{' '}
          <Link to="/privacy" className="text-blue-600 hover:text-blue-700">
            {L('privacy_link')}
          </Link>.
        </p>
      </div>
    </LegalPage>
  );
}

const STR = {
  title: { en: 'Terms & Conditions – FinSight', es: 'Términos y Condiciones – FinSight' },
  intro: {
    en: 'These Terms & Conditions govern your use of FinSight, including our website, mobile apps, and related services.',
    es: 'Estos Términos y Condiciones regulan tu uso de FinSight, incluido nuestro sitio web, aplicaciones móviles y servicios relacionados.',
  },
  sec1: { en: 'Acceptance of Terms', es: 'Aceptación de los Términos' },
  sec1_p: {
    en: 'By creating an account, purchasing a subscription, or using FinSight, you agree to these Terms & Conditions. If you do not agree, do not use FinSight.',
    es: 'Al crear una cuenta, comprar una suscripción o usar FinSight, aceptas estos Términos y Condiciones. Si no estás de acuerdo, no uses FinSight.',
  },
  sec2: { en: 'Service Description', es: 'Descripción del Servicio' },
  sec2_p: {
    en: 'FinSight provides tools for personal finance organization and related productivity workflows.',
    es: 'FinSight ofrece herramientas para organización de finanzas personales y flujos de productividad relacionados.',
  },
  sec2_li1: {
    en: 'Features may include accounts, balances, transactions, budgets, projects, payments, investments, invoices, reminders, AI-assisted responses, and other planning tools.',
    es: 'Las funciones pueden incluir cuentas, saldos, transacciones, presupuestos, proyectos, pagos, inversiones, facturas, recordatorios, respuestas asistidas por IA y otras herramientas de planificación.',
  },
  sec2_li2: {
    en: 'Some features are free and some require a paid subscription or platform purchase.',
    es: 'Algunas funciones son gratuitas y otras requieren una suscripción de pago o compra a través de una plataforma.',
  },
  sec2_li3: {
    en: 'We may change, improve, limit, suspend, or discontinue features at any time.',
    es: 'Podemos cambiar, mejorar, limitar, suspender o descontinuar funciones en cualquier momento.',
  },
  sec3: { en: 'Subscriptions, Billing, and Purchases', es: 'Suscripciones, facturación y compras' },
  sec3_p: {
    en: 'Paid features may be offered through different purchase channels depending on where you use FinSight.',
    es: 'Las funciones de pago pueden ofrecerse mediante distintos canales de compra según dónde uses FinSight.',
  },
  sec3_li1: {
    en: 'Web subscriptions may be processed through Stripe.',
    es: 'Las suscripciones web pueden procesarse a través de Stripe.',
  },
  sec3_li2: {
    en: 'Android purchases may be processed through Google Play billing.',
    es: 'Las compras en Android pueden procesarse mediante la facturación de Google Play.',
  },
  sec3_li3: {
    en: 'Subscriptions may renew automatically unless canceled through the applicable billing channel before renewal.',
    es: 'Las suscripciones pueden renovarse automáticamente salvo cancelación mediante el canal de facturación aplicable antes de la renovación.',
  },
  sec3_li4: {
    en: 'Cancellation, downgrade timing, and refund rights may depend on the store, payment processor, and applicable law.',
    es: 'La cancelación, el momento de la baja y los derechos de reembolso pueden depender de la tienda, procesador de pagos y ley aplicable.',
  },
  sec3_li5: {
    en: 'If a purchase is reversed, expires, is refunded, or cannot be verified, paid access may be limited or removed.',
    es: 'Si una compra se revierte, vence, es reembolsada o no puede verificarse, el acceso de pago puede limitarse o retirarse.',
  },
  sec4: { en: 'User Responsibilities', es: 'Responsabilidades del Usuario' },
  sec4_li1: {
    en: 'You are responsible for the accuracy and legality of the data you upload or enter into FinSight.',
    es: 'Eres responsable de la exactitud y legalidad de los datos que subes o ingresas en FinSight.',
  },
  sec4_li2: {
    en: 'If you upload customer, invoice, or third-party information, you represent that you have the right and lawful basis to do so.',
    es: 'Si subes información de clientes, facturas o terceros, declaras que tienes el derecho y la base legal para hacerlo.',
  },
  sec4_li3: {
    en: 'You must not misuse FinSight, including by attempting unauthorized access, interfering with the service, scraping, fraud, abuse, or violating applicable law.',
    es: 'No debes hacer un uso indebido de FinSight, incluyendo intentar acceso no autorizado, interferir con el servicio, hacer scraping, fraude, abuso o violar la ley aplicable.',
  },
  sec4_li4: {
    en: 'You are responsible for maintaining the confidentiality of your login credentials and the security of your devices.',
    es: 'Eres responsable de mantener la confidencialidad de tus credenciales de acceso y la seguridad de tus dispositivos.',
  },
  sec5: { en: 'AI and Informational Use', es: 'IA y uso informativo' },
  sec5_p: {
    en: 'FinSight may provide AI-assisted features. Those features are offered for convenience and informational purposes only.',
    es: 'FinSight puede ofrecer funciones asistidas por IA. Esas funciones se ofrecen solo por conveniencia y con fines informativos.',
  },
  sec5_li1: {
    en: 'FinSight is not a bank, broker, investment adviser, accountant, tax adviser, or law firm.',
    es: 'FinSight no es un banco, bróker, asesor de inversiones, contador, asesor fiscal ni despacho jurídico.',
  },
  sec5_li2: {
    en: 'AI-generated responses may be incomplete, delayed, or incorrect and should not be relied on as a substitute for professional advice.',
    es: 'Las respuestas generadas por IA pueden ser incompletas, tardías o incorrectas y no deben considerarse sustituto de asesoría profesional.',
  },
  sec5_li3: {
    en: 'You remain solely responsible for your financial, tax, accounting, legal, and business decisions.',
    es: 'Sigues siendo el único responsable de tus decisiones financieras, fiscales, contables, legales y comerciales.',
  },
  sec6: { en: 'Data, Privacy, and Security', es: 'Datos, privacidad y seguridad' },
  sec6_p: {
    en: 'Your use of FinSight is also governed by our Privacy Policy. We implement reasonable security measures, but no service can guarantee absolute security or uninterrupted availability.',
    es: 'Tu uso de FinSight también se rige por nuestra Política de Privacidad. Implementamos medidas de seguridad razonables, pero ningún servicio puede garantizar seguridad absoluta ni disponibilidad ininterrumpida.',
  },
  sec7: { en: 'Suspension and Termination', es: 'Suspensión y terminación' },
  sec7_p: {
    en: 'We may suspend, restrict, or terminate access to FinSight if we believe you violated these Terms, created risk for us or others, or used the service unlawfully. You may stop using FinSight at any time and may request account deletion through available account-deletion flows.',
    es: 'Podemos suspender, restringir o terminar el acceso a FinSight si consideramos que violaste estos Términos, generaste riesgo para nosotros o terceros, o usaste el servicio de manera ilícita. Puedes dejar de usar FinSight en cualquier momento y solicitar la eliminación de tu cuenta mediante los flujos de eliminación disponibles.',
  },
  sec8: { en: 'Disclaimers and Limitation of Liability', es: 'Descargos y limitación de responsabilidad' },
  sec8_p: {
    en: 'To the maximum extent permitted by law, FinSight is provided “as is” and “as available.” We disclaim warranties of merchantability, fitness for a particular purpose, and non-infringement. We are not liable for indirect, incidental, special, consequential, exemplary, or punitive damages, or for loss of profits, revenue, data, business opportunity, or goodwill arising from your use of FinSight.',
    es: 'En la máxima medida permitida por la ley, FinSight se proporciona “tal cual” y “según disponibilidad”. Renunciamos a garantías de comerciabilidad, idoneidad para un propósito particular y no infracción. No somos responsables por daños indirectos, incidentales, especiales, consecuenciales, ejemplares o punitivos, ni por pérdida de ganancias, ingresos, datos, oportunidades de negocio o prestigio derivados de tu uso de FinSight.',
  },
  sec9: { en: 'Changes to Terms', es: 'Cambios a los Términos' },
  sec9_p: {
    en: 'We may update these Terms from time to time. Continued use of FinSight after updated Terms become effective means you accept the revised Terms.',
    es: 'Podemos actualizar estos Términos periódicamente. El uso continuado de FinSight después de que entren en vigor los Términos actualizados significa que aceptas los Términos revisados.',
  },
  sec10: { en: 'Contact', es: 'Contacto' },
  sec10_p: {
    en: 'If you have questions about these Terms, contact support at sheremelias@gmail.com.',
    es: 'Si tienes preguntas sobre estos Términos, contacta soporte en sheremelias@gmail.com.',
  },
  contact: { en: 'Review how we handle personal data in our Privacy Policy.', es: 'Consulta cómo manejamos los datos personales en nuestra Política de Privacidad.' },
  privacy_lead: { en: 'Read our', es: 'Lee nuestra' },
  privacy_link: { en: 'Privacy Policy', es: 'Política de Privacidad' },
} as const;
