import { Link } from 'react-router-dom';
import LegalPage from '../components/LegalPage';
import { useI18n } from '../contexts/I18nContext';

export default function Terms() {
  const { language } = useI18n();
  const lastUpdated = new Date().toLocaleDateString(language === 'es' ? 'es-ES' : undefined, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
  const L = (key: keyof typeof STR) => STR[key][language];

  return (
    <LegalPage title={L('title')} lastUpdated={lastUpdated}>
          <h2 className="text-xl font-semibold mt-8">1. {L('sec1')}</h2>
          <p>{L('sec1_p')}</p>

          <h2 className="text-xl font-semibold mt-8">2. {L('sec2')}</h2>
          <p>{L('sec2_p')}</p>

          <h2 className="text-xl font-semibold mt-8">3. {L('sec3')}</h2>
          <ul className="list-disc pl-6">
            <li>{L('sec3_li1')}</li>
            <li>{L('sec3_li2')}</li>
            <li>{L('sec3_li3')}</li>
            <li>{L('sec3_li4')}</li>
          </ul>

          <h2 className="text-xl font-semibold mt-8">4. {L('sec4')}</h2>
          <ul className="list-disc pl-6">
            <li>{L('sec4_li1')}</li>
            <li>{L('sec4_li2')}</li>
            <li>{L('sec4_li3')}</li>
          </ul>

          <h2 className="text-xl font-semibold mt-8">5. {L('sec5')}</h2>
          <p>{L('sec5_p')}</p>

          <h2 className="text-xl font-semibold mt-8">6. {L('sec6')}</h2>
          <p>{L('sec6_p')}</p>

          <h2 className="text-xl font-semibold mt-8">7. {L('sec7')}</h2>
          <p>{L('sec7_p')}</p>

          <h2 className="text-xl font-semibold mt-8">8. {L('sec8')}</h2>
          <p>{L('sec8_p')}</p>

          <div className="mt-10 text-sm text-gray-600 dark:text-gray-300">
            <p>{L('contact')}</p>
            <p className="mt-2">
              {L('privacy_lead')}{' '}
              <Link to="/privacy" className="text-blue-600 hover:text-blue-700">{L('privacy_link')}</Link>.
            </p>
          </div>
    </LegalPage>
  );
}

const STR = {
  title: { en: 'Terms & Conditions – FinSight', es: 'Términos y Condiciones – FinSight' },
  sec1: { en: 'Acceptance of Terms', es: 'Aceptación de los Términos' },
  sec1_p: {
    en: 'By creating an account or using FinSight (“the App”), you agree to these Terms & Conditions. If you do not agree, you may not use the App.',
    es: 'Al crear una cuenta o usar FinSight (“la App”), aceptas estos Términos y Condiciones. Si no estás de acuerdo, no puedes usar la App.',
  },
  sec2: { en: 'Service Description', es: 'Descripción del Servicio' },
  sec2_p: {
    en: 'FinSight provides tools for tracking and managing personal finances. Some features are free; advanced features (“Pro”) require a paid subscription.',
    es: 'FinSight ofrece herramientas para registrar y administrar finanzas personales. Algunas funciones son gratuitas; las funciones avanzadas (“Pro”) requieren suscripción de pago.',
  },
  sec3: { en: 'Subscriptions & Billing', es: 'Suscripciones y Facturación' },
  sec3_li1: { en: 'Pro access is billed monthly in advance.', es: 'El plan Pro se factura mensualmente por adelantado.' },
  sec3_li2: { en: 'Payments are processed through Stripe.', es: 'Los pagos se procesan a través de Stripe.' },
  sec3_li3: { en: 'Subscriptions auto-renew unless canceled before the renewal date.', es: 'Las suscripciones se renuevan automáticamente salvo cancelación previa a la fecha de renovación.' },
  sec3_li4: { en: 'When you cancel, Pro access ends immediately. No prorated refunds are provided.', es: 'Al cancelar, el acceso Pro termina inmediatamente. No hay reembolsos prorrateados.' },
  sec4: { en: 'User Responsibilities', es: 'Responsabilidades del Usuario' },
  sec4_li1: { en: 'You are responsible for the accuracy of the data you enter.', es: 'Eres responsable de la exactitud de los datos que ingresas.' },
  sec4_li2: { en: 'You agree not to misuse the App (e.g., no hacking, scraping, or fraudulent use).', es: 'Te comprometes a no hacer un uso indebido de la App (p. ej., hackeo, scraping o uso fraudulento).' },
  sec4_li3: { en: 'FinSight is for personal finance management only, not regulated financial advice.', es: 'FinSight es para gestión de finanzas personales; no constituye asesoría financiera regulada.' },
  sec5: { en: 'Data & Security', es: 'Datos y Seguridad' },
  sec5_p: { en: 'We use encryption and security best practices to protect your data. See our Privacy Policy for details.', es: 'Usamos cifrado y buenas prácticas de seguridad para proteger tus datos. Consulta la Política de Privacidad para más detalles.' },
  sec6: { en: 'Termination', es: 'Terminación' },
  sec6_p: { en: 'We reserve the right to suspend or terminate accounts that violate these Terms.', es: 'Nos reservamos el derecho de suspender o cerrar cuentas que violen estos Términos.' },
  sec7: { en: 'Limitation of Liability', es: 'Limitación de Responsabilidad' },
  sec7_p: { en: 'FinSight provides tools “as is.” We are not responsible for losses or damages resulting from use of the App.', es: 'FinSight se ofrece “tal cual”. No somos responsables por pérdidas o daños derivados del uso de la App.' },
  sec8: { en: 'Changes to Terms', es: 'Cambios a los Términos' },
  sec8_p: { en: 'We may update these Terms from time to time. Continued use of the App means acceptance of the updated Terms.', es: 'Podemos actualizar estos Términos periódicamente. Seguir usando la App implica aceptar los Términos actualizados.' },
  contact: { en: 'Have questions? Contact support.', es: '¿Tienes preguntas? Contacta soporte.' },
  privacy_lead: { en: 'Read how we handle your data in our', es: 'Lee cómo tratamos tus datos en nuestra' },
  privacy_link: { en: 'Privacy Policy', es: 'Política de Privacidad' },
} as const;
