# FinSight: auditoría integral previa a implementación

Fecha: 2026-09-24. Estado: **auditoría de sólo lectura cerrada**; este informe es la primera modificación deliberada del checkout. El checkpoint al propietario precede todo cambio funcional, schema o dependencias. La auditoría identifica riesgos; no garantiza ausencia de errores.

## 1. Estado inicial, alcance y evidencia

- Repositorio local `/Users/elias/Desktop/financial-board`, rama `master`, HEAD `19c5651fc322cfacac5645ec92b618dbb92cc08e`, coincide con referencia histórica.
- `git status --short` inicial y al cerrar lecturas: únicamente `?? finsight-momentum/`. No cambios tracked del propietario. Paquete no versionado preservado íntegro. Sin reset/clean/checkout ni instalaciones durante auditoría.
- `git ls-files`: 404 archivos versionados. `rg --files --hidden` excluyendo dependencias/generados: 580 archivos incluyendo 176 del paquete entregado. Sin submódulos gitlink, `.gitmodules`, CI GitHub ni AGENTS.md en repo/ancestros aplicables. Las instrucciones de la solicitud gobiernan.
- El plan `FinSight_Momentum_Implementation_Plan(1).md` NO está en checkout ni attachments disponibles. Se leyeron solicitud, PROMPT_CODEX.md, MOMENTUM_CATALOG.md, ASSET_GUIDE.md y README del paquete. El último renglón de la solicitud pegada está truncado; PROMPT_CODEX.md conserva los tests finales de recuperación.
- Auditoría paralela con lectura de implementaciones e interfaces, no sólo búsqueda de nombres: backend completo (18 módulos, 7465 líneas), web (54 módulos TypeScript y CSS/config), móvil (71 módulos Dart, interfaces y flujos, configuración nativa). Los anexos identifican profundidad y límites. En grandes pantallas se siguieron handlers, lifecycle, validación, APIs, navegación y consumidores; no se afirma lectura línea por línea de decoración o dependencias.

### Inventario por responsabilidad

| Área | Responsabilidad / lectura |
|---|---|
| `financial-dashboard/server` | Express único. `routes.ts` completo, 5248 líneas, auth/finanzas/salarios/invoices/AI/recibos/compras; 17 auxiliares completos. No paquetes backend separados ni colas persistentes. |
| `financial-dashboard/src` | React19, Router7, API fetch, estado local por pantalla, localStorage auth, Recharts, sistema UI Tailwind/light-dark. Todos módulos en anexo web. |
| `mobile/lib` | Flutter provider/AuthStore, REST, RefreshBus, Liquid Glass, navegación/ads/widgets/push, finanzas, PDF/IA/recibos. Todos módulos en anexo móvil. |
| `database` | Schema22tablas + ALTERs y seed demo; no historial numerado. Leído completo y revisados los 4 commits que lo modifican (`e27c077`, `af89548`, `796d0c2`, `5587ce8`). Sin triggers/procedimientos declarados. |
| Infra/scripts | Docker root y tres web/API, dos CloudBuild, nginx proxy remoto, UpgradeNode.ps1, Vite/TS/ESLint/Tailwind/PostCSS, Gradle/Podfile/Xcode/CMake/configs. Leídos antes de ejecutar checks. |
| Tests | Único test real previo `mobile/test/invoice_pdf_test.dart`,2casos. `server/test-server.ts` es un servidor demo que devuelve body, no suite. `mock-db.ts` no está conectado a runtime. |
| Docs | FEATURE_GUIDE.md leído (promete algunas funciones que UI no implementa); READMEs web/móvil obsoletos/parciales; FIREBASE_PUSH_SETUP y docs catálogo leídos. |
| Recursos | SVG/iconos/fonts/screenshots/native catalogs inventariados. Manifest Momentum34badges+4niveles+12UI,168SVG únicos existentes, XML parseado correctamente. `build_assets.py` leído, NO ejecutado ni usado para sustituir entregados. PREVIEW sólo galería. |
| Legacy raíz | TEMP/TMP copias de Dart/Sidebar/patch, Figma JSON vacíos/error, i18n.dart vacío y temp_check.dart aislado sin entrypoint. Clasificados sin incorporar como implementación. Archivos de configuración sensible existentes se excluyen de reproducción en este informe. |

Exclusiones justificadas: node_modules585nodos por lock, Pods/.symlinks, `.dart_tool` salvo resolución, `dist`, `build`, Gradle caches, launchers/plugin registrants generados, PNG/TTF/ICO/keystores y `.DS_Store`. Se inventariaron con `git status --ignored`; no se leyeron binarios/dependencias línea por línea. Configuración ignorada `.env`, key.properties/local.properties y Firebase se revisa sólo por presencia/nombres y aspectos no secretos. No acceso a datos de usuarios/DB/proveedores.

## 2. Arquitectura real, contratos y flujos críticos

### Auth, sesión, correo, recuperación

Web Login/Signup y móvil AuthService -> `/api/login`, `/api/signup` -> `auth.login`, bcrypt10, JWT24h -> Bearer `authenticateToken` -> DB `users`. `sessions` existe pero no la usa JWT; no refresh tokens/MFA/RBAC/reset. JWT tiene id/username/is_pro, no versión; debe conservar claims y revocar por versión comprobada en DB. Google `/api/login/google` valida tokeninfo y crea password aleatoria hasheada **sin guardar proveedor**: las cuentas SSO antiguas son indistinguibles de locales en schema actual. No inferir proveedor a partir de email/hash. Cambio de perfil/contraseña UI es sólo local en ambos clientes, no API real.

`email.ts::sendResendEmail` ya integra Resend; welcome y notification_cron/invoice email son consumidores. Tiene logs de errores con payload proveedor y sin timeout: sanear al reutilizar para reset. Inbound webhook Svix es opcional por configuración previa; no usarlo como verificación de cuentas. Nuevo reset requiere emisión opaca hash-only, TTL30min, rate limits IP/cuenta, URL HTTPS canónica allowlist, POST atómico, notificación postcommit, sin auto-login y tv revocada en todos requests. Legacy credential_kind desconocido necesita clasificación con evidencia o password login exitoso; se bloquea sólo emisión para esa cuenta hasta resolverlo. Nuevo Google no obtiene contraseña local por accidente. Links nativos HTTPS no desplegados: fallback web es indispensable; no fabricar asociaciones/certificados.

### Finanzas y outbox

UI -> ApiService/DataService -> routes CRUD -> mysql2 `db` pool -> response envelope existente -> estado local/RefreshBus. `transactionWriter.createTransactionForUser` comparte `updateBalanceHistory`, `syncInvestmentContribution` y `fetchTransactionWithRelations` en routes; callers transacción normal y confirmación de draft. Otras transacciones se crean en salarios, pagos overdue/individual e invoice payments. Accounts balances, project spent, investment contributions y balance_history dependen de esos callers. Transferencias de clientes son dos POST separados: nunca premiar volumen.

**Riesgo previo**: START/COMMIT/ROLLBACK sobre pool, sin conexión reservada, en transactionWriter y12familias de rutas; helpers también pool. Los callbacks deben compartir la misma conexión y toda escritura outbox debe estar en la misma transacción/statement financiero. Propuesta: contexto asíncrono por request que conserva conexión para bloques legacy, cleanup, pruebas de concurrencia; nuevos módulos usan transacciones explícitas. Outbox vía triggers aditivos para mutaciones de tablas fuente captura también salarios/rutas legacy y evita evaluación/red dentro de la transacción. Fallo INSERT outbox aborta la mutación; fallo evaluador posterior NO cambia operación ya comprometida. Worker reentrante, backoff/fallos visibles y reconciliación de hechos reales. No sumar XP desde payload cliente.

Drafts tienen processing/ready/failed/confirmed/discarded, hash imagen/confirmed_transaction_id. Confirmación hace claim optimista y transactionWriter; upload no otorga logro. `ensureTransactionDraftSchema`, `ensureInvestmentAccountSchema`, `ensureTransactionTransferTypeSchema`, `ensureSalaryAutomationSchema` realizan DDL al vuelo; investment también crea cuentas para backfill. Mover/condicionar bootstrap para rollout explícito y no DDL accidental en transacciones.

IA `handleAiChat` (`/api/ai-chat` y `/api/assistant/chat`) existe, Pro, OpenAI configurado, contexto financiero y reply. No servicio nuevo; crédito se reserva antes de llamada, prioridad Pro, timeout/retry limitado y evento sólo respuesta exitosa. Web AssistantChat abre GPT externo, no evidencia. PDF local móvil real; export completion debe ACK limitado tras éxito con revalidación, nunca screen_view. Proyectos sólo budget/spent/status: tiers25/50/75 quedan deshabilitados por falta de progreso real; Completed es semántica actual y sólo una concesión, sin premio por dinero.

### Pagos/entitlement

PurchaseService stream/restore -> link -> Google purchases.subscriptionsv2 o Apple receipt -> tablas -> is_pro -> `/api/me` -> gating web/Flutter/ads. Stripe checkout/portal -> webhook raw -> users. Anexo Billing detalla flaws y cadena resuelta7.1.1. No RTDN/ACK worker/reconciliación duradera. Unificar OR de fuentes verificadas preservando contratos e identidades; ningún token puede cambiar usuario por POST. Mantener IDs/SKUs existentes como configuración observada, no afirmar productos publicados. IDs1/3 son exenciones Pro **no admin**. Pro manual/desconocido/trial separados de suscriptores pagados. Revocar una fuente no revoca otra válida.

### Telemetría, notificaciones y admin

No analytics pipeline ni métricas de uso actuales. `device_tokens.platform` y proveedor pago no prueban plataforma utilizada. Nueva analytics_events conductual separada de engagement_events dominio; actividad significativa servidor separada de sesión30min. Platform web/android/ios/unknown explícita, datos antiguos unknown. No PII financiera/preguntas/tokens en analytics/admin. Admin owner debe resolver usuario real por CLI/env, autorización por endpoint, acceso/export auditado y consultas paginadas/agregadas. Datos sin cobertura son N/D.

Notificaciones FCM existentes: push_service -> device-tokens con offset/abreviatura timezone -> cron5min -> notification_events unique -> FCM; email Resend paralelo. Sin quiet hours/preferencias Momentum ni períodos IANA. Reusar entrega, añadir dedupe usuario/semana y preferencias; push en background no crea sesión. Mantener links widget `financialboard://widget/*`; no apilar modales.

## 3. Schema, migraciones y política de borrado

Schema22tablas: users/accounts/projects/transactions/expense_categories/expense_subcategories/transaction_drafts/payments/sessions/balance_history/customers/invoices/invoice_items/invoice_payments/investments/investment_contributions/play_subscriptions/app_store_subscriptions/inbound_emails/salary_rules/device_tokens/notification_events. User FKs cascaden mayormente; salary_rules carece FK usuario, invoices->customers RESTRICT y invoice_payments->accounts RESTRICT requieren cuidado en eliminación. Tokens recibos Play/Apple en claro actualmente; nunca exponer en admin/export/log.

Divergencias: investments.account_id+FK+unique e investment_contributions.transaction_id+unique sólo ensureInvestmentAccountSchema (no schema.sql); varios ALTERs duplicate esperados se ignoran; installment script complementa deployments viejos; fix-projects-column trata columna legacy inexistente en schema. initial seed contiene usuarios/transacciones ficticias y se ejecuta si no existe root. No ejecutar seed con upgrade. Nueva runner aditiva con checksums/preflight no debe confundirse con initializeDatabase. DDL MySQL no es rollback transaccional: backup antes de aplicar, estado registrado por statement y compatibilidad verificada con SHOW; tablas nuevas InnoDB/UTC/unique/index/FK cascade. No se conoce versión o motor real producción: verificar local/staging antes rollout. MySQL local ausente, no afirmar migración ejecutada.

Ledger XP inmutable vía append; correcciones compensatorias auditadas, cache reconstruible. Inmutabilidad no impide derecho de borrado: user cascades eliminan registros y secretos sin PII residual. Retención para analytics/inboxes/rate limits explícita. No borrar ledger al rollback de feature.

## 4. Matriz global requisito -> cambio/riesgo/prueba

| Requisito | Actual / consumidores afectados | Cambio propuesto | Riesgo / regresión |
|---|---|---|---|
| 6activaciones250+clear_view50,4niveles,34badges | inexistente; Dashboard/Settings/profile y nuevas API | catálogo versionado completo EN/ES/capacidad/deeplink, motor facts+ledger | 249/250/749/750/1499/1500, claves34, no volumen/gasto/loginXP |
| Semanas3roles+100/20 y meses75 | sin períodos ni ACK | período IANA fijo, set persistido, cap lock usuario, replacements auditados |2dispositivos,duplicados,Free/Proexpiry,cap compartido,0XP nominal vs concedido|
| Revisiones/comeback/grace | sólo datos financieros y opens |snapshot renderizable+confirmación,eligibilidad recalculada,grace1/8semanas configurable|DST,cambio zona,no histórico ficticio,replay/offlinecaducado|
| Outbox/backfill |mutación pool y sin eventos |conexión dedicada,triggers atómicos,worker/reconcile/backfill facts|rollback outbox,failure postcommit,retry,delete/recreate,cache ledger|
| Créditos IA |AI Pro real; sin créditos|grant3Organizer30dflag,reserva/consume/libera,idempotencia|concurrencia,timeout,expiración,Pro primero,retry no cargos ilimitados|
| SDK Google actual |7.1.1; Flutter instalado3.41.6|wrapper compatible8 provisional;9 sin soporte oficial disponible|dependencyInsight/manifestnuevo,offersprecio,pendiente/cancel/restore|
| Verificación/ACK/RTDN |best effort/ausente,AppleJWS decode|validación proveedores,ownership,inboxJWT+worker/reconcile,ORentitlement|forgery,tokenotheruser,replacements,fueraorden,graceholdrevoked,múltiplesfuentes|
| Admin privado métricas reales |ningún rol/pipeline|RBACreal,analytics,contracts/charges y aggregationsporzona/moneda|401/403,filtros/CSVinyección,cohortesinmaduras,D7D30exacto,multiplataforma,N/D|
| Recuperación3clientes |ausente y perfil simulado|32byteshash-onlyTTL30m,mailer,UIneutral,JWTversion,links|requestresetlogin,concurrencia,SSOlegacy,scannersGET,emailfail,URLallowlist|
| Borrado/retención/operación |cascade mayoritario + scripts peligrosos|migración aditiva explícita,sanitización,flags+runbook|ledger/PIIdelete,rollbacksinborrar,revisiónschema,no producción|

## 5. Baseline y limitaciones

Todos scripts fueron leídos antes de checks; no installs ni format/autofix. Config DB local apunta a servicio externo, no es aislada; no se conectó. No mysql/mysqld/docker en PATH. `npm run server`/`dev:full`, scripts de balance/password/migración y Docker/CloudBuild **NO ejecutados** porque boot carga env, muta schema/seed y puede enviar correo/push. No compras/correos reales/dispositivos/PlayConsole/producción.

| Check | Resultado comprobado |
|---|---|
| Git initial/final audit | master19c5651; sólo paquete no tracked |
| Backend esbuild.transform de18ts/js usando paquete instalado | PASS sintaxis (NO typecheck/test/integración) Node24.14.1; no módulos ejecutados; no suite/script servidor previo |
| Web tsc app y node --noEmit --incremental false en copia aislada | PASS/PASS |
| Web Vite --configLoader runner --outDir build-output con API127.0.0.1:9 | PASS; chunks grandes/browserslist viejo |
| Web eslint src json | FAIL previo166errors6warnings; anexo identifica reglas y log |
| Flutter analyze aislado sin pub get |0errores,5warnings,128info; exit2 previo |
| Flutter test --no-pub aislado |PASS2/2,cache/socket permitidos mediante escalación específica |
| Assets |168SVG/34keys XML existentes y sin rutas duplicadas; no sustituye renderFlutter/dispositivo|
| MySQL,release native fresco,store sandbox |NO ejecutado; SDK/servicio/accesos y configuración externa por comprobar|

## 6. Fases, compatibilidad y recuperación

A completada con este informe. B: migraciones explícitas/foundation transaccional/outbox/telemetría/RBAC+tests. C: Billing/entitlements/SDK compatible/worker. D: catálogo/motor/revisiones/créditos/caps/backfill. E: Flutter/React stores/UI/assets/reset (recuperación backend en paralelo como prerequisito de clientes). F: admin vistas reales. G: regresiones integradas/builds/docs/rollout.

Preservar métodos/rutas/envelopes financieros, moneda/signos/frecuencias/estados, JWTclaims Bearer de clientes distribuidos, usuarios/purchases vigentes y fuentes de entitlement, SKUs aliases, raw Stripe webhook, navegación/widget/deeplinks, datos del propietario. Nuevas rutas `/api/engagement`, `/api/auth/*`, `/api/admin` aditivas. RevocaciónJWT requiere mantener guardia aun si se revierte UI; ledger y nuevos snapshots no se borran para rollback. Flags independientes momentum_enabled/momentum_ai_rewards_enabled/admin_analytics_enabled/pagos sin apagar verificación ni recepción compras existentes. Backend y migraciones en staging antes clientes; ampliar cohortes gradualmente con healthchecks.

Bloqueos externos concretos (no bloquean código local): MySQLaislado+versiónproducción; credential_kindlegacy sin evidencia; productos/ofertas/PlayDeveloperAPI/PubSubJWTaudience/serviceaccount/DLQ; Applebundle/appid/roots/credenciales/notifications; secrets Stripe/Resend y remitente verificado; asociaciones HTTPS y certificados propios; pruebas sandbox/dispositivo. Credenciales en archivos legacy versionados requieren revisión/rotación por operador; no se reproducen. Ningún bloqueo justifica datos falsos ni publicación automática.

Fuentes primarias complementarias consultadas: [OWASP recuperación](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html), [MySQL triggers](https://dev.mysql.com/doc/refman/8.0/en/trigger-syntax.html), [MySQL locking reads](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html). Fuentes oficiales de Billing en anexo. El resto de conclusiones se sustenta en rutas/símbolos de este checkout.

## 7. Anexos de lectura, baseline y contratos por aplicación

# Auditoría de React web y configuración — sólo lectura

Fecha: 2026-09-24. Rama/commit/diff inicial son responsabilidad del informe raíz. No se modificó el repositorio. No hay AGENTS.md bajo ../financial-board ni otros directorios del mismo nivel según `find .. -name AGENTS.md` (el agente raíz cubre ancestros). La solicitud adjunta fue leída; este informe corresponde al área web y se combina con auditorías backend, mobile y raíz.

## Cobertura real y exclusiones

Se leyeron implementaciones, props/contratos, handlers, imports y render de todos los 54 módulos TS/TSX/d.ts de src, ambos CSS y el inventario SVG. En páginas extensas se ocultaron únicamente literales className estáticos en algunas lecturas para reducir ruido; toda lógica/JSX/textos fue revisada. Las clases del sistema UI y Layout/Sidebar/TopNavbar se leyeron íntegras. No se confunde listado con lectura. Todos los módulos cubiertos figuran al final.

Se leyeron README (plantilla Vite, no documentación de negocio), package.json, package-lock v3 (585 nodos, manifests resueltos/engines/transitivas relevantes/install scripts), Vite/TS/ESLint/Tailwind/PostCSS configs, index.html, nginx.conf, tres Dockerfiles, cloudbuild.api.yaml, .env.example, public/screenshots/README.txt, app-ads.txt, temp_patch.txt (vacío), fix-existing-balance.js (script peligroso de mutación, no ejecutado). .env sólo inventariado por nombres de variables y presencia; nunca se imprimieron valores. node_modules y outputs dist se excluyeron de lectura de código por ser dependencias/generados; se usan las herramientas ya instaladas sin instalar ni actualizar. Imágenes exportadas/screenshots, SVG voluminosos con imagen, .DS_Store y boilerplate react.svg/vite.svg se inventariaron como assets y no se interpretaron como fuente de lógica ni de capacidades.

## Arquitectura y contratos

- `src/main.tsx`: React StrictMode + createRoot; parche global de fetch redirige localhost:3001 hacia VITE_API_URL. No analytics/lifecycle/cache global.
- `src/App.tsx`: BrowserRouter con rutas públicas /login,/signup,/terms,/privacy,/landing,/guide,/delete-account; /onboarding protegido y nested Layout en / con index Dashboard, analytics, projects, transactions, invoices, invoices/:id, payments, categories, accounts, investments. Sin 404 ni /admin, Momentum o reset. En mount, GET /me actualiza user localStorage una vez, sin notificación reactiva compartida.
- `ProtectedRoute`: comprueba existencia local de token; la protección de datos debe seguir siendo middleware servidor. `Layout`: Sidebar, TopNavbar, Outlet y UpdateProfileModal. Nueva administración debe ir con layout propio fuera de éste.
- Estado financiero por página (useState/useEffect), sin React Query/Redux propio, ningún service worker, cache persistente de datos activa ni cola offline. `utils/storage.ts` es almacén legacy con fixtures y camelCase; no tiene consumidores importados. No reutilizar sus seeds para datos reales.
- `utils/api.ts`: ApiService usa Bearer localStorage, siempre application/json, response.json, 401 limpia token/user y navegación dura /login; CRUD y billing wrappers. resolveApi: env > override persistente `?api=` > /api sólo host finsight.com.mx/www > localhost:3001/api. Query override admite origen arbitrario y env tiene prioridad. Debe blindarse auth/reset ante envío de credenciales/tokens a origen arbitrario; revisar compatibilidad de endpoints de prueba antes de cambiar helper compartido.
- Login POST /login {username,password} espera {success,token,user}; username local y sesión JWT. GIS script oficial cargado dinámicamente y POST /login/google {id_token}; éxito Google entra directo al dashboard (no onboarding local). Signup POST /signup {username,email,password}, mínimo 6 chars + confirm, respuesta mismo contrato y /onboarding. Signup y varios billing paths usan env/fallback directo, no resolveApi. Contratos de clientes distribuidos deben conservarse.
- Onboarding sólo tour 3 pantallas y `localStorage onboarded:<uid>=1`; ni muta backend ni prueba que se crearon cuentas. No equivale a las 6 activaciones.
- Logout TopNavbar y DeleteAccount limpian únicamente token/user; no otro cache. Nuevos stores por usuario deben vaciarse allí y en 401/cambio de cuenta.
- ThemeContext usa localStorage theme y clase dark; no preferencia del OS. I18nContext ES/EN por campo user.language local con cross-tab storage event, locale es-ES/en-US, fallback devuelve key. Landing/Terms/Privacy/Guide/AppCarousel usan diccionarios locales; numerosos labels siguen sólo EN. `utils/date.ts` local Date y en-GB/es-ES; no IANA/períodos fijos servidor.
- UI compartida real: ActionButton, AppCard, DataTableShell, EmptyState, FilterBar, LoadingState, ModalShell, PageHeader, StatCard, StatusBadge, cn. Tailwind, borders/slate/light-dark, backdrop en Layout/Nav/Modal. No wrapper Liquid Glass web formal. ModalShell tiene roles/Escape/backdrop pero no focus trap/restore; apenas exportado, sin consumidor actual. ActionButton disabled/loading/focus ring, LoadingState role=status. No preferencias reduce-transparency; reduced-motion sólo en landing/auth/demo.
- Lock resuelto: React/DOM19.1.1, Router7.8.2 (types legacy @types/react-router-dom5), Recharts3.1.2, TS5.8.3, Vite7.1.4 (Node ^20.19 o >=22.12), Framer Motion12.40, @react-three/fiber9.6.1/Three0.184. Docker Node20-alpine no pin minor. Install hooks sólo bcrypt/esbuild/fsevents en lock, no hooks propios package.

## Flujos completos del lado cliente e interfaces que backend debe preservar

1. Financieras: Accounts CRUD /accounts; transfer hace DOS POST /transactions secuenciales (riesgo parcial preexistente), Transfer con signo -, luego +; no otorgar XP por volumen/transfer. Detalle cuenta obtiene TODAS transactions y filtra mes local. Transactions CRUD /transactions y carga accounts/projects/categories; Expenses negativos, Income positivos, category string más category_id/subcategory_id nullable, project_id nullable. `CategoryPicker` obtiene objeto category/subcategory, texto fallback legacy; Categories CRUD expense-categories y expense-subcategories, normaliza/sort. Capturar eventos canónicos servidor no UI.
2. Payments GET/POST/PUT/DELETE /payments, process-overdue, /credit/installments para cuenta Credit. category ids + string, frecuencia Weekly/Monthly/Quarterly/Yearly, next_date, is_active, project_id=0 legado. Toggle envía registro completo. Pending UI logs financieras completas en consola preexistentes: no copiarlas a telemetry. Datos pueden cambiar por proceso overdue backend; outbox debe seguir caller servidor.
3. Projects CRUD /projects, presupuesto/spent/status Active/On Hold/Completed; permite spent libre desde cliente. No modelo hito/% trabajo real en web; barra spent/budget NO progreso válido para premios. Preservar presupuesto/estado sin fabricar XP monetario.
4. Invoices carga invoices/customers/accounts/projects. Mutaciones /invoices, /invoices/:id, payments/delete. Tax/discount UI porcentajes convertidos a importes antes de POST; servidor recibe importes. InvoiceDetail GET {invoice,items,payments}, edita sólo sent, payments puede incluir transaction relacionado. Delete factura revierte transacciones según contrato. Customer edit UI tiene bug preexistente: guarda siempre createCustomer y estado editingCustomer descartado. No export/PDF/send UI integrado aunque api.sendInvoice existe sin callers.
5. Investments lista y N GET detalle para contribuciones; principal/rate/date y compuesto diario calculado en UI (list estimated_value también usado Dashboard/Analytics), elimina /investments. api.addInvestmentContribution existe sin caller UI. Jamás usar importe como objetivo Momentum.
6. Dashboard GET cuentas/transactions/projects/payments/investments, tolera fallos de opcionales Pro; suma no-inversión + estimated_value, excluye transfers gastos, balanceChange hardcoded0. Analytics (Pro) Recharts line/pie desde balance-history/transacciones, último período agrega inversión; sus pie de ingresos/gastos aún incluyen transfers por signo (divergencia existente). Metrics nuevas admin no deben reutilizar estos KPIs personales.
7. Pro: Sidebar/Analytics/Projects/Invoices/Investments/Payments consideran is_pro O IDs1/3; no roles. Condicional previo a hooks produce errores lint/riesgo de hooks. Tres entrypoints Stripe /checkout en banners/mini/API, redirigen data.url; retorno /payments?upgraded=1 hace /stripe/sync -> /me -> localStorage/reload. Profile cancel usa /stripe/cancel para cualquier is_pro, asume cancelación inmediata, no distingue proveedor. UI hardcodea web MX$200 + tax; landing incluye precios Android235/iOS249 heredados. No inventar precios nuevos ni asumir que marketing demuestra oferta vigente.
8. Recuperación AUSENTE: ningún enlace/página/request forgot/reset, token capture/no-referrer/session revoke cliente. `UpdateProfileModal.handleSubmit` sólo escribe user localStorage y muestra éxito; NO cambia contraseña en API pese a pedir actual/nueva y validar mínimo6. No mantener éxito falso al implementar cambio autenticado; usar endpoint real con current password. SSO necesita información backend, no se puede inferir de web.
9. AI web `AssistantChat` abre un Custom GPT externo, siempre presente incluso login/legal (z1000), sin API consumo ni crédito. No conectar créditos a click externo ni exponer en reset (retirar trackers/widgets de ruta de reset). Receipt/extract API no tiene consumidor web actual; no asumir feature web. Native/backend pueden tenerla.
10. Admin/analytics/push: ninguna ruta, rol, evento de sesión, config consentimiento, webhook, push web ni telemetry de uso propio. Recharts permite construir gráficas reales. Datos auth/backend y nuevas APIs deben proveer role/entitlement/metadata y paginación; UI no puede inventar owner ni deducir plataforma de proveedor.
11. Marketing: Landing lazy LandingHeroScene (Three/canvas WebGL, resources disposed, reduced motion fallback), AppCarousel demos hardcoded etiquetadas demo; jamás importarlos para admin production. Privacy/Terms bilingües declaran IA/notificaciones/dispositivos/correos, pero no son evidencia de implementation. Guía promete export/portal que UI no tiene.

## Requisitos → estado → cambio/riesgo/regresión

| Requisito | Estado y consumidores | Cambio mínimo | Riesgo/regresión |
|---|---|---|---|
| Momentum multiplataforma | No cliente; App/Layout/Dashboard y 7 pantallas contexto | servicio+store por user; rutas resumen/misiones/logros/reviews; SVG manifest y cards reales | logout/401 cache, Free vs Pro, EN/ES, reduced motion/keyboard, 34 keys |
| Revisiones explícitas | GET financieros existentes, ningún ACK | API summary/evidence server + checklist visible + next step; ACK idempotente | no screen_view como dominio, períodos fijados y server timezone |
| Entitlement | is_pro local+IDs1/3; checkout Stripe | conservar checkout/respuesta/me; exponer roles por separado; proveedor en cancel/estado | retorno Stripe, sesión vieja, múltiples fuentes, no admin por ID1 |
| Recuperación | ausente; Profile contraseña fake | rutas públicas sin AssistantChat/analytics; API anon; history token clearing; no auto-login | inválido/expirado/usado, SSO, reenvío, theme/i18n, sesión revocada en 401 |
| Admin | inexistente | /admin layout+server RBAC; query paginada; overview/usage/users/subscriptions/Momentum/health, Recharts | 401/403, ND vs0, fecha/zona/filtros, export seguro |
| Analytics usage | inexistente | client web explícito, sesión30m/foreground; allowlist sin finanzas/token | React StrictMode no dupes, reset excluido, retries event UUID |
| Assets | sólo marketing SVG; paquete Momentum aparte | copiar SVG entregados, resolver key/version/theme/status | todos34, alt contextual, sin reemplazos ni gallery bitmap |

## Baseline seguro comprobado

Scripts revisados antes de ejecutar. No `npm ci`, npm install, autofix ni migraciones. No levantar Express/dev:full: backend startup y env apuntan potencialmente a servicios reales. No ejecutar fix-existing-balance.js: carga .env, autoejecuta UPDATE cuentas sin scope usuario. No Docker build/deploy (npm ci/Cloud Run destino). Nginx /api proxy a Cloud Run preexistente no se usó. Snapshot aislado creado fuera del repo con src/public/configs/package+lock, .env excluido; dependencia node_modules enlazada existente; comandos no generan en node_modules por incremental=false y configLoader runner.

Directorio: `/var/folders/27/k5gzvtvj1s95p2zbrnm1_h7h0000gn/T/finsight-web-baseline-ds8ur95e`.

- `node --version`: v24.14.1; TS5.8.3.
- `node node_modules/typescript/bin/tsc -p tsconfig.app.json --noEmit --incremental false`: exit0.
- `node node_modules/typescript/bin/tsc -p tsconfig.node.json --noEmit --incremental false`: exit0.
- `node node_modules/eslint/bin/eslint.js src --format json --output-file lint-baseline.json`: exit1, 54 files, 166 errores/6 warnings PREEXISTENTES. Reglas: no-explicit-any104; hooks48; no-empty5; refresh3; unused3; ban-ts-comment3; exhaustive-deps6. JSON íntegro guardado sólo temp.
- `VITE_API_URL=http://127.0.0.1:9/api node node_modules/vite/bin/vite.js build --configLoader runner --outDir build-output`: exit0,2931 módulos; index1043.85kB, lazy hero901.32kB. Warnings chunk>500kB y caniuse-lite13meses; no actualización automática.
- Package no contiene test script; no tests funcionales web previos encontrados en src. No afirmación UI browser/device ni backend live. Build nunca llamó APIs financieras/pagos.

## Próximos cambios compatibles

Backend contract+flag antes de componentes. Mantener /login,/signup,/me y Bearer. Preferir módulo reset aislado y no helper genérico sin revisar callers; rutas reset deben excluir todo tracking y GPT externo. Admin guard servidor+layout independiente, no usar ID exemptions como role. Momentum store user-keyed y cleanup central se puede incorporar sin reemplazar estados financieros existentes. Instrumentación client sólo metadata allowlist; eventos financieros siguen backend. Reusar Recharts/UI design, no Three marketing para métricas.

## Lista explícita de archivos src cubiertos

- `financial-dashboard/src/App.css` — leído
- `financial-dashboard/src/App.tsx` — leído
- `financial-dashboard/src/assets/react.svg` — asset inventariado, sin lógica propia
- `financial-dashboard/src/components/AppCarousel.tsx` — leído
- `financial-dashboard/src/components/AssistantChat.tsx` — leído
- `financial-dashboard/src/components/CategoryPicker.tsx` — leído
- `financial-dashboard/src/components/FinSightLogo.tsx` — leído
- `financial-dashboard/src/components/LandingHeroScene.tsx` — leído
- `financial-dashboard/src/components/Layout.tsx` — leído
- `financial-dashboard/src/components/LegalPage.tsx` — leído
- `financial-dashboard/src/components/ProUpgradeBanner.tsx` — leído
- `financial-dashboard/src/components/ProUpgradeMini.tsx` — leído
- `financial-dashboard/src/components/ProtectedRoute.tsx` — leído
- `financial-dashboard/src/components/Sidebar.tsx` — leído
- `financial-dashboard/src/components/TopNavbar.tsx` — leído
- `financial-dashboard/src/components/UpdateProfileModal.tsx` — leído
- `financial-dashboard/src/components/auth/AuthShell.tsx` — leído
- `financial-dashboard/src/components/ui/ActionButton.tsx` — leído
- `financial-dashboard/src/components/ui/AppCard.tsx` — leído
- `financial-dashboard/src/components/ui/DataTableShell.tsx` — leído
- `financial-dashboard/src/components/ui/EmptyState.tsx` — leído
- `financial-dashboard/src/components/ui/FilterBar.tsx` — leído
- `financial-dashboard/src/components/ui/LoadingState.tsx` — leído
- `financial-dashboard/src/components/ui/ModalShell.tsx` — leído
- `financial-dashboard/src/components/ui/PageHeader.tsx` — leído
- `financial-dashboard/src/components/ui/StatCard.tsx` — leído
- `financial-dashboard/src/components/ui/StatusBadge.tsx` — leído
- `financial-dashboard/src/components/ui/index.ts` — leído
- `financial-dashboard/src/components/ui/utils.ts` — leído
- `financial-dashboard/src/contexts/I18nContext.tsx` — leído
- `financial-dashboard/src/contexts/ThemeContext.tsx` — leído
- `financial-dashboard/src/index.css` — leído
- `financial-dashboard/src/main.tsx` — leído
- `financial-dashboard/src/pages/Accounts.tsx` — leído
- `financial-dashboard/src/pages/Analytics.tsx` — leído
- `financial-dashboard/src/pages/Categories.tsx` — leído
- `financial-dashboard/src/pages/Dashboard.tsx` — leído
- `financial-dashboard/src/pages/DeleteAccount.tsx` — leído
- `financial-dashboard/src/pages/Guide.tsx` — leído
- `financial-dashboard/src/pages/Investments.tsx` — leído
- `financial-dashboard/src/pages/InvoiceDetail.tsx` — leído
- `financial-dashboard/src/pages/Invoices.tsx` — leído
- `financial-dashboard/src/pages/Landing.tsx` — leído
- `financial-dashboard/src/pages/Login.tsx` — leído
- `financial-dashboard/src/pages/Onboarding.tsx` — leído
- `financial-dashboard/src/pages/Payments.tsx` — leído
- `financial-dashboard/src/pages/Privacy.tsx` — leído
- `financial-dashboard/src/pages/Projects.tsx` — leído
- `financial-dashboard/src/pages/Signup.tsx` — leído
- `financial-dashboard/src/pages/Terms.tsx` — leído
- `financial-dashboard/src/pages/Transactions.tsx` — leído
- `financial-dashboard/src/types/expense.ts` — leído
- `financial-dashboard/src/utils/api.ts` — leído
- `financial-dashboard/src/utils/categoryIcons.tsx` — leído
- `financial-dashboard/src/utils/date.ts` — leído
- `financial-dashboard/src/utils/storage.ts` — leído
- `financial-dashboard/src/vite-env.d.ts` — leído


---

# Auditoría móvil de sólo lectura (2026-09-24)

## Alcance y método

Sin modificación deliberada del repositorio. `git status --short -- mobile` vacío al terminar. Se leyó la solicitud adjunta. No se encontró AGENTS.md aplicable con búsqueda fuera de node_modules/build/Pods/.git. Se inventarió `mobile` con `rg --files`, `find` de directorios y lockfiles/configuración. Hay **71 módulos Dart propios en lib**, más un test Dart, launchers C++/Swift/Kotlin y recursos nativos. Se leyeron todas las interfaces de módulos; implementaciones completas de servicios/modelos/estado/Liquid Glass/utilidades/principales widgets; en screens grandes se siguieron lifecycle, APIs, validaciones, mutaciones, callbacks, navegación y consumidores, con lectura focalizada de widgets decorativos (no afirmación de haber leído cada línea de las ~32k líneas de UI).

`purchase_service.dart` y `pro_widgets.dart` se coordinaron con audit_billing, que los leyó a profundidad. Sus consumidores en main, settings, DataService, AuthStore y pantallas Pro se revisaron aquí.

Exclusiones justificadas: `mobile/build`, android/build/.gradle/.kotlin, ios/build/Pods/.symlinks, `.dart_tool` outputs excepto package_config/package_graph para baseline, carpetas ephemeral y generated_plugin_registrant/generated_plugins generados; PNG/TTF/ICO y catálogos de imágenes se inventariaron sin tratarlos como fuente. `lib/dummy.txt,temp.txt,i18n_tmp_line.txt` son restos no importados/no Dart; no participan compilación. `mobile/tools` no contiene scripts inventariados. No pub get, pod install, formatter, autofix, migración ni acceso a API de aplicación.

## Arquitectura y flujos

- `main.dart::main` configura StoreKit1 por compatibilidad backend verifyReceipt, ads async, `FinancialBoardRoot` (providers AuthStore, LangStore, ThemeModeStore, RefreshBus), luego widget bridge/FCM. `MaterialApp` light/dark, EN/ES, sin Router externo. `AppGate` token→HomeShell y overlay biométrico; sin token→LoginScreen.
- `HomeShell`: bottom tabs Analytics/TransactionsV2/Dashboard/Payments/AccountsNew. Navigator anidado `/root`, `/calendar`, `/ai-chat`, `/investments`, `/projects`, `/invoices`; categorías/settings/guide por Navigator superior. Main usa transactions_v2, el antiguo transactions_screen es legado no importado; accounts_screen reexporta/subclasifica AccountsScreenNew sin consumidores encontrados. AccountSummary es anterior sin importadores; AccountListSummary es actual.
- `ApiClient`: base define API_BASE_URL; release `https://api.finsight.com.mx`, debug emulator/localhost. Bearer token explícito por instancia; timeout15s; upload90s; decodifica JSON y errores `{message|error}`, imprime body sólo debug. No cliente singleton, refresh token, middleware401 ni offline queue. Tras POST/PUT/PATCH/DELETE exitoso llama RefreshBus; ignora únicamente ai-chat y device-tokens. **Telemetría/engagement necesitan exclusión para no provocar reload financiero a cada ACK/evento**. No alterar envelopes financieros; cada consumidor espera List o objeto plano.
- LoginScreen/SignupScreen→AuthService `/api/login` y `/api/signup`→token→AuthStore.setToken→SharedPreferences.auth_token→AppGate. Signup mínimo6 caracteres/confirmación. AuthStore decodifica claims id/is_pro/username sin validar expiración local; servidor sigue siendo autoridad. BiometricService usa local_auth; logout normal con biometría **bloquea** pero retiene token; logout(force:true) borra. `is_pro_local` global sobrevive logout y cambio usuario, OR con flag servidor. `isProOrExempt` contiene IDs1/3. Esto no es RBAC ni debe reutilizarse para admin. PurchaseService/main manejan entitlement; ver informe billing.
- HomeShell arranque→purchase.initialize→play/sync (en cualquier plataforma)→iOS appstore/sync→stripe/sync→me.is_pro. Play fallo exterior salta refresco siguiente por catch amplio. No listener de foreground salvo comprobación de lifecycle para ads. Momentum y telemetría deben observar foreground, no contar push en background como uso.
- Finanzas: screens/forms/quick_create→DataService→ApiClient→REST→model parsing→RefreshBus global+ticks específicos→reload listas/dashboard. AccountDetail también lee todas cuentas/transacciones y filtra local. TransferFunds crea dos transacciones secuenciales; no introducir XP por cualquiera de esas operaciones. Payments crea regulares/installment, actualiza/elimina y procesa overdue/individual; calendar calcula ocurrencias y salarios, exporta link Google Calendar. Settings puede reparar transfers, reconstruir balance history y editar salary rules.
- Categorías: ManageCategories y CategoryPicker CRUD `/expense-categories` y `/expense-subcategories`, IDs canónicos; transacciones también conservan texto legacy category, category_id/subcategory_id; UI fallback por nombre. Budgets de subcategoría son Pro; cuentas/categorías básicas Free. Charts financieros usan fl_chart y datos reales; no son analytics de comportamiento.
- Proyectos: modelo Project es id,name,description,budget,spent,status,start/end. spent es campo libre en formulario; cards calculan spent/budget. No tasks/milestones/campo progress. **No premiar porcentajes de gasto**. Tiers25/50/75 deben capability-disabled con motivo. Completed puede considerarse semántica existente sólo con revalidación/dedup y sin afirmar progreso financiero real; nunca premiar toggle repetido.
- Inversiones: get list/detail/contributions y CRUD, cálculo estimado local compuesto diario si no existe estimate; modelo Investment reside dentro de investments_screen. No usar aportaciones/dinero como criterio XP.
- Recibos sí implementados: ImagePicker cam/gallery→limite8MiB→multipart `/transaction-drafts/receipt` (422/503 retornan estado estructurado)→GET draft→edición explícita→PATCH draft→confirm→transacción→RefreshBus. Pro gated. Confirmation del backend es evento confiable; upload/screen view no es éxito. Discard best effort. Asset/body de recibo no debe ir en telemetry.
- IA sí implementada: AiChatScreen mantiene sesiones/preguntas localmente en SharedPreferences por usuario, envía últimas20 messages `/api/ai-chat`, respuesta `reply`. UI actualmente exige Pro. Créditos requieren permitir acceso según saldo servidor y conservar Pro como prioridad; no exponer prompts en analytics.
- Exports sí existen: TransactionsV2 `_downloadReport`→filtros/config→`_buildReportPdf`→Printing.layoutPdf/sharePdf; invoice_pdf.dart→PDF con fuentes embebidas→DataService.emailInvoice→`/invoices/:id/email`. Export es actualmente local sin evento backend; ACK allowlist post-éxito con evidencia/snapshot y dedup necesario. Facturas y customers Pro, se cargan invoices/customers/accounts/projects; los callbacks update/pay/delete respetan envelopes actuales.
- Push: Firebase initialize, background handler sólo initialize; foreground FLN, notification open→PushAction(targetType,int targetId), queue inicial→HomeShell payment/project/subcategory. Token en SharedPreferences y debugPrint (debe sanearse), registerDeviceToken auth→timezone offset y `DateTime.timeZoneName` (**abreviatura, no IANA garantizada**). `_lastRegisteredKey` no incluye usuario; riesgo cambio cuenta. No preference/quiet hours/dedup semanal ni ACK presented/seen; backend cron debe ser autoridad.
- Deep links: HomeWidget bridge reconoce financialboard://widget/create-transaction y scan-receipt; legado create-recurring-payment redirige scan receipt. iOS CFBundleURLSchemes=financialboard. Android abre actividad explícita con URI widget; **no intent filter HTTPS de App Links**. iOS no associated-domains ni universal links. No reset routing. Fallback canónico web debe funcionar, asociaciones nativas externas no pueden afirmarse desplegadas.
- Recovery inexistente en móvil: login no forgot link; AuthService sólo login/signup; `UpdateProfileScreen::_save` valida current/new pero contiene comentario API no implementada y **sólo guarda JSON perfil local**, mostrando éxito. No reutilizarlo como cambio real. Añadir pantallas request/reset, URL allowlist, sin autologin y logout(force:true) tras reset, cuidando que no haya tokens en telemetry/logs.
- Persistencia estado: Auth, lenguaje, tema global SharedPreferences; AI/chat/savings-goal por usuario; savings goal sólo local y **no elegible como evidencia servidor multiplataforma**. No DB local sincronizada, cola o métricas propias. Debe añadirse store separado por usuario, reset al logout/cambio, stable ACK IDs y límite temporal del servidor.

## Diseño y localización

Se leyeron los 12 módulos Liquid Glass (barrel + tokens, glass, card, button, form, modal, metric, badge, empty/loading, background, header). Azul ya#2563EB; warning#F59E0B; success actual#16A34A (Momentum puede definir mint#22B66F/lavender#7C83FD sin recolorear global). Radius10/14/18/24/32,pill999; spacing4/8/12/16/24/32/40; blur8/14/20; superficies dark/light. Reusar LGGlassCard/LGSolidCard/LGBottomSheetShell/LGButton/LGForm, Semantics para SVG/XP/status. `flutter_svg` ya existe y lock2.2.3; puede renderizar assets SVG por key; sin Lottie requerido. AppTheme Material3 y Liquid Glass; I18n.t usa watch, tr usa read para callbacks/overlay, fallback en→key. Algunas screens/guide/PDF todavía tienen inglés hardcoded preexistente. Nuevo alcance debe ser EN/ES completo. No infraestructura reduce-motion explícita; MediaQuery.disableAnimations para unlock.

Ads: AdMobAdUnits elige reales release/tests debug y sólo Android/iOS. Interstitial controller cuenta mutaciones exitosas por usuario en SharedPreferences, máximo3/sesión, cooldown5min, 650ms retraso, lifecycle resumed y rutas permitidas. No reinterpretar contadores ads como actividad significativa/XP. Momentum modal debe no competir con modal/purchase/ads.

## Nativo, manifests y lockfiles

Leídos README, FIREBASE_PUSH_SETUP (algunos textos de estado obsoletos), pubspec, lock (135 paquetes resueltos), analysis_options/devtools, Android Gradle3archivos/gradle.properties/wrapper, manifests main/debug/profile y network security/widget provider; AppDelegate/MainActivity, widget Kotlin+Swift, iOS Info/entitlements/Podfile/Podfile.lock/project build settings/scripts; macOS launcher/config/entitlements/Podfile y tests; Linux/Windows runner interfaces+implementaciones/CMake, Flutter-web HTML/manifest. Plantillas desktop conservan nombres `mobile`/`com.example.mobile`, fuera de publicación Android/iOS/web solicitada.

Version pubspec1.0.8+9 (README afirma1.0.1+2 obsoleto); Android versionCode51 fijo, package com.finsight.finsight, namespace com.example.mobile, minSdk24, NDK27.0.12077973, AGP8.9.1,Kotlin2.1.0,Gradle8.11.1,Java11 target, desugar2.1.4. Root Gradle pin androidx.glance1.1.1 por home_widget1.+; no Billing force actual. Release signing requiere key.properties en configuración: no imprimirlo/copiar secretos. iOS bundle mx.com.finsight, widget mx.com.finsight.widget, iOS15, AppGroup group.mx.com.finsight; Runner entitlements no aps-environment ni associated-domains, widget entitlement raíz vacío frente archivo bajo widget con appgroup (configs diferentes: validar dispositivos). Podfile.lock Firebase12.6.0 y GoogleAds13.2.0; StoreKit wrapper0.4.8+1. Dart relevantes: provider6.1.5+1,http1.6.0,shared_preferences2.5.4,intl0.20.2,flutter_svg2.2.3,fl_chart1.1.1,firebase_core4.3.0,messaging16.1.0,local_notifications19.5.0,home_widget0.8.1,pdf3.11.3,printing5.14.2,local_auth2.3.0,google_ads8.0.0,image_picker1.2.2. Billing detallado agente: in_app_purchase3.2.3/android0.4.0+8 nativo7.1.1.

## Baseline comprobado

SDK existente Flutter3.41.6/Dart3.11.4. Copia aislada `/tmp/finsight-mobile-baseline` de lib/test/assets/pubspec/lock/analysis_options + package_config/package_graph **existentes**, rootUri mobile relativo a copia. No pub get ni fuentes generadas sobre repo.

1. `CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true /Users/elias/Documents/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine` en copia: **exit2, 0 errors, 5 warnings,128 info**. Log `/tmp/finsight-mobile-baseline-analyze.log`. Warnings: calendar:78 innecesario!, payments:593 variable per sin uso, legacy transactions:201 innecesario!, :486fmt sin uso, AuthService import foundation sin uso. No se corrigieron durante auditoría.
2. `CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true /Users/elias/Documents/flutter/bin/flutter test --no-pub --reporter expanded` en copia, con escalación revisada para SDK cache lock y sockets de test: **exit0, 2/2 pasaron**, `invoice_pdf_test.dart` money formatting y PDF real `%PDF`. Log `/tmp/finsight-mobile-baseline-test.log`.
3. Intentos aislados iniciales fallaron por lockfile SDK sandbox, después metadata rootUri /tmp vs /private/tmp y package_graph ausente en copia; se corrigió **sólo metadata de copia**, no errores del producto. No clasificar esos intentos como bugs de fuente. No builds nativos frescos ni compras sandbox/device tests ejecutados por este agente; requerir Gradle dependencyInsight/release manifest y build iOS posterior en fase billing/integración. Xcode/Android SDK disponibles según Flutter doctor disparado por error herramienta, pero no se tomaron como prueba dispositivo.

## Matriz compacta / fases propuestas

| Requisito | Actual / cambio | Consumidores / riesgo | Regresión |
|---|---|---|---|
| Estado Momentum común | inexistente→model/service/store separado API engagement | main/providers, Dashboard después resumen, RefreshBus (evitar loops), account switch | retry/offline/cache user, foreground/período, auth401 |
| Misiones/34 badges/assets | nada activo→catálogo backend + SVG manifest | Mission sheet, Profile/Settings Logros, 7strips; no reward client |34keys,ES/EN,dark/light,semantics/large text|
| Revisiones | charts financieros existentes→snapshot del servidor renderizado y confirmación | reusable review UI, Free capabilities; no screen_view recompensa |evidence stale/no datos/explicit action/expired period|
| Telemetría | ningún pipeline propio→analytics service lifecycle+allowlist | Navigator observer/tab events+mutation successful callbacks; exclude API bus |30min/session,platform native exacta,PII absent/offline dedup|
| Créditos IA | Pro gate→saldo API, prioridad Pro | AiChatScreen, backend ai-chat, no preguntas metadata |free 3credits,release failure,concurrent/idempotent|
| Push Momentum | FCM real pero básica→dedup/preferences/cooldown server y target engagement | push_service/main, no nested unlock modals |cold/warm/resume/seen/user switch|
| Reset | ausente; cambio password local falso→auth endpoints y request/reset UI | AuthStore forced logout, login/signup consistency, nativo links |neutral/expired/used/in-flight switch/ES/EN|
| Billing | nativo7.1.1 y localPro permissivo→plan agente billing |main sync/DataService/AuthStore/store checkout|pending/restore/cross-user/Apple/Stripe|

Preservar REST financiero, token claims existentes/authorization, navegación nativa widget existente, light/dark EN/ES, todos recibos/PDF/ads/proveedores. Additive state no modifica finanzas. Flags separados server; no crear autoridad de XP/Pro cliente. Rollback cliente debe seguir leyendo envelopes antiguos; backend ledger preservado. Pruebas UI y compras reales quedan externas hasta ejecución demostrable; no bloqueo para código local.

## Inventario explícito Dart revisado
- `mobile/lib/i18n.dart`
- `mobile/lib/lang_store.dart`
- `mobile/lib/liquid_glass/lg_background.dart`
- `mobile/lib/liquid_glass/lg_button.dart`
- `mobile/lib/liquid_glass/lg_card.dart`
- `mobile/lib/liquid_glass/lg_empty_loading.dart`
- `mobile/lib/liquid_glass/lg_form.dart`
- `mobile/lib/liquid_glass/lg_glass.dart`
- `mobile/lib/liquid_glass/lg_metric_card.dart`
- `mobile/lib/liquid_glass/lg_modal_shell.dart`
- `mobile/lib/liquid_glass/lg_page_header.dart`
- `mobile/lib/liquid_glass/lg_status_badge.dart`
- `mobile/lib/liquid_glass/lg_tokens.dart`
- `mobile/lib/liquid_glass/liquid_glass.dart`
- `mobile/lib/main.dart`
- `mobile/lib/models.dart`
- `mobile/lib/screens/account_detail_screen.dart`
- `mobile/lib/screens/accounts_screen.dart`
- `mobile/lib/screens/accounts_screen_new.dart`
- `mobile/lib/screens/ai_chat_screen.dart`
- `mobile/lib/screens/analytics_screen.dart`
- `mobile/lib/screens/calendar_screen.dart`
- `mobile/lib/screens/dashboard_screen.dart`
- `mobile/lib/screens/guide_screen.dart`
- `mobile/lib/screens/investment_detail_screen.dart`
- `mobile/lib/screens/investments_screen.dart`
- `mobile/lib/screens/invoices_screen.dart`
- `mobile/lib/screens/lock_screen.dart`
- `mobile/lib/screens/login_screen.dart`
- `mobile/lib/screens/manage_categories_screen.dart`
- `mobile/lib/screens/payments_screen.dart`
- `mobile/lib/screens/project_detail_screen.dart`
- `mobile/lib/screens/projects_screen.dart`
- `mobile/lib/screens/receipt_scan_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/screens/signup_screen.dart`
- `mobile/lib/screens/transactions_screen.dart`
- `mobile/lib/screens/transactions_v2_screen.dart`
- `mobile/lib/screens/update_profile_screen.dart`
- `mobile/lib/services/api.dart`
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/services/biometric_service.dart`
- `mobile/lib/services/data_service.dart`
- `mobile/lib/services/purchase_service.dart` (profundidad delegada audit_billing; callers revisados aquí)
- `mobile/lib/services/push_service.dart`
- `mobile/lib/services/receipt_image_service.dart`
- `mobile/lib/services/widget_service.dart`
- `mobile/lib/state/auth_store.dart`
- `mobile/lib/state/refresh_bus.dart`
- `mobile/lib/theme.dart`
- `mobile/lib/theme_mode_store.dart`
- `mobile/lib/utils/category_icons.dart`
- `mobile/lib/utils/format.dart`
- `mobile/lib/utils/invoice_pdf.dart`
- `mobile/lib/utils/links.dart`
- `mobile/lib/utils/savings_goal.dart`
- `mobile/lib/widgets/account_list_summary.dart`
- `mobile/lib/widgets/account_summary.dart`
- `mobile/lib/widgets/admob_ad_units.dart`
- `mobile/lib/widgets/category_picker.dart`
- `mobile/lib/widgets/kpi_card.dart`
- `mobile/lib/widgets/new_transaction_dialog.dart`
- `mobile/lib/widgets/non_pro_banner_ad.dart`
- `mobile/lib/widgets/non_pro_interstitial_ad_controller.dart`
- `mobile/lib/widgets/onboarding_coach.dart`
- `mobile/lib/widgets/pro_widgets.dart` (profundidad delegada audit_billing; callers revisados aquí)
- `mobile/lib/widgets/project_summaries.dart`
- `mobile/lib/widgets/quick_create_dialogs.dart`
- `mobile/lib/widgets/recent_transactions.dart`
- `mobile/lib/widgets/subcategory_budget_summary.dart`
- `mobile/lib/widgets/upcoming_events.dart`
- `mobile/test/invoice_pdf_test.dart` (completo, baseline ejecutado).


---

# Auditoría Billing — sólo lectura, 2026-09-24

Subinforme para integrar en `docs/implementation/repository-audit.md`. Ningún archivo del repositorio, lockfile, schema ni dependencia ha sido modificado por este agente. No se ha arrancado el servidor, conectado a MySQL/proveedores, comprado, publicado ni aplicado migraciones. Se leyeron la solicitud adjunta completa y los módulos enumerados abajo; no se afirma cobertura de módulos delegados a otros agentes.

## Cobertura de lectura e interfaces

- Completo: `financial-dashboard/server/stripe.ts`, `server/index.ts`, `server/db.ts`; `mobile/lib/services/purchase_service.dart`, `mobile/lib/widgets/pro_widgets.dart`, `mobile/lib/state/auth_store.dart`; manifests `financial-dashboard/package.json`, `mobile/pubspec.yaml`; configuraciones `mobile/android/{build.gradle.kts,settings.gradle.kts,gradle.properties,gradle/wrapper/gradle-wrapper.properties,app/build.gradle.kts}`; `financial-dashboard/src/components/ProUpgradeBanner.tsx`.
- Lectura profunda de bloques y consumidores relevantes: `server/routes.ts` Apple helpers 165–370, acceso 1430–1503, perfil/Billing 4950–5248; `mobile/lib/services/data_service.dart` métodos Billing 670–789; `mobile/lib/main.dart` init de compras/sync 203–231 y gating de navegación; `mobile/lib/screens/settings_screen.dart` restore 330–350; `financial-dashboard/src/pages/Payments.tsx` retorno Stripe 55–80; schema `database/schema.sql` users y tablas Play/Apple 350–384.
- Lockfiles inspeccionados por resolución (no código vendorizado): `financial-dashboard/package-lock.json`, raíz `package-lock.json`, `mobile/pubspec.lock`, `mobile/ios/Podfile.lock`, `mobile/.dart_tool/package_config.json`. Configuración determinante y puntos específicos del wrapper resuelto leídos en caché: Android plugin `pubspec.yaml`, `android/build.gradle`, compra/ACK de `lib/src/in_app_purchase_android_platform.dart`, tipos GooglePlayPurchaseParam/ProductDetails. No se leyó toda la dependencia vendorizada.
- Salidas generadas existentes inventariadas y consultadas como evidencia histórica: `mobile/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`, dependencias lint release, AAB release existente. NO son builds verificados en esta sesión.
- Búsquedas por callers de PurchaseService/ProBlock/UpgradeBanner, `activatePro`, métodos sync/link; búsqueda repo de RTDN/PubSub/server notifications e intermediarios de compras: no se encontró RevenueCat/Adapty, RTDN ni App Store Server Notifications. Cron existente no procesa Billing. Revisión global de cron/auth/finanzas corresponde al agente principal.
- Se consultaron sólo **nombres** de variables de env, nunca valores. No se imprimieron credenciales, keystore, receipts ni tokens.

## Flujo móvil y SDK reales

`main.dart` shell inicializa singleton PurchaseService y hace `syncPlay()` en todas las plataformas, `syncAppStore()` en iOS, después `stripeSync()` y `/api/me`. Un error en Play bloquea el resto de ese bloque; Stripe tiene catch interno. Pro se aplica a AuthStore y a gating de funciones/anuncios. El singleton guarda el AuthStore/messenger de la primera suscripción; no se dispone/cancela al logout. `AuthStore` conserva `is_pro_local` global sin partición de usuario ni limpieza en logout; `isPro` es OR de local/server/JWT. El shell sí borra localPro si consigue `/api/me` false, pero existe ventana de filtración al cambiar cuenta/offline.

`ProBlock` y `UpgradeBanner` llaman `purchasePro`. Consumidores incluyen dashboard, proyectos y detalle, investments y detalle, facturas, analytics, IA, main/navigation; ProMiniChip también categorías y transacciones. `purchasePro` consulta todos los IDs de ambas plataformas, escoge por prioridad de ID usando mapa que colapsa ofertas del mismo producto a la última, invoca PurchaseParam genérico y `buyNonConsumable` (correcta categoría para suscripción), ignorando el bool de lanzamiento. No hay selección de basePlan/oferta/precio; no applicationUserName obfuscado. **El wrapper sí propaga automáticamente el offerToken del GooglePlayProductDetails escogido**, por lo que no es correcto decir que no se envía ningún offerToken; el problema es la selección/UI/identidad.

Compra purchased/restored → `/api/play/link` o `/api/appstore/link` → `completePurchase` si pendingCompletePurchase → `/api/me` → local/server Pro. Los métodos link DataService devuelven void y descartan `state/is_pro`, por lo que un HTTP 200 con verificación fallida UNKNOWN se ACKea. Pending se muestra con texto App Store incluso Android; errores completos se muestran/loguean sin saneado consistente; ninguna cola de entrega/reintento durable. `completePurchase` en Android wrapper llama acknowledgePurchase salvo que su objeto local ya indique acknowledged. No consume suscripciones. Restore existe en servicio para Android pero **sólo se expone en UI iOS**. Listener al iniciar puede recuperar compras previas, pero no hay prueba de app kill/dispositivos.

IDs observados, sin afirmar configuración de consolas: iOS `7T8M8X5R46`, `finsight_pro_monthly`, `finsight_monthly`; Android `finsight_monthly`, `finsight_pro_monthly`; package `com.finsight.finsight`. No inventar ni retirar aliases que pudieran corresponder a usuarios distribuidos. Prices en Pro widgets hardcoded MX$249/iOS y MX$235/Android, mensual y EN; deben provenir de store y estar localizados. Web banner también hardcodea MX$200+tax mientras checkout usa env/fallback USD1000 minor units; no hay evidencia de igualdad.

Versiones comprobadas:

| Capa | Declarado/resuelto real |
|---|---|
| Flutter SDK local (metadata de cache) | 3.41.6 / Dart 3.11.4 |
| pubspec | in_app_purchase ^3.1.11; storekit ^0.4.8+1 |
| pubspec.lock y package_config | core 3.2.3; Android 0.4.0+8; interface 1.4.0; StoreKit 0.4.8+1 |
| Android wrapper build.gradle | com.android.billingclient:billing:7.1.1 |
| Manifest release preexistente | com.google.android.play.billingclient.version = 7.1.1 |
| Android app | minSdk24; AGP8.9.1; Gradle8.11.1; Kotlin2.1.0; NDK27.0.12077973 |
| wrapper Android 0.4.0+8 | AGP8.13.1 / Java17 |
| iOS | Podfile iOS15; local StoreKit pod via symlink (0.0.1 pod label, not Dart plugin version) |
| Node lock | Stripe16.12.0; googleapis139.0.0; google-auth-library9.15.1; mysql2 3.22.3 |

## Backend y persistencia

No intermediario único existente: integración directa Stripe, Google API y Apple receipt/JWS. `users.is_pro` es cache boolean sin procedencia; columns Stripe guardan un contrato/status/expiry. `play_subscriptions` almacena token en claro con unique global + FK user cascade; `app_store_subscriptions` unique original_transaction_id + receipt_data MEDIUMTEXT + FK user cascade. No ledger financiero de cobros/refunds, moneda/importe/periodicidad, delivery/ACK jobs, token encryption o durable webhooks. Esas métricas están N/D, no cero.

Play: `/api/play/link` autenticado exige campos truthy; `verifyPlaySub` llama `purchases.subscriptionsv2.get` con package env o default y ADC scope androidpublisher; errores se reducen a ok:false y aún se persiste UNKNOWN y responde success. **expiryTime RFC3339 se convierte con Number**, casi siempre null. No validate product allowlist/respuesta, entorno testPurchase, identidad obfuscatedAccount, linkedPurchaseToken/reemplazos/estado concreto. Upsert de token no cambia user_id, pero tampoco rechaza explícitamente otro propietario y puede actualizar datos de registro ajeno. `/api/play/sync` recorre tokens sólo al pedirlo cliente, sin reconciliación programada. Sin ACK backend.

Apple: `verifyAppStoreReceipt` primero intenta `normalizeStoreKit2Transaction`; **decodifica payload JWS sin firma/cadena/certificados/bundle/app/env/ownership** y devuelve status0. Legacy verifyReceipt sí contacta Apple con shared secret, modos auto/sandbox/production, 21007/21008 fallback. Summary filtra por productId arbitrario del cliente y expiry/revocation; no bundle/product allowlist. Upsert en link/sync escribe `user_id=VALUES(user_id)` para original_transaction_id existente: transferencia entre cuentas posible. JWT replay y verificación local no pueden actualizar renovaciones futuras; no notifications/server reconciliation.

Stripe: checkout y portal llaman API directa; subscription mode mensual conserva metadata user_id. Sync crea customer si falta, lista hasta100 subscriptions y escribe is_pro según cualquiera active/trialing mientras metadata queda la primera, pudiendo divergir. Webhook raw antes de JSON parser: signature verificada sólo si STRIPE_WEBHOOK_SECRET presente; si falta acepta JSON sin verificación incluso producción. Sin dedupe/durable inbox/orden/retries: checkout.completed concede true asumiendo active sin fetch; updates/deleted setPro directo; no cobros/refunds. Cancel endpoint cancela inmediatamente y pone false; account delete reutiliza ese comportamiento. No cambiarlo a cancel-at-period-end sin conservar contrato/semántica de callers.

`refreshUserProFlag` en routes ORs proveedores, pero Stripe tiene escrituras separadas que lo pisan. Stripe status active/trialing O cualquier expiry futura concede; Play ACTIVE O cualquier expiry futura concede (hold/paused/revoked futuro erróneo). `userIsPro` usa cache stale, `/api/me` tampoco recalcula. Por orden móvil, Stripe sync puede quitar suscripción Google/Apple legítima y crear customers Stripe innecesariamente. ID1/3 siempre Pro por exención existente; **no son roles admin**. Se deben preservar como grants legacy explícitos auditados y separados de paid/trial, sin inferir propietario/admin. Endpoint `/api/pro/activate` permite a cualquier usuario autenticado marcar is_pro true sin prueba; caller DataService.activatePro existe, sin invocaciones activas encontradas: conservar ruta pero retirar concesión no verificada y devolver explicación de actualización/verificación.

`db.ts` inicializa pool al importar pero consulta/red al ejecutar. `index.ts` boot ejecuta schema y seed automáticamente; schema mezcla CREATE/ALTER no idempotentes tolerando errores. Por eso no se arrancó como baseline. Migración nueva debe ser aditiva/explicit CLI, no aplicarse a env existente durante auditoría.

## Fuentes oficiales revalidadas el 2026-09-24

- [Google release notes](https://developer.android.com/google/play/billing/release-notes): estable actual 9.1.0 publicada 2026-06-18. [Deprecation](https://developer.android.com/google/play/billing/deprecation-faq): Billing7 publicaciones/updates hasta2026-08-31, extensión hasta2026-11-01; Billing8 hasta2027-08-31 y Billing9 hasta2028-08-31. No evidencia de extensión aprobada en Play Console.
- [Migración9](https://developer.android.com/google/play/billing/migrate-gpblv9): requiere adaptar APIs removidas; no basta sobreescribir dependency nativa del plugin.
- [Changelog oficial Flutter core](https://pub.dev/packages/in_app_purchase/changelog): 3.3.0 cambia Android a ^0.5.0; actual3.3.1. [Android changelog](https://pub.dev/packages/in_app_purchase_android/changelog): 0.5.0 sube Billing7.1.1→8.0.0; actual0.5.3, desde0.5.0+1 exige Flutter3.44/Dart3.12. [Gradle oficial](https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/android/build.gradle.kts) aún declara8.0.0; [pubspec](https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/pubspec.yaml) confirma mínimos actuales. **Ruta provisional compatible a investigar tras checkpoint** core3.3.1 + wrapper0.5.0 (último compatible con SDK instalado según changelog), fijar resolución real y verificar Gradle/manifest. Wrapper9 no publicado evidenciado; no decir migrado9; no force. No se eligió/instaló versión durante auditoría.
- [Flutter API/README](https://pub.dev/packages/in_app_purchase): listener temprano, validar restore, completePurchase después de validación/entrega, cambio plan mediante ChangeSubscriptionParam; warning sobre declarar Billing directo. Definir ACK backend como autoridad Google y hacer Android cliente omitir completePurchase tras ACK backend confirmado; conservar completePurchase iOS para terminar transacciones. Clientes antiguos pueden ACKear también: backend debe consultar acknowledgementState/idempotencia y tolerar carrera.
- [Google security](https://developer.android.com/google/play/billing/security): verificación server y ownership antes entitlement; token único; atender linkedPurchaseToken; pending no acceso; ACK después concesión y antes plazo (normal3d). [Backend](https://developer.android.com/google/play/billing/backend): sincronizar ciclo RTDN+API, dedupe messageId. [RTDN](https://developer.android.com/google/play/billing/rtdn-reference): notificación impulsa consulta, no prueba standalone. [Subscriptions](https://developer.android.com/google/play/billing/subscriptions) y [APIv2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2) sustentan estados/expiry RFC3339. [PubSub auth](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions): validar JWT firma/audience/issuer, service account/email_verified. [Sandbox checklist](https://developer.android.com/google/play/billing/test) revisado; ningún sandbox ejecutado.
- [Apple biblioteca oficial](https://github.com/apple/app-store-server-library-node): SignedDataVerifier con Apple roots, bundleId/environment y appAppleId production; AppStoreServerAPIClient para estado/notificaciones. No existe esta biblioteca en manifests actuales; aún no añadida.

## Contratos, propuesta, regresiones

| Requisito | Preservar / consumidores | Cambio mínimo propuesto | Riesgo / regresión |
|---|---|---|---|
| SDK/prod/ofertas | IDs actuales, purchases stream, iOS StoreKit | ruta wrapper compatible; modelo product/offer precio tienda; restore ambas plataformas | dependencyInsight+manifest nuevo, app kill, pending/cancel/owned/offline |
| Play verificado | POST link/sync y respuesta campos existentes | servicio provider validate state/product/env/owner; expiry RFC3339; conflicto token409; HMAC account ID | token otro usuario, estados tabla, legacy sin obfuscated ID |
| Entitlement común | /api/me is_pro y gating financiero | OR sólo grants válidos de fuentes normalizadas, cache recalculada; legacy separado | revoke fuente no borra otra, cancelado acceso hasta expiry, hold sin acceso |
| Apple fiable | receiptData+productId; compras vigentes | verificar JWS oficial/legacy Apple, binding inmutable usuario; sync y notifications oficiales | forged JWS, sandbox/env, ownership, renewal/revoked |
| Stripe fiable | checkout/portal/cancel existentes y metadata | firma obligatoria, fetch actual, inbox durable y normalized ingestion/cobros/refunds | webhook duplicado/fuera de orden; Apple/Play conviven; cancel caller |
| ACK/RTDN | Android viejos completePurchase | jobs durable, backoff/lease/idempotencia; persist RTDN antes200 y consultar API | ACK fail/retry/dead, duplicate messageId, linked token reemplazo |
| Admin real | uso plataforma independiente de proveedor | billing_contracts/charges coverage y raw-vs-normalized no tokens; cada moneda separado | anual/12, trial/grant exclusión, replacements/unknown/N-D |
| Borrado | FK user cascade actual | token/receipt secretos cifrados y metadata sólo necesaria; records cascade/anonymize explícito | no PII en auditoría/ledger/export, mismo delete conserva semántica |

Propuesta estructura posterior: `server/billing/{types,entitlements,google,apple,repository,worker,routes}` + `002_billing.sql` aditivo, DB connection dedicada/locks usuario y binding único. Legacy tables conservadas para transición/rollback con readers compatibles; jamás tratar is_pro sin origen como suscripción pagada. Preservar identidad de contrato ante linked tokens y respaldar antes rollout. No rollback destructivo del ledger/inbox; flags detienen nuevos checkout/rollout sin desactivar verificación/ingesta existentes.

## Baseline y límites concretos

- Lectura lock+Gradle+manifest release histórico consistente7.1.1. `java --version` falló porque /usr/bin/java es Java8; `java -version` confirma1.8.0_503. JBR Android Studio leído con `-version` confirma21.0.9. Flutter metadata local3.41.6/Dart3.11.4. Gradle8.11.1 y8.14 instalados; SDK Android, signing config y AAB existentes (sólo existencia, no secretos).
- **dependencyInsight/build nuevo no ejecutados en este subinforme**: Gradle del checkout escribe project cache/outputs y plugin included build; auditoría exige aislamiento y primera modificación repo sólo informe. Artefacto existente no sustituye verificación release nueva tras upgrade. Agent móvil evalúa baseline Flutter aislado; integrar su resultado sin duplicar.
- No tests Billing existentes localizados. No fixtures proveedor/MySQL aislado disponibles en este subalcance. No pruebas dispositivo, Play internal testing, Apple sandbox, Stripe sandbox ni producción.
- Env actual sólo nombres: `.env.example` tiene STRIPE_PUBLISHABLE_KEY/SECRET_KEY/WEBHOOK_SECRET pero faltan Play/Apple; `.env` presente no declara keys Billing consultadas. Esto **no prueba** ausencia de secretos en runtime cloud; no se usaron credenciales locales. Env source además usa ANDROID_PACKAGE_NAME, ADC GOOGLE_APPLICATION_CREDENTIALS/identity, APPLE_SHARED_SECRET aliases, APPLE_RECEIPT_VERIFICATION_MODE aliases, STRIPE_CURRENCY/STRIPE_UNIT_AMOUNT/CLIENT_URL.
- Externo necesario: confirmar productos/basePlans/ofertas publicados, Play extension si aplica, permiso Play Developer API y package, PubSub topic/service account JWT audience/DLQ, Apple bundle/appAppleId/roots/API credentials+notifications, Stripe webhook secret/event subscriptions. Default rollout no debe prometer estos configurados.

Siguiente paso exacto: integrar este subinforme al audit global, esperar checkpoint informativo del principal. Sólo entonces implementar migración/módulos/tests de Billing y actualizar wrappers en ruta compatible con resolución verificada. Cualquier sandbox externo queda checklist pendiente verificable.

Adenda de metadata oficial exacta: [tag Android0.5.0 pubspec](https://raw.githubusercontent.com/flutter/packages/in_app_purchase_android-v0.5.0/packages/in_app_purchase/in_app_purchase_android/pubspec.yaml) exige Dart^3.10/Flutter>=3.38 y [tag Gradle](https://raw.githubusercontent.com/flutter/packages/in_app_purchase_android-v0.5.0/packages/in_app_purchase/in_app_purchase_android/android/build.gradle.kts) declara Billing8.0.0, Kotlin2.3.20, AGP8.13.1, Java17. [core3.3.1 pubspec actual](https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase/pubspec.yaml) exige Dart^3.11/Flutter>=3.41, Android^0.5.0 y StoreKit^0.4.0. Son compatibles con SDK local3.41.6/Dart3.11.4 a nivel constraints; falta resolver/compilar toolchain nativo. API pub.dev metadata no accesible por herramienta web; tag oficial y fuente actual recuperados correctamente.


## Inventario Git inicial completo (rutas, no contenido sensible)

```text
.dockerignore
.gitignore
Dockerfile
FEATURE_GUIDE.md
TEMP_accounts_backup.txt
TEMP_figma_file.json
TEMP_figma_styles.json
TEMP_figma_vars.json
TEMP_patch_view.txt
TMP_SIDEBAR.txt
UpgradeNode.ps1
clientid.txt
cloudbuild.frontend.yaml
database/schema.sql
database/seed.sql
env.txt
financial-dashboard/.env.example
financial-dashboard/Dockerfile
financial-dashboard/Dockerfile.api
financial-dashboard/Dockerfile.web
financial-dashboard/README.md
financial-dashboard/cloudbuild.api.yaml
financial-dashboard/eslint.config.js
financial-dashboard/fix-existing-balance.js
financial-dashboard/index.html
financial-dashboard/nginx.conf
financial-dashboard/package-lock.json
financial-dashboard/package.json
financial-dashboard/postcss.config.js
financial-dashboard/public/app-ads.txt
financial-dashboard/public/finsight-icon.svg
financial-dashboard/public/screenshots/README.txt
financial-dashboard/public/screenshots/dashboard.png
financial-dashboard/public/screenshots/dashboard.svg
financial-dashboard/public/screenshots/invoices.svg
financial-dashboard/public/screenshots/projects.svg
financial-dashboard/public/screenshots/recurring.svg
financial-dashboard/public/vite.svg
financial-dashboard/server/add-installments-columns.js
financial-dashboard/server/auth.ts
financial-dashboard/server/db.ts
financial-dashboard/server/email.ts
financial-dashboard/server/fcm.ts
financial-dashboard/server/fix-projects-column.js
financial-dashboard/server/hashPassword.ts
financial-dashboard/server/index.ts
financial-dashboard/server/make-accounts-fields-nullable.js
financial-dashboard/server/mock-db.ts
financial-dashboard/server/notification_cron.ts
financial-dashboard/server/receiptExtraction.ts
financial-dashboard/server/reconcile-balances.ts
financial-dashboard/server/routes.ts
financial-dashboard/server/stripe.ts
financial-dashboard/server/test-server.ts
financial-dashboard/server/transactionWriter.ts
financial-dashboard/server/updatePassword.ts
financial-dashboard/src/App.css
financial-dashboard/src/App.tsx
financial-dashboard/src/assets/react.svg
financial-dashboard/src/components/AppCarousel.tsx
financial-dashboard/src/components/AssistantChat.tsx
financial-dashboard/src/components/CategoryPicker.tsx
financial-dashboard/src/components/FinSightLogo.tsx
financial-dashboard/src/components/LandingHeroScene.tsx
financial-dashboard/src/components/Layout.tsx
financial-dashboard/src/components/LegalPage.tsx
financial-dashboard/src/components/ProUpgradeBanner.tsx
financial-dashboard/src/components/ProUpgradeMini.tsx
financial-dashboard/src/components/ProtectedRoute.tsx
financial-dashboard/src/components/Sidebar.tsx
financial-dashboard/src/components/TopNavbar.tsx
financial-dashboard/src/components/UpdateProfileModal.tsx
financial-dashboard/src/components/auth/AuthShell.tsx
financial-dashboard/src/components/ui/ActionButton.tsx
financial-dashboard/src/components/ui/AppCard.tsx
financial-dashboard/src/components/ui/DataTableShell.tsx
financial-dashboard/src/components/ui/EmptyState.tsx
financial-dashboard/src/components/ui/FilterBar.tsx
financial-dashboard/src/components/ui/LoadingState.tsx
financial-dashboard/src/components/ui/ModalShell.tsx
financial-dashboard/src/components/ui/PageHeader.tsx
financial-dashboard/src/components/ui/StatCard.tsx
financial-dashboard/src/components/ui/StatusBadge.tsx
financial-dashboard/src/components/ui/index.ts
financial-dashboard/src/components/ui/utils.ts
financial-dashboard/src/contexts/I18nContext.tsx
financial-dashboard/src/contexts/ThemeContext.tsx
financial-dashboard/src/index.css
financial-dashboard/src/main.tsx
financial-dashboard/src/pages/Accounts.tsx
financial-dashboard/src/pages/Analytics.tsx
financial-dashboard/src/pages/Categories.tsx
financial-dashboard/src/pages/Dashboard.tsx
financial-dashboard/src/pages/DeleteAccount.tsx
financial-dashboard/src/pages/Guide.tsx
financial-dashboard/src/pages/Investments.tsx
financial-dashboard/src/pages/InvoiceDetail.tsx
financial-dashboard/src/pages/Invoices.tsx
financial-dashboard/src/pages/Landing.tsx
financial-dashboard/src/pages/Login.tsx
financial-dashboard/src/pages/Onboarding.tsx
financial-dashboard/src/pages/Payments.tsx
financial-dashboard/src/pages/Privacy.tsx
financial-dashboard/src/pages/Projects.tsx
financial-dashboard/src/pages/Signup.tsx
financial-dashboard/src/pages/Terms.tsx
financial-dashboard/src/pages/Transactions.tsx
financial-dashboard/src/types/expense.ts
financial-dashboard/src/utils/api.ts
financial-dashboard/src/utils/categoryIcons.tsx
financial-dashboard/src/utils/date.ts
financial-dashboard/src/utils/storage.ts
financial-dashboard/src/vite-env.d.ts
financial-dashboard/tailwind.config.js
financial-dashboard/temp_patch.txt
financial-dashboard/tsconfig.app.json
financial-dashboard/tsconfig.json
financial-dashboard/tsconfig.node.json
financial-dashboard/vite.config.ts
i18n.dart
mobile/.gitignore
mobile/.metadata
mobile/FIREBASE_PUSH_SETUP.md
mobile/README.md
mobile/analysis_options.yaml
mobile/android/.gitignore
mobile/android/app/build.gradle.kts
mobile/android/app/google-services.json
mobile/android/app/src/debug/AndroidManifest.xml
mobile/android/app/src/main/AndroidManifest.xml
mobile/android/app/src/main/kotlin/com/example/mobile/FinancialBoardWidgetProvider.kt
mobile/android/app/src/main/kotlin/com/example/mobile/MainActivity.kt
mobile/android/app/src/main/res/drawable-hdpi/android12splash.png
mobile/android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png
mobile/android/app/src/main/res/drawable-hdpi/splash.png
mobile/android/app/src/main/res/drawable-mdpi/android12splash.png
mobile/android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png
mobile/android/app/src/main/res/drawable-mdpi/splash.png
mobile/android/app/src/main/res/drawable-night-hdpi/android12splash.png
mobile/android/app/src/main/res/drawable-night-mdpi/android12splash.png
mobile/android/app/src/main/res/drawable-night-xhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-night-xxhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-v21/background.png
mobile/android/app/src/main/res/drawable-v21/launch_background.xml
mobile/android/app/src/main/res/drawable-xhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png
mobile/android/app/src/main/res/drawable-xhdpi/splash.png
mobile/android/app/src/main/res/drawable-xxhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png
mobile/android/app/src/main/res/drawable-xxhdpi/splash.png
mobile/android/app/src/main/res/drawable-xxxhdpi/android12splash.png
mobile/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
mobile/android/app/src/main/res/drawable-xxxhdpi/splash.png
mobile/android/app/src/main/res/drawable/background.png
mobile/android/app/src/main/res/drawable/finsight_icon.png
mobile/android/app/src/main/res/drawable/ic_stat_finsight.xml
mobile/android/app/src/main/res/drawable/launch_background.xml
mobile/android/app/src/main/res/drawable/widget_background.xml
mobile/android/app/src/main/res/drawable/widget_background_dark.xml
mobile/android/app/src/main/res/drawable/widget_background_light.xml
mobile/android/app/src/main/res/drawable/widget_button_background.xml
mobile/android/app/src/main/res/drawable/widget_button_background_dark.xml
mobile/android/app/src/main/res/drawable/widget_button_background_light.xml
mobile/android/app/src/main/res/drawable/widget_card_background.xml
mobile/android/app/src/main/res/drawable/widget_card_background_dark.xml
mobile/android/app/src/main/res/drawable/widget_card_background_light.xml
mobile/android/app/src/main/res/layout/widget_quick_transaction.xml
mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
mobile/android/app/src/main/res/values-night-v31/styles.xml
mobile/android/app/src/main/res/values-night/colors.xml
mobile/android/app/src/main/res/values-night/styles.xml
mobile/android/app/src/main/res/values-v31/styles.xml
mobile/android/app/src/main/res/values/colors.xml
mobile/android/app/src/main/res/values/styles.xml
mobile/android/app/src/main/res/values/widget_strings.xml
mobile/android/app/src/main/res/xml/network_security_config.xml
mobile/android/app/src/main/res/xml/widget_quick_transaction_info.xml
mobile/android/app/src/profile/AndroidManifest.xml
mobile/android/build.gradle.kts
mobile/android/gradle.properties
mobile/android/gradle/wrapper/gradle-wrapper.properties
mobile/android/settings.gradle.kts
mobile/assets/finsight-icon-flat.png
mobile/assets/finsight-icon.png
mobile/assets/finsight-icon.svg
mobile/assets/fonts/NotoSans-Bold.ttf
mobile/assets/fonts/NotoSans-Regular.ttf
mobile/devtools_options.yaml
mobile/ios/.gitignore
mobile/ios/FinancialBoardWidget/Assets.xcassets/Contents.json
mobile/ios/FinancialBoardWidget/FinancialBoardWidget.entitlements
mobile/ios/FinancialBoardWidget/FinancialBoardWidget.swift
mobile/ios/FinancialBoardWidget/FinancialBoardWidgetBundle.swift
mobile/ios/FinancialBoardWidget/Info.plist
mobile/ios/FinancialBoardWidgetExtension.entitlements
mobile/ios/Flutter/AppFrameworkInfo.plist
mobile/ios/Flutter/Debug.xcconfig
mobile/ios/Flutter/Release.xcconfig
mobile/ios/Podfile
mobile/ios/Podfile.lock
mobile/ios/Runner.xcodeproj/project.pbxproj
mobile/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
mobile/ios/Runner.xcworkspace/contents.xcworkspacedata
mobile/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
mobile/ios/Runner/AppDelegate.swift
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
mobile/ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json
mobile/ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard
mobile/ios/Runner/Base.lproj/Main.storyboard
mobile/ios/Runner/GoogleService-Info.plist
mobile/ios/Runner/Info.plist
mobile/ios/Runner/Runner-Bridging-Header.h
mobile/ios/Runner/Runner.entitlements
mobile/ios/RunnerTests/RunnerTests.swift
mobile/lib/dummy.txt
mobile/lib/i18n.dart
mobile/lib/i18n_tmp_line.txt
mobile/lib/lang_store.dart
mobile/lib/liquid_glass/lg_background.dart
mobile/lib/liquid_glass/lg_button.dart
mobile/lib/liquid_glass/lg_card.dart
mobile/lib/liquid_glass/lg_empty_loading.dart
mobile/lib/liquid_glass/lg_form.dart
mobile/lib/liquid_glass/lg_glass.dart
mobile/lib/liquid_glass/lg_metric_card.dart
mobile/lib/liquid_glass/lg_modal_shell.dart
mobile/lib/liquid_glass/lg_page_header.dart
mobile/lib/liquid_glass/lg_status_badge.dart
mobile/lib/liquid_glass/lg_tokens.dart
mobile/lib/liquid_glass/liquid_glass.dart
mobile/lib/main.dart
mobile/lib/models.dart
mobile/lib/screens/account_detail_screen.dart
mobile/lib/screens/accounts_screen.dart
mobile/lib/screens/accounts_screen_new.dart
mobile/lib/screens/ai_chat_screen.dart
mobile/lib/screens/analytics_screen.dart
mobile/lib/screens/calendar_screen.dart
mobile/lib/screens/dashboard_screen.dart
mobile/lib/screens/guide_screen.dart
mobile/lib/screens/investment_detail_screen.dart
mobile/lib/screens/investments_screen.dart
mobile/lib/screens/invoices_screen.dart
mobile/lib/screens/lock_screen.dart
mobile/lib/screens/login_screen.dart
mobile/lib/screens/manage_categories_screen.dart
mobile/lib/screens/payments_screen.dart
mobile/lib/screens/project_detail_screen.dart
mobile/lib/screens/projects_screen.dart
mobile/lib/screens/receipt_scan_screen.dart
mobile/lib/screens/settings_screen.dart
mobile/lib/screens/signup_screen.dart
mobile/lib/screens/transactions_screen.dart
mobile/lib/screens/transactions_v2_screen.dart
mobile/lib/screens/update_profile_screen.dart
mobile/lib/services/api.dart
mobile/lib/services/auth_service.dart
mobile/lib/services/biometric_service.dart
mobile/lib/services/data_service.dart
mobile/lib/services/purchase_service.dart
mobile/lib/services/push_service.dart
mobile/lib/services/receipt_image_service.dart
mobile/lib/services/widget_service.dart
mobile/lib/state/auth_store.dart
mobile/lib/state/refresh_bus.dart
mobile/lib/temp.txt
mobile/lib/theme.dart
mobile/lib/theme_mode_store.dart
mobile/lib/utils/category_icons.dart
mobile/lib/utils/format.dart
mobile/lib/utils/invoice_pdf.dart
mobile/lib/utils/links.dart
mobile/lib/utils/savings_goal.dart
mobile/lib/widgets/account_list_summary.dart
mobile/lib/widgets/account_summary.dart
mobile/lib/widgets/admob_ad_units.dart
mobile/lib/widgets/category_picker.dart
mobile/lib/widgets/kpi_card.dart
mobile/lib/widgets/new_transaction_dialog.dart
mobile/lib/widgets/non_pro_banner_ad.dart
mobile/lib/widgets/non_pro_interstitial_ad_controller.dart
mobile/lib/widgets/onboarding_coach.dart
mobile/lib/widgets/pro_widgets.dart
mobile/lib/widgets/project_summaries.dart
mobile/lib/widgets/quick_create_dialogs.dart
mobile/lib/widgets/recent_transactions.dart
mobile/lib/widgets/subcategory_budget_summary.dart
mobile/lib/widgets/upcoming_events.dart
mobile/linux/.gitignore
mobile/linux/CMakeLists.txt
mobile/linux/flutter/CMakeLists.txt
mobile/linux/flutter/generated_plugin_registrant.cc
mobile/linux/flutter/generated_plugin_registrant.h
mobile/linux/flutter/generated_plugins.cmake
mobile/linux/runner/CMakeLists.txt
mobile/linux/runner/main.cc
mobile/linux/runner/my_application.cc
mobile/linux/runner/my_application.h
mobile/macos/.gitignore
mobile/macos/Flutter/Flutter-Debug.xcconfig
mobile/macos/Flutter/Flutter-Release.xcconfig
mobile/macos/Flutter/GeneratedPluginRegistrant.swift
mobile/macos/Podfile
mobile/macos/Runner.xcodeproj/project.pbxproj
mobile/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
mobile/macos/Runner.xcworkspace/contents.xcworkspacedata
mobile/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/macos/Runner/AppDelegate.swift
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
mobile/macos/Runner/Base.lproj/MainMenu.xib
mobile/macos/Runner/Configs/AppInfo.xcconfig
mobile/macos/Runner/Configs/Debug.xcconfig
mobile/macos/Runner/Configs/Release.xcconfig
mobile/macos/Runner/Configs/Warnings.xcconfig
mobile/macos/Runner/DebugProfile.entitlements
mobile/macos/Runner/Info.plist
mobile/macos/Runner/MainFlutterWindow.swift
mobile/macos/Runner/Release.entitlements
mobile/macos/RunnerTests/RunnerTests.swift
mobile/pubspec.lock
mobile/pubspec.yaml
mobile/test/invoice_pdf_test.dart
mobile/web/favicon.png
mobile/web/icons/Icon-192.png
mobile/web/icons/Icon-512.png
mobile/web/icons/Icon-maskable-192.png
mobile/web/icons/Icon-maskable-512.png
mobile/web/index.html
mobile/web/manifest.json
mobile/web/splash/img/dark-1x.png
mobile/web/splash/img/dark-2x.png
mobile/web/splash/img/dark-3x.png
mobile/web/splash/img/dark-4x.png
mobile/web/splash/img/light-1x.png
mobile/web/splash/img/light-2x.png
mobile/web/splash/img/light-3x.png
mobile/web/splash/img/light-4x.png
mobile/windows/.gitignore
mobile/windows/CMakeLists.txt
mobile/windows/flutter/CMakeLists.txt
mobile/windows/flutter/generated_plugin_registrant.cc
mobile/windows/flutter/generated_plugin_registrant.h
mobile/windows/flutter/generated_plugins.cmake
mobile/windows/runner/CMakeLists.txt
mobile/windows/runner/Runner.rc
mobile/windows/runner/flutter_window.cpp
mobile/windows/runner/flutter_window.h
mobile/windows/runner/main.cpp
mobile/windows/runner/resource.h
mobile/windows/runner/resources/app_icon.ico
mobile/windows/runner/runner.exe.manifest
mobile/windows/runner/utils.cpp
mobile/windows/runner/utils.h
mobile/windows/runner/win32_window.cpp
mobile/windows/runner/win32_window.h
package-lock.json
sk.txt
temp_check.dart
```
