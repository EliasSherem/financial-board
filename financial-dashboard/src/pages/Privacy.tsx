import LegalPage from '../components/LegalPage';
import { useI18n } from '../contexts/I18nContext';

export default function Privacy() {
  const { language } = useI18n();
  const lastUpdated = new Date().toLocaleDateString(language === 'es' ? 'es-ES' : undefined, {
    year: 'numeric', month: 'long', day: 'numeric',
  });
  const L = (k: keyof typeof STR) => STR[k][language];

  return (
    <LegalPage title={L('title')} lastUpdated={lastUpdated}>
      <h2 className="text-xl font-semibold mt-8">1. {L('sec1')}</h2>
      <ul className="list-disc pl-6">
        <li>{L('sec1_li1')}</li>
        <li>{L('sec1_li2')}</li>
        <li>{L('sec1_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">2. {L('sec2')}</h2>
      <ul className="list-disc pl-6">
        <li>{L('sec2_li1')}</li>
        <li>{L('sec2_li2')}</li>
        <li>{L('sec2_li3')}</li>
        <li>{L('sec2_li4')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">3. {L('sec3')}</h2>
      <p>{L('sec3_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec3_li1')}</li>
        <li>{L('sec3_li2')}</li>
        <li>{L('sec3_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">4. {L('sec4')}</h2>
      <ul className="list-disc pl-6">
        <li>{L('sec4_li1')}</li>
        <li>{L('sec4_li2')}</li>
        <li>{L('sec4_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">5. {L('sec5')}</h2>
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
      <p>{L('sec8_p')} <a className="text-blue-600 dark:text-blue-400" href="mailto:sheremelias@gmail.com">sheremelias@gmail.com</a></p>
    </LegalPage>
  );
}

const STR = {
  title: { en: 'Privacy Policy – FinSight', es: 'Política de Privacidad – FinSight' },
  sec1: { en: 'Information We Collect', es: 'Información que recopilamos' },
  sec1_li1: { en: 'Account data: name, email, subscription details.', es: 'Datos de cuenta: nombre, correo y detalles de suscripción.' },
  sec1_li2: { en: 'Financial data you provide: account balances, transactions, budgets.', es: 'Datos financieros que proporcionas: saldos, transacciones y presupuestos.' },
  sec1_li3: { en: 'Technical data: device info, cookies, app usage analytics.', es: 'Datos técnicos: información del dispositivo, cookies y analíticas de uso.' },
  sec2: { en: 'How We Use Information', es: 'Cómo usamos la información' },
  sec2_li1: { en: 'To provide and improve the App.', es: 'Para ofrecer y mejorar la App.' },
  sec2_li2: { en: 'To process subscriptions and payments.', es: 'Para procesar suscripciones y pagos.' },
  sec2_li3: { en: 'To send service updates (never spam).', es: 'Para enviar avisos de servicio (sin spam).' },
  sec2_li4: { en: 'To ensure security and prevent fraud.', es: 'Para garantizar seguridad y prevenir fraude.' },
  sec3: { en: 'Data Sharing', es: 'Compartición de datos' },
  sec3_p: { en: 'We do not sell your data. We may share data only with:', es: 'No vendemos tus datos. Podemos compartirlos únicamente con:' },
  sec3_li1: { en: 'Payment processors (for subscription billing).', es: 'Procesadores de pago (para facturación de suscripciones).' },
  sec3_li2: { en: 'Service providers (hosting, analytics, support).', es: 'Proveedores de servicio (hosting, analíticas, soporte).' },
  sec3_li3: { en: 'Authorities if required by law.', es: 'Autoridades cuando lo exija la ley.' },
  sec4: { en: 'Data Storage & Security', es: 'Almacenamiento y seguridad' },
  sec4_li1: { en: 'Data is encrypted in transit and at rest.', es: 'Los datos se cifran en tránsito y en reposo.' },
  sec4_li2: { en: 'We follow GDPR-level best practices for data protection.', es: 'Seguimos buenas prácticas de protección de datos a nivel GDPR.' },
  sec4_li3: { en: 'You can request deletion of your data anytime.', es: 'Puedes solicitar la eliminación de tus datos en cualquier momento.' },
  sec5: { en: 'Your Rights', es: 'Tus derechos' },
  sec5_li1: { en: 'Access, correct, or delete your data.', es: 'Acceder, corregir o eliminar tus datos.' },
  sec5_li2: { en: 'Cancel your subscription at any time (Pro access ends immediately).', es: 'Cancelar tu suscripción en cualquier momento (el acceso Pro termina de inmediato).' },
  sec5_li3: { en: 'Opt-out of non-essential communications.', es: 'Darte de baja de comunicaciones no esenciales.' },
  sec6: { en: 'Children’s Privacy', es: 'Privacidad de menores' },
  sec6_p: { en: 'FinSight is not intended for users under 18.', es: 'FinSight no está destinada a menores de 18 años.' },
  sec7: { en: 'Changes to Policy', es: 'Cambios a la política' },
  sec7_p: { en: 'We may update this Privacy Policy. Significant changes will be notified to users.', es: 'Podemos actualizar esta política. Notificaremos cambios significativos a los usuarios.' },
  sec8: { en: 'Contact Us', es: 'Contáctanos' },
  sec8_p: { en: 'If you have questions, contact us at:', es: 'Si tienes preguntas, contáctanos en:' },
} as const;
