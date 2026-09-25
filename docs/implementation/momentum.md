# Momentum: implementación y operación

El servidor mantiene un catálogo versionado de 41 misiones y 34 insignias en `server/momentum/catalog.ts`. React y Flutter sólo muestran el DTO común de [client-contract.md](client-contract.md). Assets originales: 168 SVG, copiados por manifiesto y verificados byte a byte; `npm run assets:check` no modifica archivos.

## Autoridad y límites

Las seis activaciones conceden 250 XP en total. `clear_view` concede 50 adicionales; las insignias nominales 0 no duplican sus misiones. Explorer 0, Organizer 250, Planner 750, Strategist 1500. El XP vitalicio se reconstruye por SUM del ledger, nunca por contadores del cliente.

Una semana tiene tres tareas requeridas persistidas: revisión, mantenimiento y objetivo. Se eligen sólo con cuenta y actividad real, usando alternativas Free cuando no hay recursos o Pro. Una única tarea opcional rota de forma determinista por semana ISO/usuario entre capacidades elegibles. No se vuelve a sortear al abrir otro dispositivo. Sólo se reemplaza un slot imposible; queda historial. Los completados no cambian. Si no hay sustituto, queda unavailable y no penaliza ritmo.

Todas las misiones semanales y comeback comparten 100 XP. Terminar los tres slots concede un único bono 20; los mensuales comparten 75 XP. Completan incluso si el saldo concede 0 XP. Insignias únicas quedan fuera de esos topes. Ledger append-only mediante triggers; correcciones son filas compensatorias con referencia y motivo auditado, nunca UPDATE/DELETE. Un descuento compensatorio no reabre el presupuesto del período.

Bloqueo común: `users FOR UPDATE` antes de crear/bloquear `user_momentum`; coincide con Billing y evita deadlocks por promoción de locks de FK. Recompensas y progresos se escriben dentro de esa transacción. Uniques de misión/usuario/período, recompensa/idempotencia y badge/usuario impiden duplicación entre dispositivos. Los errores deadlock/lock-timeout se reintentan hasta tres veces.

## Evidencia real y períodos

GET de revisión crea un snapshot con digest de datos reales, nombres de secciones aplicables y vencimiento, sin una segunda copia de las finanzas. No completa la revisión. Confirmar requiere checklist explícito, datos revalidados y siguiente paso en la revisión semanal/mensual. Semanal: cuentas, actividad, neto y obligaciones aplicables. Mensual: cuentas, neto, categorías y obligaciones aplicables. Un cambio de datos devuelve 409 y exige recargar. Snapshot máximo 15 min, limitado por cierre del período; ACK offline máximo 15 min y únicamente período vigente. No se conceden revisiones históricas.

La zona IANA y los límites se guardan con cada período. Offset es fallback. Una preferencia manual se guarda separadamente del contexto del dispositivo para que un refresh o push-token no la cambie. El período ya iniciado conserva sus límites; los cambios rigen en el siguiente período no solapado. Retroceder una zona/clave nunca reabre un período premiado. DST se calcula con días civiles, incluyendo semanas 167/169 horas.

`comeback_clarity` requiere 14 días sin actividad significativa conocida; conserva el episodio capturado hasta su revisión y no infiere inactividad de usuarios sin evidencia. `comeback_week` requiere una semana asignada anterior no completada y una misión de la actual completada. Ambos consumen el tope semanal. Gracia configurable con `MOMENTUM_GRACE_ENABLED`: una semana dentro de cada ventana móvil de 8 semanas; preserva ritmo, sin XP ni revisión ficticia. DTO indica período de gracia.

La identidad canónica de una transacción se fija al insert a partir de cuenta, fecha, tipo, importe, descripción normalizada. Un trigger conserva esa identidad al editar. Categorizar/deshacer/recrear el mismo registro original no suma de nuevo. Transfers no cuentan. Dos registros idénticos se consideran la misma evidencia para Momentum aunque ambos sigan visibles en finanzas. Los targets de categorización capturan registros existentes, no nuevos volúmenes.

El modelo de proyectos no tiene progreso de trabajo 25/50/75: esas tres insignias permanecen visibles pero inhabilitadas, con motivo explícito. `goal_builder_4` reconoce una vez un proyecto marcado Completed. Nunca se traduce dinero gastado/aportado en porcentaje de trabajo.

## Outbox y recuperación

Las aportaciones directas de inversiones insertan `investment_contributions.insert` desde su ruta dentro de la misma transacción que aportación, saldo e historial. El payload contiene sólo identificadores internos, sin importes, y el consumidor reconoce actividad significativa sin dar XP por aumentar la inversión.

`004_domain_outbox.sql` agrega triggers a cuentas, transacciones, categorías, subcategorías/presupuestos, pagos, proyectos, facturas, pagos de factura, inversiones y drafts. Cada INSERT del evento participa en la misma escritura/transacción financiera. Un fallo al insertar outbox devuelve error y revierte esa escritura; el evaluador no corre allí. Las transacciones heredadas y sus helpers comparten conexión mediante AsyncLocalStorage. Una respuesta cerrada aborta el scope y no permite que los siguientes statements se ejecuten accidentalmente en autocommit.

Después del commit, el worker procesa eventos bajo lock del usuario. Reentrada, duplicados y crash hacen rollback de su procesamiento sin tocar la operación financiera confirmada. Backoff exponencial con límite 1 h, 10 intentos antes de failed. Admin/Datahealth muestra errores saneados y atraso. Reintento operativo: tras corregir la causa, marcar únicamente IDs revisados de `engagement_events` failed como retry con `next_attempt_at=UTC_TIMESTAMP(3)`; no alterar payload ni otorgar XP manual.

Reconciliación cada 5 min, lotes 50 usuarios con cursor persistente, y en GET/confirmaciones. Backfill deriva sólo configuración/logros comprobables, no sesiones ni reviews/rachas. La primera síntesis histórica se reconoce una vez; su ACK marca vistos los badges históricos anteriores al backfill. Misiones y XP existentes no se borran al apagar presentación.

El worker clasifica sólo cambios financieros comprobados, revisiones, recibo confirmado y respuesta IA como actividad significativa. Plataforma de los triggers queda unknown: no se inventa a partir de Google/Apple/Stripe. Tracking de pantalla/login no da XP ni DAU significativo.

## IA y notificaciones

`MOMENTUM_AI_REWARDS_ENABLED` requiere una clave del producto IA existente. Al alcanzar Organizer se concede una vez un grant de 3 preguntas, 30 días. `MOMENTUM_AI_CREDITS_ENABLED` queda como alias compatible interno. Pro tiene prioridad. UUID por pregunta reserva capacidad bajo lock antes de la llamada, consume sólo respuesta no vacía y exitosa; fallo/timeout libera. El SDK hace 0 reintentos y timeout máximo 60 s; una solicitud ambigua no se repite al proveedor con el mismo UUID. Hasta 6 intentos/día Free y 100 Pro incluyendo fallos. Reservas expiran 2 min y se reconcilian. Una respuesta se guarda privadamente 24 h para reintentos; después sólo queda el tombstone de UUID y no se hace otra llamada. Prompts y respuestas nunca entran en analytics/outbox/ledger.

No se creó una IA web nueva: el enlace web legado a GPT externo no prueba respuesta ni concede recompensa. Flutter usa el endpoint existente. Export local exige un snapshot real y ACK únicamente tras PDF/share exitoso; su evidencia es declaración acotada del cliente, no confirmación de una descarga desde servidor. Receipt requiere flag y capacidad existentes; sólo confirmed y hashes distintos cuentan.

Push está apagado por defecto, opt-in por usuario y depende de FCM configurado/permiso de dispositivo. Una notificación week-ready y a lo sumo un recordatorio por semana, más comeback una vez por episodio con cooldown 14 días; mínimo 48 h entre mensajes Momentum. Horas quietas locales (start=end silencia todo el día), textos EN/ES sin datos financieros. Se reserva antes de enviar; un envío ambiguo no se repite. Cursor por usuario evita que el primer lote 500 monopolice las entregas. Todos abren `/momentum`.

## Retención, flags y rollout

Los hijos tienen FK cascade al usuario: incluso el ledger inmutable se elimina mediante cascade al borrar cuenta. No se conserva una identidad personal fuera de ese mecanismo. Snapshots vencidos se purgan tras 1 día; eventos outbox procesados tras 30 días; límites tras 2 días; caché IA tras 1 día. Failed permanece visible para recuperación. Métricas tienen su política separada 400 días en [web-admin-analytics.md](web-admin-analytics.md).

Flags independientes en [.env.example](../../financial-dashboard/.env.example): MOMENTUM_ENABLED, presentation/evaluation; MOMENTUM_WORKER_ENABLED, outbox/reconciliación; MOMENTUM_AI_REWARDS_ENABLED, grant/accesscredits; MOMENTUM_PUSH_ENABLED, delivery; ADMIN_ANALYTICS_ENABLED, ingest/admin. Mantener worker activo aunque Momentum esté off permite capturar dominio para analytics; la cola financiera sigue durable. Verificación de Billing y revocación JWT no dependen de estos flags.

Orden: revisar copia de datos y privilegios MySQL 8/InnoDB, aplicar 000–009 explícitamente en staging, API/worker primero, flags opt-in, clientes después. El arranque comprueba migraciones y secreto JWT en producción y no hace DDL/seed. Rollback de presentación por flags preserva ledger, inbox, bindings y sesiones revocadas. No restaurar binario anterior que ignore revocación o acepte compras sin verificar. Las pruebas de FCM/IA real/dispositivos y proveedores requieren configuración externa y no se dan por realizadas.
