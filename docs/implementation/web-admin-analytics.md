# Web, telemetría y panel del propietario

Implementación aditiva en React 19/Router 7/Recharts existente; no cambia el stack. Los SVG del paquete se resuelven por key desde `public/momentum/assets/manifest.json`: 34 insignias, cuatro niveles, doce marcas UI, 168 variantes. La prueba `server/admin/web_assets.test.ts` comprueba catálogo, paths y archivos reales.

## Web Momentum

`src/momentum/{types,service,context,store,Asset,ui,utils}` separa contratos, red, estado y presentación. El servidor concede elegibilidad/XP/créditos; el cliente nunca manda cantidades de XP. La tarjeta de Home va después del resumen financiero. `/momentum` presenta hasta tres activaciones accionables, misiones semanales, mensuales y otras asignadas, XP nominal/concedido y límites, nivel, ritmo/gracia, historia XP real y preferencias. `/momentum/achievements` usa las 34 keys del DTO con requisitos, progreso y filtros. Hay strips contextuales en las siete secciones solicitadas y enlace desde el perfil.

Las revisiones `/momentum/review/:kind` cargan snapshots reales, muestran sus tablas y requieren confirmar cada sección aplicable y elegir siguiente paso cuando corresponde. La confirmación conserva payload/UUID en memoria durante un reintento en esa pantalla: no anuncia éxito offline ni fabrica otro `occurred_at`. Al abandonar/recargar la pantalla se solicita una evidencia nueva; ninguna revisión se ejecuta en segundo plano. Se muestran vencimiento y recuperación de errores. La revisión semanal/mensual usa idempotencia del snapshot servidor.

Cache exclusivamente en memoria, validación de `user_id` y generación de sesión antes de aceptar respuestas. Logout/cambio de cuenta descarta estado; foreground, recuperación de red, mutaciones financieras exitosas y timer visible de un minuto actualizan Momentum y períodos. Backfill tiene un resumen y ACK explícito. Cada montaje de la pantalla muestra como máximo un dialog de logro; el ACK se persiste en servidor. El dialog usa `<dialog>` nativo, foco y Escape; animación 400ms con alternativa sin movimiento. Assets 24/40/64px, textos ES/EN, light/dark y controles etiquetados.

No se creó un producto IA web nuevo: la web preexistente sólo enlazaba a GPT externo; los créditos se visualizan y remiten al asistente móvil existente. La exportación web no genera ACK de éxito porque el navegador no permite probar si se canceló imprimir. Capacidad/notificación no disponible se explica desde el DTO, nunca concede progreso por una visita.

Corrección de compatibilidad encontrada durante QA: Vite no sustituía `(import.meta as any)?.env?.VITE_API_URL`; el navegador caía al puerto legacy 3001 incluso con configuración. Se usa `import.meta.env.VITE_API_URL` directo en consumidores existentes, preservando configuración/env y contratos financieros.

## Telemetría

`server/analytics/{validation,repository,routes}` y migración006 complementan tablas001. `POST /api/analytics/events` sólo admite lote de1–20 eventos allowlist, UUIDs, timestamp dentro de24h y máximo60s futuro, campos/versiones/pantallas/metadatos restringidos y rate limit60lotes/min/usuario. Auth determina usuario; desconocidos, `user_id`, XP, montos, prompts y eventos de proveedor enviados por cliente se rechazan. `INSERT IGNORE event_id` deduplica reintentos; sesión no puede cambiar de usuario ni plataforma.

Los eventos cliente son `significant=false`. `recordDomainAnalytics` sólo se llama desde handlers/outbox confiables; es la fuente de actividad significativa. Origen legacy de dominio es `unknown`, nunca se deriva del proveedor. `recordBillingAnalytics` comparte conexión/transacción de billing, deduplica UUID, guarda sólo provider/status/flow_id y siempre mantiene `significant=false`, platform `unknown`, sin avanzar sesiones. Signup registra plataforma únicamente si se recibió realmente del cliente; el pasado permanece desconocido.

Web registra plataforma `web`, incluido navegador sobre Android. `VITE_APP_VERSION` es opcional; ausente permanece sin versión, no se inventa. Sesión nueva tras30min de inactividad; heartbeat cada minuto sólo con interacción reciente y pestaña visible, sin extender actividad por background/push. Instalación UUID aleatoria por usuario rota30d. Cola local máximo100 eventos/24h, UUID estable, sólo campos permitidos; se borra al logout/cambio de cuenta. Login/signup/recovery/admin no generan screen telemetry. El token de recuperación nunca se incluye en evento/ruta/metadata.

`GET /api/analytics/preferences` devuelve `{enabled,available}`; `POST` sólo acepta `{enabled:boolean}`. Control en perfil; servidor aplica opt-out a eventos de cliente, dominio y pagos analíticos sin alterar billing o ledger financiero. No hay fingerprinting ni consentimiento previo gestionado en el código original; se agregó esta preferencia. Retención eventos/sesiones y auditoría admin400d; borrado de cuenta cascade elimina PII. `cleanupAnalytics` es ejecutado por el mantenimiento compartido.

Paywalls reales emiten exposición y checkout con UUID `flow_id`; Stripe lo recibe y propaga a confirmación verificada. El inicio de checkout espera como máximo 250 ms al registro analítico. Un retorno cancelado consume la correlación local una vez y emite `purchase_failed`; un retorno de éxito nunca sustituye la verificación de servidor. Una mutación financiera exitosa emite feature_used y refresca Momentum. Las seis activaciones emiten el paso observado sólo tras transición a completed verificada por servidor, sin convertir un backfill inicial en eventos históricos.

## Admin read-only

Layout independiente `/admin` y páginas overview, usage, users, subscriptions, momentum, data-health. Auth JWT y consulta `admin_roles` en **cada** endpoint; un usuario normal obtiene403 incluso con ID1/3 o bodyroleowner. `/api/admin/access` permite mostrar menú sólo al owner. No hay MFA en auth original: no se inventó una protección inexistente.

Bootstrap sobre un usuario existente, nunca seed de personas:

```sh
node --import tsx server/admin/bootstrap-owner.ts --email owner@example.invalid --apply
# Alternativa: --user-id <id-existente>; revocación: añadir --revoke
```

Operar con email real revisado o ID inequívoco en el entorno autorizado. La CLI exige exactamente un usuario, hace transacción y audita. No se ejecutó bootstrap en producción. No existe endpoint para asignar roles desde cliente.

Contratos y agregaciones SQL en `server/admin/service.ts`; queries parametrizadas, filas explícitas, paginación25(default)/100(max), rango hasta366d, zona IANA, plataforma/proveedor independientes, plan, estado, versión, fecha de cohorte, entorno y exclusión interna. Desconocidos no se completan por inferencia. Búsqueda autorizada por ID/email. Tablas y timeline omiten tokens, claves de contrato, prompts, cuentas/transacciones financieras personales y payloads crudos. Reportes son read-only; accesos y CSV se auditan con filtros saneados, sin query/email en auditoría. Export users/subscriptions máximo10,000filas y5/h; escape de fórmulas CSV además de comillas.

Gráficos Recharts usan datos reales, tooltip/legend y tabla accesible; cohortes tienen tabla coloreada y valores textuales. Estados loading/error/empty, filtro compartido y frescura/periodo/timezone/cobertura explícitos. Notas de metodología ES/EN.

- DAU/WAU/MAU: únicos de actividad significativa, ventanas locales1/7/30 al día final, parcial marcado. Plataformas se solapan; total global deduplicado; sesiones son indicador separado.
- D7/D30: día local exacto después del alta, sólo días completos y altas posteriores al inicio de tracking. Si faltan tablas de zonas MySQL, N/D explícito. Activación: seis completados reales dentro de siete días, denominador maduro.
- Suscriptores pagados: usuarios únicos efectivos; contratos, trials y grants separados. Usuario muestra caché Pro y Pro efectivo por fuentes verificados por separado.
- MRR: snapshot contractual actual por moneda; anual/12; sin trials, grants ni reemplazos. Importes/períodos desconocidos tienen cobertura explícita. No representa ingreso neto liquidado.
- Cobros/refunds: ledger verificado y fecha del cargo/reembolso, moneda separada. Sin histórico disponible = N/D. No FX implícito.
- Churn: contratos observados pagados activos al inicio que pierden acceso efectivo al cierre, excluye reemplazos; cancel_at_period_end no es pérdida mientras conserve acceso. Falta de histórico limita denominador.
- Conversión: primera exposición en rango, siete días maduros y checkout flow_id del mismo usuario emparejado a purchase_verified servidor. Intentos separados; restore sin correlación no se atribuye retroactivamente.
- Completion semanal: semanas cerradas con tres slots elegibles; progreso actual separado. Crédito→upgrade es correlación temporal, sin afirmación causal; no se inventan exposiciones experimentales.

## Verificaciones ejecutadas

- TypeScript app: `node node_modules/typescript/bin/tsc -p tsconfig.app.json --noEmit --incremental false` PASS.
- TypeScript dirigido backend recuperación/analytics/admin PASS.
- ESLint de módulos nuevos web y recovery/authApi: PASS (baseline global tenía166errores/6warnings preexistentes).
- 14 unit tests recovery/session/RBAC/filtros/DST/CSV/telemetry PASS; cobertura de assets 1/1 PASS.
- `npm run test:db -- server/recovery/mysql.test.ts server/analytics/mysql.test.ts server/admin/metrics_sql.test.ts`: **4 pruebas MySQL8.4 reales PASS** con múltiples assertions. Incluye rollback después de escribir password, concurrent double-use, revocación JWT, proveedor/uso separados, opt-out, ownership sesión, dedup, usuario multiplataforma, D7/D30 exactos vs inmaduros, anual/mensual, monedas, trial/grant/refund/unknown y ejecución de seis reportes, filtros/paginación/export/timeline sin secretos.
- Pruebas DB sólo aceptan NODE_ENV=test, hostloopback y nombreDB test; fixtures dedicadas se eliminan; ningún proveedor remoto se llama.
- Build de producción final aislado sin `.env` en `/tmp/finsight-final-build/dist`: PASS, 2,945 módulos. CSS 76.19 kB, bundle principal 1,124.54 kB y escena 3D previa 901.32 kB. Persisten advertencias de bundles mayores de 500 kB y datos Browserslist antiguos; no se alteró el lockfile para silenciarlas.
- `git diff --check`: PASS.
- Preview aislado bajo `/tmp/finsight-ui-qa` sin `.env`, API local con routers reales/DB test y usuario de QA desechable. El coordinador verificó Dashboard, tarjeta Momentum, misiones, revisión semanal explícita (checkboxes antes de confirmar; 50→115 XP y 0/3→1/3), galería clara con 34 insignias y 2 desbloqueadas, y Admin con layout separado, seis secciones, filtros, cobertura N/D y exclusión predeterminada de la fixture de prueba. DevTools mostró cero errores.
- La automatización nativa de Chrome presentó snapshots atrasados y acciones intermitentes; no se certificaron visualmente modo oscuro, cambio ES/EN ni formularios de recuperación web. Recuperación sí tiene pruebas unitarias y MySQL descritas arriba. La QA local no equivale a dispositivo ni sandbox de compras.

Pendiente externo: consentimientos legales locales, cargar timezone tables en destino, configurar owner real porCLI, versión/build pública, observación de cobertura de proveedor y rollout flags. Resend/Play/Apple/Stripe/sandbox/dispositivos no se validan con fixtures locales.
