import LegalPage from '../components/LegalPage';
import { useI18n } from '../contexts/I18nContext';

const LAST_UPDATED = {
  en: 'April 4, 2026',
  es: '4 de abril de 2026',
} as const;

export default function Privacy() {
  const { language } = useI18n();
  const L = (k: keyof typeof STR) => STR[k][language];

  return (
    <LegalPage title={L('title')} lastUpdated={LAST_UPDATED[language]}>
      <p>{L('intro')}</p>

      <h2 className="text-xl font-semibold mt-8">1. {L('sec1')}</h2>
      <p>{L('sec1_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec1_li1')}</li>
        <li>{L('sec1_li2')}</li>
        <li>{L('sec1_li3')}</li>
        <li>{L('sec1_li4')}</li>
        <li>{L('sec1_li5')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">2. {L('sec2')}</h2>
      <p>{L('sec2_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec2_li1')}</li>
        <li>{L('sec2_li2')}</li>
        <li>{L('sec2_li3')}</li>
        <li>{L('sec2_li4')}</li>
        <li>{L('sec2_li5')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">3. {L('sec3')}</h2>
      <p>{L('sec3_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec3_li1')}</li>
        <li>{L('sec3_li2')}</li>
        <li>{L('sec3_li3')}</li>
        <li>{L('sec3_li4')}</li>
        <li>{L('sec3_li5')}</li>
        <li>{L('sec3_li6')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">4. {L('sec4')}</h2>
      <p>{L('sec4_p')}</p>
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
        <li>{L('sec5_li4')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">6. {L('sec6')}</h2>
      <p>{L('sec6_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec6_li1')}</li>
        <li>{L('sec6_li2')}</li>
        <li>{L('sec6_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">7. {L('sec7')}</h2>
      <p>{L('sec7_p')}</p>
      <ul className="list-disc pl-6">
        <li>{L('sec7_li1')}</li>
        <li>{L('sec7_li2')}</li>
        <li>{L('sec7_li3')}</li>
      </ul>

      <h2 className="text-xl font-semibold mt-8">8. {L('sec8')}</h2>
      <p>{L('sec8_p')}</p>

      <h2 className="text-xl font-semibold mt-8">9. {L('sec9')}</h2>
      <p>{L('sec9_p')}</p>

      <h2 className="text-xl font-semibold mt-8">10. {L('sec10')}</h2>
      <p>
        {L('sec10_p')}{' '}
        <a className="text-blue-600 dark:text-blue-400" href="mailto:sheremelias@gmail.com">
          sheremelias@gmail.com
        </a>
      </p>
    </LegalPage>
  );
}

const STR = {
  title: { en: 'Privacy Policy – FinSight', es: 'Política de Privacidad – FinSight' },
  intro: {
    en: 'This Privacy Policy explains how FinSight collects, uses, stores, and shares information when you use our website, mobile apps, and related services.',
    es: 'Esta Política de Privacidad explica cómo FinSight recopila, usa, almacena y comparte información cuando utilizas nuestro sitio web, aplicaciones móviles y servicios relacionados.',
  },
  sec1: { en: 'Information We Collect', es: 'Información que recopilamos' },
  sec1_p: {
    en: 'Depending on how you use FinSight, we may collect the following categories of information:',
    es: 'Según cómo utilices FinSight, podemos recopilar las siguientes categorías de información:',
  },
  sec1_li1: {
    en: 'Account information, such as username, email address, encrypted password credentials, subscription status, and billing-related identifiers.',
    es: 'Información de cuenta, como nombre de usuario, correo electrónico, credenciales de contraseña cifradas, estado de suscripción e identificadores relacionados con facturación.',
  },
  sec1_li2: {
    en: 'Financial and productivity information you choose to enter, such as accounts, balances, transactions, budgets, projects, payments, investments, salary rules, customers, invoices, invoice items, and notes.',
    es: 'Información financiera y de productividad que decides ingresar, como cuentas, saldos, transacciones, presupuestos, proyectos, pagos, inversiones, reglas salariales, clientes, facturas, conceptos y notas.',
  },
  sec1_li3: {
    en: 'Device and app information, such as IP-based network data, app version, platform, device notification token, timezone offset, timezone name, and basic diagnostic information.',
    es: 'Información del dispositivo y de la app, como datos de red basados en IP, versión de la app, plataforma, token de notificaciones del dispositivo, desfase horario, nombre de zona horaria e información diagnóstica básica.',
  },
  sec1_li4: {
    en: 'On-device stored information, such as login token state, biometric lock preference, locally stored chat history, and other app preferences saved on your device.',
    es: 'Información almacenada en el dispositivo, como estado del token de inicio de sesión, preferencia de bloqueo biométrico, historial de chat guardado localmente y otras preferencias de la app guardadas en tu dispositivo.',
  },
  sec1_li5: {
    en: 'Communications and support information, including welcome emails, invoice delivery details, and messages you send through the AI assistant.',
    es: 'Información de comunicaciones y soporte, incluidos correos de bienvenida, datos de envío de facturas y mensajes que envías mediante el asistente de IA.',
  },
  sec2: { en: 'How We Use Information', es: 'Cómo usamos la información' },
  sec2_p: {
    en: 'We use information to operate, maintain, and improve FinSight, including to:',
    es: 'Usamos la información para operar, mantener y mejorar FinSight, incluyendo para:',
  },
  sec2_li1: {
    en: 'Create and manage your account, authenticate you, and provide core features.',
    es: 'Crear y administrar tu cuenta, autenticarte y ofrecer funciones principales.',
  },
  sec2_li2: {
    en: 'Process subscriptions, verify purchases, manage billing access, and support account deletion or recovery requests.',
    es: 'Procesar suscripciones, verificar compras, administrar acceso de facturación y atender solicitudes de eliminación o recuperación de cuenta.',
  },
  sec2_li3: {
    en: 'Send service-related communications such as welcome emails, invoice emails, renewal-related information, and important product notices.',
    es: 'Enviar comunicaciones relacionadas con el servicio, como correos de bienvenida, correos de facturas, información relacionada con renovaciones y avisos importantes del producto.',
  },
  sec2_li4: {
    en: 'Provide reminders and push notifications that you enable, including payment and invoice reminders.',
    es: 'Ofrecer recordatorios y notificaciones push que habilites, incluidos recordatorios de pagos y facturas.',
  },
  sec2_li5: {
    en: 'Generate AI assistant responses using the conversation you submit and relevant FinSight account context needed to answer your request.',
    es: 'Generar respuestas del asistente de IA usando la conversación que envías y el contexto relevante de tu cuenta de FinSight necesario para responder tu solicitud.',
  },
  sec3: { en: 'How We Share Information', es: 'Cómo compartimos la información' },
  sec3_p: {
    en: 'We do not sell your personal information. We may share information with service providers and partners only as needed to operate FinSight, including:',
    es: 'No vendemos tu información personal. Podemos compartir información con proveedores de servicios y socios solo en la medida necesaria para operar FinSight, incluyendo:',
  },
  sec3_li1: {
    en: 'Stripe, to create customer records, process web subscriptions, manage billing portals, and sync subscription status.',
    es: 'Stripe, para crear registros de clientes, procesar suscripciones web, administrar portales de facturación y sincronizar el estado de suscripción.',
  },
  sec3_li2: {
    en: 'Google Play billing services, to verify Android purchases and subscription status when purchases are made through Google Play.',
    es: 'Servicios de facturación de Google Play, para verificar compras de Android y el estado de suscripción cuando las compras se realizan a través de Google Play.',
  },
  sec3_li3: {
    en: 'Google and Firebase services, including Google Sign-In and Firebase Cloud Messaging, to support login and push notifications.',
    es: 'Servicios de Google y Firebase, incluidos Google Sign-In y Firebase Cloud Messaging, para soportar inicio de sesión y notificaciones push.',
  },
  sec3_li4: {
    en: 'OpenAI, to generate AI assistant responses based on the messages and financial context needed to answer your request.',
    es: 'OpenAI, para generar respuestas del asistente de IA con base en los mensajes y el contexto financiero necesario para responder tu solicitud.',
  },
  sec3_li5: {
    en: 'Resend or similar email delivery providers, to send welcome emails and invoice emails with attachments to recipients you designate.',
    es: 'Resend u otros proveedores similares de entrega de correo, para enviar correos de bienvenida y facturas con archivos adjuntos a los destinatarios que designes.',
  },
  sec3_li6: {
    en: 'Courts, regulators, law enforcement, or other parties when required by law, legal process, or to protect rights, safety, and security.',
    es: 'Tribunales, reguladores, autoridades u otras partes cuando lo exija la ley, un proceso legal o para proteger derechos, seguridad y protección.',
  },
  sec4: { en: 'AI Features', es: 'Funciones de IA' },
  sec4_p: {
    en: 'If you use FinSight AI features, your messages and selected financial account context may be processed by an AI provider to generate a response.',
    es: 'Si utilizas funciones de IA de FinSight, tus mensajes y el contexto financiero seleccionado de tu cuenta pueden ser procesados por un proveedor de IA para generar una respuesta.',
  },
  sec4_li1: {
    en: 'The AI assistant is provided for informational and productivity purposes only and is not financial, tax, accounting, or legal advice.',
    es: 'El asistente de IA se ofrece solo con fines informativos y de productividad y no constituye asesoría financiera, fiscal, contable ni legal.',
  },
  sec4_li2: {
    en: 'You should avoid submitting highly sensitive information unless you are comfortable using an AI-powered feature for that request.',
    es: 'Debes evitar enviar información altamente sensible salvo que te sientas cómodo usando una función impulsada por IA para esa solicitud.',
  },
  sec4_li3: {
    en: 'AI responses may be incomplete or incorrect and should be reviewed by you before you rely on them.',
    es: 'Las respuestas de IA pueden ser incompletas o incorrectas y deben ser revisadas por ti antes de confiar en ellas.',
  },
  sec4_li4: {
    en: 'Locally stored AI chat history may remain on your device until you delete it, uninstall the app, or clear app storage.',
    es: 'El historial del chat de IA almacenado localmente puede permanecer en tu dispositivo hasta que lo elimines, desinstales la app o borres el almacenamiento de la app.',
  },
  sec5: { en: 'Notifications, Biometrics, and Device Features', es: 'Notificaciones, biometría y funciones del dispositivo' },
  sec5_p: {
    en: 'FinSight may use optional device features to improve your experience.',
    es: 'FinSight puede usar funciones opcionales del dispositivo para mejorar tu experiencia.',
  },
  sec5_li1: {
    en: 'If you enable notifications, we may collect and store your push token, platform, and timezone details in order to deliver reminders and alerts.',
    es: 'Si habilitas notificaciones, podemos recopilar y almacenar tu token push, plataforma y datos de zona horaria para enviar recordatorios y alertas.',
  },
  sec5_li2: {
    en: 'If you enable biometric login or unlock, biometric authentication is handled by your device operating system. FinSight does not receive or store your raw fingerprint or face template.',
    es: 'Si habilitas inicio de sesión o desbloqueo biométrico, la autenticación biométrica es gestionada por el sistema operativo de tu dispositivo. FinSight no recibe ni almacena tu huella o plantilla facial sin procesar.',
  },
  sec5_li3: {
    en: 'Some account and preference data may be stored locally on your device to keep you signed in, preserve app settings, and support lock-screen behavior.',
    es: 'Algunos datos de cuenta y preferencias pueden almacenarse localmente en tu dispositivo para mantener tu sesión iniciada, conservar ajustes de la app y soportar el comportamiento de bloqueo.',
  },
  sec5_li4: {
    en: 'You can disable notifications or biometrics in your device settings or inside the app where those controls are available.',
    es: 'Puedes desactivar notificaciones o biometría en la configuración de tu dispositivo o dentro de la app cuando esos controles estén disponibles.',
  },
  sec6: { en: 'Data Retention and Deletion', es: 'Conservación y eliminación de datos' },
  sec6_p: {
    en: 'We keep information for as long as reasonably necessary to provide the service, comply with legal obligations, resolve disputes, and enforce our agreements.',
    es: 'Conservamos la información durante el tiempo razonablemente necesario para prestar el servicio, cumplir obligaciones legales, resolver disputas y hacer cumplir nuestros acuerdos.',
  },
  sec6_li1: {
    en: 'You may request deletion of your FinSight account. Deleting your account is intended to remove your associated in-app records from our active systems, subject to legal, billing, fraud-prevention, backup, and technical constraints.',
    es: 'Puedes solicitar la eliminación de tu cuenta de FinSight. La eliminación de tu cuenta tiene por objeto borrar tus registros asociados dentro de la app de nuestros sistemas activos, sujeto a restricciones legales, de facturación, prevención de fraude, respaldo y técnicas.',
  },
  sec6_li2: {
    en: 'Some information may persist temporarily in backups, logs, app stores, payment systems, email systems, or records needed to complete or document transactions.',
    es: 'Parte de la información puede persistir temporalmente en respaldos, registros, tiendas de aplicaciones, sistemas de pago, sistemas de correo o registros necesarios para completar o documentar transacciones.',
  },
  sec6_li3: {
    en: 'Information stored locally on your device, such as app preferences or local AI chat history, may remain until you remove it from the device.',
    es: 'La información almacenada localmente en tu dispositivo, como preferencias de la app o historial local de chat de IA, puede permanecer hasta que la elimines del dispositivo.',
  },
  sec7: { en: 'Security', es: 'Seguridad' },
  sec7_p: {
    en: 'We use reasonable administrative, technical, and organizational measures designed to protect information. However, no method of transmission, storage, or security control is guaranteed to be completely secure.',
    es: 'Utilizamos medidas administrativas, técnicas y organizativas razonables diseñadas para proteger la información. Sin embargo, ningún método de transmisión, almacenamiento o control de seguridad garantiza seguridad absoluta.',
  },
  sec7_li1: {
    en: 'We use password hashing, authenticated access controls, and HTTPS/TLS transport where supported by our services.',
    es: 'Usamos hash de contraseñas, controles de acceso autenticado y transporte HTTPS/TLS cuando nuestros servicios lo soportan.',
  },
  sec7_li2: {
    en: 'You are responsible for maintaining the confidentiality of your credentials and for securing access to your own devices and email accounts.',
    es: 'Eres responsable de mantener la confidencialidad de tus credenciales y de asegurar el acceso a tus propios dispositivos y cuentas de correo.',
  },
  sec7_li3: {
    en: 'If you believe your account or data has been compromised, contact us promptly.',
    es: 'Si crees que tu cuenta o datos han sido comprometidos, contáctanos de inmediato.',
  },
  sec8: { en: 'Your Rights and Choices', es: 'Tus derechos y opciones' },
  sec8_p: {
    en: 'Subject to applicable law, you may have rights to access, correct, export, or delete certain information, and to opt out of non-essential communications.',
    es: 'Sujeto a la ley aplicable, puedes tener derechos para acceder, corregir, exportar o eliminar cierta información, y para darte de baja de comunicaciones no esenciales.',
  },
  sec9: { en: 'Children’s Privacy', es: 'Privacidad de menores' },
  sec9_p: {
    en: 'FinSight is not directed to children under 18, and we do not knowingly collect personal information from children under 18.',
    es: 'FinSight no está dirigida a menores de 18 años y no recopilamos conscientemente información personal de menores de 18 años.',
  },
  sec10: { en: 'Changes and Contact', es: 'Cambios y contacto' },
  sec10_p: {
    en: 'We may update this Privacy Policy from time to time. If you have questions or requests about this Privacy Policy, contact us at',
    es: 'Podemos actualizar esta Política de Privacidad periódicamente. Si tienes preguntas o solicitudes sobre esta Política de Privacidad, contáctanos en',
  },
} as const;
