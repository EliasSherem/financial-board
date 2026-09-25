# Prompt maestro — FinSight Momentum, Google Play Billing y Admin

Implementa este trabajo en el repositorio real de FinSight. No te limites a entregar otro plan: inspecciona, modifica, prueba y documenta el código. Trabaja por fases, con cambios revisables y un registro persistente de avance. No publiques en tiendas ni ejecutes migraciones en producción como parte de este prompt. Puedes completar código, migraciones, pruebas, builds y documentación local sin detenerte a pedir confirmación por decisiones rutinarias.

## 0. Contexto y autoridad

El plan de referencia es `FinSight_Momentum_Implementation_Plan(1).md`, adjunto por el propietario. Describe `EliasSherem/financial-board`, rama `master`, commit de referencia `19c5651fc322cfacac5645ec92b618dbb92cc08e`, Flutter móvil, React web, Express API y MySQL. Es una referencia histórica, no evidencia de que el checkout actual sea idéntico. Lee AGENTS.md, el repositorio, lockfiles, schema, autenticación, suscripciones y componentes Liquid Glass antes de elegir implementaciones. No migres la arquitectura a otro stack.

Este paquete contiene `assets/manifest.json`, 168 SVG, `PREVIEW.html`, `MOMENTUM_CATALOG.md` y `ASSET_GUIDE.md`. Integra los gráficos entregados, no los sustituyas por emojis, placeholders o una imagen de toda la galería. Usa los catálogos de este paquete y el plan adjunto; las decisiones explícitas siguientes resuelven ambigüedades. Si el plan original no está presente, el catálogo del paquete y este prompt permiten ejecutar el alcance; documenta esa ausencia.

Objetivos completos:
1. Momentum funcional en Android, iOS y web: misiones, XP, cuatro niveles, 34 insignias, revisión semanal/mensual, retorno, créditos IA y notificaciones cuando la capacidad exista.
2. Actualización e integración correcta de Google Play Billing, preservando suscriptores existentes y compras Apple/Stripe.
3. Admin web privado para el propietario, con métricas reales de uso, Momentum y suscripciones, distinguiendo plataforma utilizada de proveedor de pago.

No dar por implementadas capacidades solamente mencionadas en documentación. Si recibos, IA o exports no existen, las misiones asociadas permanecen inhabilitadas por capacidad, con motivo documentado. No construyas un producto IA nuevo para satisfacer una misión opcional.

## 1. Auditoría inicial breve y ejecución

Identifica integración de pagos actual (plugin Flutter, wrapper, SDK directo o proveedor intermediario), SKU/product IDs, backend, webhooks, RBAC, telemetría, notificaciones, timezone, rutas y tests. No imprimas secretos. Documenta versiones resueltas, limitaciones de acceso y diferencias contra la referencia. Conserva cambios preexistentes del usuario. Continúa con la implementación; solamente bloquea la parte que dependa de un dato externo imprescindible.

Entrega `docs/implementation/finsight-platform-upgrade.md` con checklist, decisiones, comandos y resultados comprobados, instrucciones de rollout/rollback y tareas externas exactas. No declares pruebas de dispositivo, Play Console o producción que no hayas podido ejecutar.

## 2. Reglas definitivas de Momentum

- Servidor como autoridad de elegibilidad, asignación, progreso, XP y créditos. Flutter y React muestran el mismo estado.
- No XP por abrir app, login diario, aumentar gasto/inversión ni crear transacciones repetitivamente. Las misiones de activación reconocen una configuración finita, no volumen ilimitado.
- Niveles por XP vitalicio: Explorer 0–249; Organizer 250–749; Planner 750–1499; Strategist 1500+. ES: Explorador, Organizador, Planificador, Estratega. Nunca resetear niveles.
- Seis activaciones suman 250 XP. `clear_view` da un bono separado explícito de 50 XP al terminar las seis: total 300 XP si se concede esa insignia, sin afirmar que el total con bono sea 250. Insignias marcadas 0 no duplican la recompensa de misión.
- Semana ISO local persistida por usuario. Tres misiones requeridas: revisión, mantenimiento y objetivo relevante; una misión opcional de descubrimiento puede aparecer aparte.
- Máximo 100 XP por misiones semanales repetibles incluyendo opcionales repetibles, más 20 XP por terminar las tres requeridas: máximo semanal 120. Los límites se aplican atómicamente bajo concurrencia.
- Misiones mensuales: límite compartido de 75 XP al mes para todas las misiones mensuales repetibles. Las secundarias avanzan y se reconocen; conceden sólo el saldo disponible del límite. La UI explica XP nominal y XP realmente concedido. Insignias de una sola vez quedan fuera de ese límite.
- Misiones comeback: `comeback_clarity` después de 14 días sin actividad significativa, una vez por episodio; `comeback_week` tras una semana perdida, una vez por semana. Sus XP repetibles consumen el presupuesto semanal de 100. La insignia `comeback_strong` es una sola vez y aparte. No farmear cambiando fechas, clientes o editando registros.
- Grace week: decisión de implementación propuesta para concretar el plan: una semana de gracia en cada ventana móvil de ocho semanas; preserva el ritmo mostrado, no entrega XP ni cuenta como revisión completada. Se aplica como máximo una vez por período perdido, nunca diariamente. Hacerlo configurable en servidor y visible en tests/documentación.
- Activación muestra como máximo tres pasos accionables a la vez de los seis. Los tres requeridos semanales sólo se asignan cuando existe suficiente información y acciones elegibles. Antes de eso mostrar activación, no inventar tres tareas imposibles.
- Tras asignar un set, persistirlo: no reshuffle al abrir otra plataforma. Si pierde elegibilidad (datos eliminados, Pro vencido), sustituir solamente la misión imposible por una equivalente alcanzable, con historial y sin volver a premiar tareas terminadas. Si no existe sustitución, comunicar el estado y no penalizar al usuario.
- No obligar a crear pagos, facturas, inversiones o proyectos irrelevantes para completar una semana. Las misiones Pro nunca bloquean usuarios Free.
- Revisiones: datos renderizados y confirmación explícita, más elegibilidad revalidada por servidor; screen_view por sí solo no completa una misión. Revisión semanal: cuentas, actividad reciente, obligaciones si existen y un siguiente paso. Mensual: cuentas, neto, categorías, obligaciones y siguiente paso. Secciones sin datos pueden ser no aplicables; no marcar revisiones históricas ficticias.
- Generar objetivos de categorización con los registros elegibles existentes; deduplicar por identidad canónica. No sumar por categorizar/descategorizar el mismo registro. Proyectos: hitos por progreso real del modelo actual, no dinero aportado ni un contador libre enviado por cliente.
- Zona IANA preferida y offset sólo fallback. Fijar zona y límites temporales del período al asignarlo. Un cambio de zona no permite repetir premios. UTC para almacenamiento, zona explícita para presentación.

## 3. Backend Momentum

Usar catálogo versionado para todas las claves, criterios, XP, traducciones, capacidad y deeplink. Módulo separado, adaptado al repositorio: `server/momentum/{catalog,types,repository,events,engine,missionGenerator,serializers}`.

Migraciones aditivas y verificables, índices y unicidad:
- engagement_events: outbox de eventos de dominio, user, source, clave idempotente, fechas, estado, reintentos y error sanitizado.
- user_missions: misión, versión de catálogo, período, target/progreso, status y fechas; unique(user,mission,period).
- user_achievement_progress: unique(user,achievement), contadores, completed_at, seen_at.
- reward_ledger: inmutable, XP concedido, origen, período, clave idempotente única. Correcciones mediante entradas compensatorias auditadas, no edits silenciosos.
- weekly_reviews y monthly_reviews: período único por usuario, evidencia de checklist y zona fijada.
- user_momentum: cache de XP reconstruible desde ledger, ritmo y grace.
- ai_credit_ledger y reservas de consumo: saldo/expiración y claves idempotentes.

Outbox y límites: un fallo del evaluador después del commit financiero no revierte ni bloquea la operación. Insertar evento de dominio en la misma transacción financiera y procesarlo después; no confundir esto con prometer que un fallo de escritura de la transacción base no puede causar rollback. Si la escritura de outbox falla, la transacción no debe producir una mutación parcial: devolver el error normal y permitir reintento idempotente. Usar mecanismo de recuperación para rutas heredadas que no puedan integrarse atómicamente. Evitar llamadas de red o evaluación costosa dentro de la transacción. Consumidor reentrante, reintentos con backoff, eventos fallidos visibles y reconciliación. Lock de usuario/período o estrategia equivalente para caps concurrentes.

Emitir eventos desde acciones reales existentes: cuentas, transacciones, categorías, pagos, proyectos, facturas, inversiones, presupuesto, recibo confirmado, respuesta IA completada y exportación terminada. ACK del cliente limitado a allowlist; nunca aceptar XP, user_id arbitrario o event_type privilegiado. Ownership y rate limits obligatorios. XP sólo después del éxito financiero real.

API autenticada `/api/engagement`: GET `/me`, `/missions/current`, `/achievements`; POST `/client-events`, `/achievements/:key/seen`, `/weekly-review`, `/monthly-review`. Reutiliza auth y errores actuales, valida payloads. Mantén contratos financieros existentes; refresh Momentum tras mutación si un envelope nuevo rompe clientes antiguos.

Backfill idempotente desde datos reales: configuración y logros verificables; no inventar reviews, sesiones ni rachas. Un único resumen de progreso histórico. Borrado de cuenta y retención deben respetar el mecanismo real de eliminación, sin conservar PII en ledgers supuestamente inmutables.

## 4. UX Flutter y React

Home: tarjeta compacta después del resumen financiero, nivel, XP, progreso 0/3, siguiente misión y CTA. Sheet/panel de misiones con motivo, progreso, XP y deeplink. Semana completa colapsa a confirmación con bono real concedido. Perfil: Logros y XP con 34 insignias, estado, requisitos visibles, filtros y progreso. No mostrar capacidades no disponibles como promesas activas.

Usar tokens actuales Liquid Glass, azul #2563EB, mint #22B66F, lavender #7C83FD y amber #F59E0B. Gráficos 64px galería, 40px listas, 24px chips; a 24px preferir marca simple y evitar detalle ilegible. Light/dark, ES/EN completos, lector de pantalla, texto grande, contraste y navegación teclado web. Nunca distinguir status sólo por color.

Integrar todos los SVG por key desde manifest. Web img con alt contextual o aria-hidden si ya está etiquetado; Flutter renderer SVG compatible verificado en el repo. Progress bars, anillos numéricos, gráfica de XP, skeletons y notificación dot son componentes de UI con datos reales, no bitmaps. Animación desbloqueo scale/fade 350–500ms y halo sobrio, alternativa sin movimiento. No exigir Lottie si el repo no lo necesita.

Separar store/servicio/modelos de Momentum. Cache por usuario, vaciar al logout/cambio de cuenta. ACK offline con idempotency key estable y occurred_at validado: no completar retroactivamente una semana caducada con un evento recién fabricado. Servidor decide ventana tolerada documentada. Refresh al volver foreground y cambio de período. Notificaciones y navegación no apilan modales: marcar presented/seen coherentemente; backfill en resumen.

Contextual strips en Transacciones, Pagos, Proyectos, Facturas, Inversiones, Categorías y Análisis sólo cuando haya misión relevante. Coachmark una vez y dot de nueva semana. Push: una de misiones listas y máximo un recordatorio por semana, deduplicado entre dispositivos, preferencias/quiet hours y timezone; comeback con cooldown. No incluir información financiera sensible.

Créditos IA: tres preguntas al llegar a Organizer, una concesión por usuario, vencen a 30 días. No conceder Pro ni alterar suscripciones. Comprobar Pro antes de créditos; reservar crédito atómicamente antes de llamada y consumir sólo respuesta exitosa, liberar fallos/timeout con reconciliación. Evitar gasto doble bajo llamadas concurrentes y no generar cargos ilimitados reintentando. Desactivar concesión por flag si IA no está disponible.

## 5. Google Play Billing

A fecha 22-09-2026, fuentes oficiales consultadas muestran Billing 9.1.0 y vencimiento normal de Billing 7 para nuevas publicaciones/updates el 31-08-2026, con extensión hasta 01-11-2026. Revalida documentación al ejecutar. Apunta a la estable actual compatible; no confundir mínimo admitido con última versión ni asumir que cambiar pubspec actualiza el SDK nativo.

1. Auditar plugin/wrapper real y dependencias transitivas. Actualizar por una ruta oficialmente compatible. Verificar Gradle dependencyInsight/dependencies y metadata del manifiesto del build release. No usar resolutionStrategy force para saltar APIs incompatibles. Si falta soporte de wrapper para 9.x, implementar/adaptar correctamente o documentar la dependencia concreta y la versión soportada provisional; no decir que migraste a 9 si el bundle usa 8.
2. ProductDetails, base plans, ofertas elegibles, offerToken y precio/moneda/periodicidad localizados desde tienda. No fijar precios, product IDs o descuentos inventados. Tratar errores, cancelación voluntaria, servicio desconectado, red, pendiente, compra ya poseída, restore y app kill durante checkout.
3. Backend verifica purchaseToken con Google Play Developer API, `purchases.subscriptionsv2.get` para estado. Validar package, productos permitidos, entorno, estado y asociación a usuario. Token único, protegido, nunca en logs/admin/export. Obfuscated account ID sin email en claro. No permitir trasladar un token existente entre usuarios por simple POST.
4. Entitlement sólo después de verificar compra y estado; pending no concede acceso. Acknowledgement idempotente tras concesión validada y dentro del plazo de Google, con worker/reintentos y alertas. No consumir suscripciones como productos consumibles. Evitar doble lógica incompatible entre completePurchase del plugin y ACK backend; documentar el propietario del ACK y usar integración correcta del plugin.
5. RTDN vía Pub/Sub autenticado (validación JWT/audience/issuer/service-account según transporte). Persistir evento duradero antes de ack; deduplicar messageId y estado proveedor. RTDN dispara consulta al proveedor, no prueba por sí sola el entitlement. Manejar mensajes repetidos/fuera de orden, retries, dead letter, linkedPurchaseToken, sustituciones, renewals, cancelación con acceso hasta expiración, grace, hold, paused, expired, refunded/revoked y recovered. Reconciliación periódica repara notificaciones perdidas.
6. Una capa común de entitlement enlazada a fuentes Google, Apple y Stripe existentes. Conservar suscripciones actuales y acceso multiplataforma. Cancelado no equivale a expirado. Estado de gracia puede mantener acceso conforme al proveedor, hold/expiry no. Revocar una fuente no elimina otra concesión legítima activa. Grants manuales separados y con vencimiento; AI credits aparte.
7. Si Apple/Stripe ya tienen proveedor intermediario, reutilizar su fuente fiable y no introducir dos autoridades de entitlement. Completar normalización e ingestión necesarias para admin sin reescribir checkout que funciona.
8. Restauración, cambio de cuenta, múltiples dispositivos y cambios de plan deben conservar identidad y evitar dos registros activos contables del mismo contrato por reemplazo de token.
9. Este alcance actualiza Play Billing y suscripciones; no activar Billing Choice/pagos alternativos/enlaces de pago externos ni cambiar precios por inferencia. Si existe un requisito explícito en repo, documentarlo separadamente.

Entregar `.env.example` sin secretos, permisos mínimos, instrucciones Play Console/PubSub/credenciales/RTDN, datos concretos que falten, build y matriz sandbox. No depender de credenciales de producción para unit/integration tests.

## 6. Telemetría propia de uso

Instrumenta Flutter Android/iOS y React web. Tabla/event pipeline propio para métricas del admin; Firebase Analytics puede complementar, nunca adjudicar XP ni reemplazar registro servidor de pagos.

Separar analytics_events (comportamiento) de engagement_events (dominio confiable). Esquema: event_id UUID, schema_version, user_id interno obtenido de auth, session_id, install_id rotativo cuando corresponda, client_platform web/android/ios/unknown, app_version/build, source_screen allowlist, client_occurred_at y received_at, metadata limitada. Cliente web en Android cuenta como web: OS no es plataforma. Origen legacy desconocido queda unknown; no inferir Android del proveedor Google. Flags de entorno test/internal para exclusión.

Sesión: nueva tras 30min de inactividad; documentar foreground/heartbeat y no contar background push como uso. Lifecycle para last_seen; actividad significativa definida en catálogo de eventos de dominio/reviews, no sólo app_open. Deduplicar eventos offline, descartar timestamps imposibles y no convertir un retry en usuario activo adicional. Backfill sólo métricas derivables y con procedencia; tracking comienza en una fecha visible.

Eventos mínimos: session_started, app_foregrounded, screen_view permitido, feature_used, onboarding_step_completed, paywall_viewed, checkout_started, purchase_pending, purchase_verified (servidor), purchase_failed sanitizado, subscription_state_changed (servidor), restore_completed y eventos Momentum del plan. Funnel de compra une eventos por checkout/flow ID no sensible; no confundir intentos con transacciones confirmadas.

No enviar montos financieros personales, nombres de comercios/clientes, descripciones, recibos, IDs de cuentas financieras ni preguntas IA. Ingresos de suscripción provienen del proveedor y viven en billing, no payload analítico genérico. Limitar payload, rate limits y metadatos permitidos en servidor. Política de retención y borrado documentada; respetar consentimiento/configuración de privacidad existente. Sin fingerprinting.

## 7. Admin privado del propietario

Implementar en React existente bajo `/admin`, layout separado del dashboard financiero personal. Admin role verificado en cada endpoint servidor; ocultar menú no es autorización. Bootstrap del owner mediante mecanismo seguro/env/CLI que resuelva un usuario real, sin asumir ID 1 o que todos son admin. No admitir role desde cliente. Auditar acceso/exportación; reutilizar MFA/reauth si existe. No incluir controles de cobro, cancelación masiva ni acceso a cuentas financieras personales fuera de lo pedido.

Páginas:
- Overview: registrados, activos DAU/WAU/MAU, nuevos, activación, retención D7/D30, suscriptores pagados activos, trials, Pro concedidos/manuales, MRR estimado por moneda y cobros/reembolsos verificados. Mostrar frescura, período, timezone y cobertura.
- Usage: series temporales, features utilizadas, sesiones, funnel de onboarding, cohorts y distribución web/android/ios/unknown, usuarios multiplataforma.
- Users: búsqueda autorizada por ID/email, paginación servidor, alta, last_seen, plataformas observadas, última plataforma, versiones, estado Pro, proveedor, plan, expiry, XP/nivel. Detalle con timeline saneado, no purchaseTokens ni datos financieros privados.
- Subscriptions: Google Play/Apple/Stripe/unknown por separado, trial/active/cancel_at_period_end/grace/hold/paused/expired/revoked/refunded cuando aplicable, renovación, moneda, periodicidad, estado de sincronización y discrepancias. Distinguir estado bruto proveedor de normalizado y acceso efectivo.
- Momentum: asignados/completados por misión, abandono, niveles, XP otorgado, insignias, semanas completas, exposición experimental, cohortes y funnel crédito IA→upgrade. No presentar correlación como causalidad.
- Data health: fecha inicial de tracking, retraso ingestión, último sync de proveedores, eventos fallidos, webhooks pendientes, unknown platform y errores sanitizados. Sin tokens o payloads crudos expuestos.

Filtros compartidos: fechas, zona de informe, plataforma de uso, proveedor de pago, plan, estado, versión, cohorte, entorno y exclusión de cuentas internas. Rango arbitrario con límites sensatos, consultas parametrizadas, agregaciones e índices; no descargar todos los usuarios al navegador. CSV autorizado y con fórmulas escapadas para evitar inyección; no secretos. Read-only de negocio por defecto.

### Definiciones medibles

- DAU/WAU/MAU: usuarios únicos con actividad significativa en 1/7/30 días; mostrar también sesiones por separado. Ventanas terminan en la fecha seleccionada, día parcial marcado.
- Activos por plataforma: un usuario puede estar en varias series; total global deduplicado. Mostrar intersecciones o advertencia visible: suma por plataforma no equivale al total. El gráfico de sesiones sí puede ser reparto exclusivo.
- Última plataforma por último evento válido; plataformas usadas por período; signup_platform sólo si capturada realmente; purchase_provider independiente.
- Activación = usuarios que completaron las seis activaciones / cohorte elegible, dentro de ventana explícita (7 días para vista primaria). No incluir cohortes inmaduras en métricas cerradas.
- D7/D30 exactos por día local de cohorte: actividad significativa en día 7/30 después del alta; denominator sólo usuarios con ventana completa. No llamar D7 al regreso en cualquier momento de 7 días. Implementar y etiquetar por zona de informe consistente.
- Completion semanal = sets completos / sets elegibles asignados de semanas cerradas. Mostrar progreso de semana actual por separado.
- Subscriber count = usuarios únicos con suscripción pagada efectiva, no número bruto de tokens. Contratos y users son indicadores separados. Trials y grants manuales separados.
- MRR estimado contractual: importe recurrente vigente del contrato / meses de período, moneda por moneda; trial/grants excluidos, anual /12, upgrades/reemplazos deduplicados. Política de descuentos explícita, tax/fees según cobertura. No presentarlo como ingreso neto liquidado.
- Revenue = cobros confirmados del período por moneda; refunds por fecha de reembolso, neto de refunds separado de comisiones/impuestos no disponibles. Nunca sumar MXN+USD sin FX histórico y método visible. Datos no disponibles = N/D, no cero.
- Churn de suscripción = contratos efectivos perdidos en período / contratos activos al inicio, con definición de exclusión de reemplazos. Churn usuarios separado si implementado. Cancelación programada no es churn efectivo.
- Conversion paywall→purchase = usuarios expuestos que convierten en 7 días, cohortes maduras; ratios por intento separados. Documentar atribución temporal y proveedor.

Gráficas funcionales con librería del repo: líneas DAU/WAU/MAU, barras por plataforma/feature, cohort heatmap, funnel, estados de suscripción, ingresos/MRR por moneda y progreso Momentum. Tooltips/tabla accesible, loading/error/empty, sin datos de demostración en producción. No usar imágenes estáticas para métricas.

## 8. Pruebas y criterios de entrega

Tests relevantes, no snapshots vacíos:
- Reglas de cada misión/badge, niveles 249/250/749/750/1499/1500, cap semanal 100+20, mensual 75, comeback, grace, timezone/DST y cambios de zona.
- Dos dispositivos completando la misma misión, duplicados/outbox retries, recategorización/delete-recreate, backfill repetido y reconstrucción ledger, failure del evaluador tras commit financiero.
- Free nunca recibe misiones requeridas bloqueadas; expired Pro sustituye elegibilidad sin doble bonus. Créditos IA concurrentes, expiración, timeout y retry.
- Billing verified/pending/cancelled/grace/hold/recovered/expired/revoked, app kill/restore, ACK fallido y retry, RTDN fuera de orden, token reclamado por otro usuario, replacements y convivencia de proveedores.
- RBAC: anónimo 401, usuario normal 403 incluso llamando API directamente; filtros/query validation/CSV; autenticación webhooks.
- Métricas con fixtures de usuario multiplataforma, cohorte inmadura, anual/mensual, monedas distintas, trial, grants, refunds y unknown. Resultados SQL comparados con expectativas exactas.
- UI Flutter/web: light/dark, ES/EN, accesibilidad, offline, deep links, un modal por unlock, 34 keys de badges y assets existentes. Build/lint/typecheck/tests disponibles.
- No simular test de compra real como si fuera test sandbox ejecutado. Entregar checklist Play internal testing y Apple/Stripe regresión cuando requieran accesos.

## 9. Secuencia y finalización

A. Auditoría y contratos; B. DB/telemetría/RBAC; C. Billing/entitlements; D. Motor Momentum y catálogo completo; E. Flutter/web + recursos; F. Admin; G. integración y rollout.

Usar flags independientes `momentum_enabled`, `momentum_ai_rewards_enabled`, `admin_analytics_enabled` y flags de rollout de pagos apropiados sin desactivar verificación o RTDN de compras existentes. Backend antes de clientes. Registrar checks y blockers. Si necesitas varias sesiones, guardar estado y siguiente acción exacta, continuar todo lo implementable. No recortar a 12 insignias o sólo frontend: el alcance solicitado incluye las 34. Priorizar un primer flujo vertical funcional y luego completar catálogo.

Entregar código real, migraciones, seeds de catálogo no de usuarios ficticios, SVG integrados, tests, README de operación, configuración sin secretos, runbook de despliegue/rollback con preservación de ledger y checklist manual pendiente. Resumen final distingue implementado, verificado y pendiente externo. No afirmar producción lista si faltan compras sandbox o pruebas reales.

## Fuentes oficiales a revalidar

- https://developer.android.com/google/play/billing/release-notes
- https://developer.android.com/google/play/billing/deprecation-faq
- https://developer.android.com/google/play/billing/migrate-gpblv9
- https://developer.android.com/google/play/billing/security
- https://developer.android.com/google/play/billing/backend
- https://developer.android.com/google/play/billing/subscriptions
- https://developer.android.com/google/play/billing/rtdn-reference
- https://developer.android.com/google/play/billing/test

Verifica también documentación primaria del plugin Flutter/proveedor realmente encontrado. No fijar una versión de plugin sin inspección.

## 10. Recuperar contraseña — alcance adicional obligatorio

Implementar recuperación completa en web, Android e iOS. Incluirla en auditoría, fases, tests y definición de terminado; no dejarla como sugerencia.

- Revisar primero auth actual. Si usa proveedor gestionado, utilizar su flujo oficial, no almacenar una contraseña paralela. Si auth es propia, usar biblioteca criptográfica del stack y el hash de contraseñas existente seguro.
- Login con “¿Olvidaste tu contraseña?” / “Forgot password?”. Pantalla email, confirmación neutral, reenvío con cooldown, formulario nueva contraseña y confirmación, estados link inválido/expirado/usado y final con volver a iniciar sesión. Accesibilidad, ES/EN, light/dark y validación coherente con registro.
- POST `/api/auth/forgot-password` y POST `/api/auth/reset-password` o rutas equivalentes del repo. La primera responde de forma uniforme exista o no el correo, también para usuarios SSO-only; no filtrar existencia por cuerpo, status o diferencias obvias de tiempo. Límites por IP y cuenta normalizada, sin convertirlos en bloqueo del login ni permitir spam de correo.
- Para auth propia: token opaco de alta entropía (mínimo 32 bytes aleatorios), almacenar sólo hash, usuario, expiry, consumed_at. Caducidad inicial 30 minutos configurable. Nueva solicitud invalida enlaces anteriores sin cambiar contraseña. Verificación y consumo atómicos junto con cambio de contraseña; dos requests concurrentes no pueden usarlo dos veces. Token no aparece en logs, analytics, errores, referrers ni admin. Nunca enviar contraseña por correo.
- URL de recuperación construida desde origen HTTPS canónico configurado y allowlist, jamás Host header o redirect arbitrario del usuario. Página de reset sin trackers, con Referrer-Policy no-referrer; retirar token de barra/historial tan pronto como sea viable tras capturarlo de forma segura. GET del enlace no cambia contraseña ni consume token: los scanners de correo no deben invalidarlo.
- Reutilizar mailer existente (Resend si sigue siendo el proveedor real). Template branded FinSight, CTA, vencimiento, texto si no se solicitó y alternativa accesible. Configurar remitente desde entorno; no asumir que un dominio está verificado sin evidencia. Entregar preview del email y variables necesarias sin secretos. Enviar aviso de contraseña cambiada después del commit.
- Universal Links/App Links sólo para dominio poseído/configurado; fallback web siempre funcional si la app no está instalada. La página web permite terminar recuperación en otro dispositivo. No inventar archivos de asociación/certificados ni afirmar que están desplegados. Reutilizar configuración de deep links existente y documentar asociación pendiente.
- Tras reset exitoso, invalidar sesiones/refresh tokens en todos los dispositivos mediante mecanismo real de auth (session_version/token_version o revocación). Para JWT de acceso, implementar invalidación comprobable por servidor o documentar y minimizar ventana residual si la arquitectura lo impide; no decir revocación inmediata si sólo se revocó refresh. No auto-login desde token de recuperación. Mantener compras, entitlement y datos del usuario intactos.
- Cambiar contraseña desde sesión autenticada, si existe, debe seguir exigiendo autenticación/reauth vigente; no debilitarlo para reutilizar este flujo. SSO-only se orienta al proveedor correspondiente sin crear password local por accidente.
- Auditoría saneada de request/completed/failure sin email en eventos públicos ni token; telemetría mínima sin señal externa de existencia de cuenta.
- Tests: cuenta existente/no existente, token expirado/inválido/usado, replay y carrera, request nuevo invalida anterior, scanner GET, rate limit, email error sin filtración, password policy, sesiones revocadas, URL/redirect no permitido, deep link y fallback web. Test integración completo de solicitud→correo capturado en entorno test→reset→login nuevo→fallo password anterior.
