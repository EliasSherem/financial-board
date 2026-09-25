# Despliegue autorizado de FinSight en Cloud Run

**Rediseño editorial de la landing, 25 de septiembre de 2026:** la web actual es `financial-web-editorial-260925-105943`, con el 100 % del tráfico. Publica la navegación y diseño inspirados en Apple, la nueva secuencia 3D y la corrección de iconos superpuestos en Momentum. El [registro del rediseño](landing-editorial-redesign.md) documenta QA, build, digest y comprobación pública a las 11:04:23 UTC. La API continúa en `financial-api-salary-push-260925-0931`.

**Primera presentación de Momentum en la landing, 25 de septiembre de 2026:** `financial-web-landing-260925-102523` fue publicada y después sustituida por el rediseño editorial. El [registro de landing](landing-momentum.md) conserva sus comprobaciones de las 10:31:21 UTC.

**Salarios y notificaciones, 25 de septiembre de 2026:** la API actual es `financial-api-salary-push-260925-0931`, con el 100 % del tráfico. Se aplicó la migración `010`, se alineó Firebase para Android/iOS y se verificaron ambas claves APNs. El [registro de salarios y push](salary-and-push-fixes.md) incluye pruebas, build, digest y limitaciones de entrega física. En esa publicación, web conservó `financial-web-momentum-260925-0857`, sustituida posteriormente por la revisión de landing.

**Actualización de carga y pasos de Momentum, 25 de septiembre de 2026:** `financial-api-momentum-260925-0857` y `financial-web-momentum-260925-0857` fueron las revisiones publicadas en esa actualización; la API fue sustituida posteriormente por la revisión de salarios y push. El [registro de carga y textos](momentum-loading-and-copy.md) documenta mediciones, pruebas, digests y verificación pública a las 09:07:26 UTC.

**Despliegues anteriores:** el [registro del rediseño](momentum-profile-redesign.md) conserva la publicación inicial del perfil (`financial-web-momentum-260925-0826`). El [registro de rendimiento](server-performance.md) documenta la optimización anterior de API (`financial-api-perf-260924-2016`), sus mediciones, 99 pruebas, digest y validación. Las revisiones y horas de las secciones siguientes corresponden al despliegue inicial de la plataforma.

**Estado: COMPLETADO.** Registro del 24 de septiembre de 2026. Las diez migraciones remotas están completas. Las revisiones finales de API y web reciben el 100 % del tráfico y sus dominios públicos sirven la versión nueva. Verificación final de servicios a las **19:37:34 UTC** y de logs de API a las **19:26:47 UTC**, sin los errores de workers descritos abajo. Los pendientes de verificación de proveedores se detallan por separado.

El propietario autorizó expresamente, después de la implementación y del ensayo local, aplicar las migraciones a la base configurada y desplegar en Cloud Run. Esa autorización posterior amplió el alcance inicial. La [revisión remota](remote-migration-review.md), el [ensayo restaurado](remote-migration-rehearsal.md) y el [registro de implementación](finsight-platform-upgrade.md) conservan lo observado en cada etapa; sus referencias a operaciones pendientes describen ese momento anterior.

## Destino y revisiones

| Campo | Estado registrado |
| --- | --- |
| Proyecto | `finsight-472418` |
| Región | `us-central1` |
| Servicio API | `financial-api` |
| Servicio web | `financial-web` |
| API anterior | `financial-api-00086-27x` |
| Web anterior | `financial-web-00064-bcw` |
| API final | `financial-api-platform-260924-fix1`, 100 % del tráfico |
| Web final | `financial-web-platform-260924-fix2`, 100 % del tráfico |
| Etiquetas temporales | `rollout-validation` retiradas tras la promoción |
| API: capacidad mínima | 1 instancia y CPU asignada continuamente para los workers en proceso |
| Digest API | `sha256:92fa2c7dafb36c6cedff671bf7d99bcd7859623a378b49ceeb00b2fdf0a60ecd` |
| Digest web | `sha256:5285a2e750a6d0d9ef2eed99212583fc5048981fe12d879b58e35d156c1c5f95` |

La revisión candidata y el reparto de tráfico son controles distintos. Tener una revisión lista o accesible por su etiqueta de validación no demuestra que reciba tráfico general. Las revisiones anteriores se registran para trazabilidad; no constituyen una instrucción para volver automáticamente a ellas.

Imágenes inmutables en `us-central1-docker.pkg.dev/finsight-472418/containers/financial-api` y `financial-web`, desplegadas por digest. Builds finales: [API](https://console.cloud.google.com/cloud-build/builds;region=us-central1/edb950db-dae4-418d-ba0b-59490bb6afcd?project=finsight-472418) y [web](https://console.cloud.google.com/cloud-build/builds;region=us-central1/bcfdba40-1753-4546-a5cb-90b60d9029d6?project=finsight-472418). El primer par de revisiones `platform-260924-1844` quedó sustituido; la primera candidata web nunca recibió tráfico general.

## Respaldo y aplicación remota

La API se pausó mediante escalado manual a cero antes de la ventana de migración. El canal de operación comprobó ausencia de otras conexiones a la misma base y de transacciones activas, versión MySQL **9.7.2**, y las **22 tablas originales InnoDB**. El runner local del repositorio conserva sus restricciones a loopback y bases de pruebas: se usó un canal separado, revisado y explícitamente autorizado para la operación remota.

Se tomó un respaldo final lógico, comprimido con gzip y cifrado mediante AES-256-GCM. El canal verificó integridad del archivo, autenticación del cifrado, antigüedad máxima de 15 minutos y correspondencia de destino mediante un fingerprint de servidor/base. La clave y los manifiestos permanecen en almacenamiento privado local, fuera del repositorio. No se incluyen credenciales, datos personales ni payloads de proveedores en este informe.

SHA-256 del respaldo final cifrado:

```text
db32f2c24e9375f7577a88d3072869fbbce885d7889b2522d3b0106daee612d6
```

El respaldo del ensayo anterior sí se restauró y migró en MySQL local 9.7.2. El respaldo final de esta ventana se autenticó; esa comprobación no equivale a afirmar que se haya realizado una segunda restauración completa del respaldo final. La copia y la clave locales tampoco constituyen por sí solas un respaldo fuera del equipo.

La auditoría remota registra inicio a las **19:03:42 UTC** y finalización a las **19:06:20 UTC**. Se aplicaron los mismos hashes de los diez archivos `000–009` validados en el ensayo, con **217 sentencias** y cursor persistido por paso. Se admitieron únicamente las 22 notas `1050` previstas por tablas existentes; no se ignoraron errores ni warnings inesperados.

MySQL hace autocommit de DDL. Este canal no reanuda automáticamente una ejecución parcial: ante un fallo se conserva la pausa y se inspeccionan schema, último paso y tracker. No se borra el tracker ni se avanza el cursor para saltarse una sentencia aplicada parcialmente.

## Invariantes comprobados después de migrar

| Comprobación | Resultado |
| --- | --- |
| Migraciones | 10/10 completas; nombres, checksums y cursores coinciden |
| Tablas finales | 54, todas InnoDB |
| Triggers | 32; nombres exactos comprobados |
| Datos originales | Las 22 tablas y 1.409 filas conservan los hashes de todas sus columnas preexistentes |
| Identidades de transacciones | Verificación canónica correcta, sin alterar datos ni timestamps originales |
| Eventos de outbox creados por la migración | 0 |
| Tablas nuevas que debían estar vacías | 28/28 vacías |
| Contratos legacy importados | 11, con propietario y campos exactos comprobados |
| Grants | 4, con propietarios y expiraciones comprobados |
| Columnas de autenticación | Valores iniciales y normalización de email correctos |
| Identidades con colación binaria | 5/5 columnas verificadas |
| Zonas horarias SQL | Conversiones de México y Nueva York disponibles |
| Readiness remoto | Comprobación posterior satisfactoria |

Los hashes antes y después incluyen exclusivamente las columnas que ya existían; las columnas nuevas se validaron mediante invariantes separados. Los archivos privados de evidencia conservan conteos, hashes, tracker y resultados de comprobación. Estos resultados no implican una certificación de compras, notificaciones o recuperación de contraseña de extremo a extremo.

## Imagen, arranque y comprobaciones de API

Los Dockerfiles de API usan **Node 22 sobre Debian Bookworm**, `npm ci --include=dev` y arranque con `node --import tsx server/index.ts`. `tsx` sigue siendo una dependencia necesaria en runtime. Las imágenes copian explícitamente manifests, configuración TypeScript del servidor, `server/`, `scripts/` y `public/momentum/`; los contextos de build emplean allowlists. Las credenciales se suministran por configuración o secretos, sin copiar `.env` ni dependencias locales dentro de la imagen.

El primer build de API detectó que las pruebas necesitaban el script propio de backfill y los assets de Momentum. Se añadieron esos archivos a ambos Dockerfiles y a la allowlist, manteniendo las pruebas. La verificación local de un layout equivalente aprobó el typecheck y 56 pruebas sin base de datos; las 27 SQL quedaron omitidas por su guard explícito. Las pruebas SQL completas pertenecen al ensayo aislado y a las regresiones posteriores; no se ejecuta esa suite sobre datos de usuarios reales.

El arranque de producción comprueba conexión y migraciones antes de escuchar; no ejecuta DDL ni siembra usuarios. El secreto JWT de producción se configuró mediante la gestión de secretos correspondiente. Los valores no forman parte de este reporte.

La candidata de API superó los siguientes checks HTTP:

- `GET /api/health`: 200.
- Acceso anónimo a cuentas, configuración de billing, acceso admin y estado Momentum: 401.
- Preflight CORS de cuentas: 204.

El endpoint de salud informa disponibilidad del proceso; por sí solo no comprueba que todos los workers o proveedores funcionen. Los 401 confirman protección de rutas anónimas y no sustituyen pruebas funcionales autenticadas.

## Correcciones comprobadas durante el despliegue

La observación de runtime detectó `worker unavailable` en billing aunque la API respondía. Un fixture aislado en MySQL 9.7.2 reprodujo **`ER_NON_UNIQ_ERROR` / 1052**: `status` era ambiguo en el `INSERT ... SELECT ... ON DUPLICATE KEY UPDATE` de reconciliación. Un `EXPLAIN` satisfactorio no había demostrado que la sentencia real se ejecutara correctamente.

La corrección califica las referencias al destino `billing_jobs`, conserva backoff y leases, y reinicia intentos y error sólo cuando un trabajo completado inicia otra ronda. Las asignaciones consultan el estado anterior antes de cambiarlo. Para órdenes, la reapertura mantiene el intervalo diario. Las dos regresiones nuevas fallaron con el código anterior y la suite final pasó **85/85 pruebas, sin omisiones, en MySQL 9.7.2**; también pasó el typecheck del servidor.

La configuración existente de Google contenía dos caracteres de whitespace finales. El frontend y la comprobación de audiencia del servidor ahora normalizan ese identificador con `trim()`, y el build recibe el valor limpio. El smoke decodifica los literales JavaScript y exige el valor exacto; no se limita a buscar una subcadena. No se modificó la cuenta OAuth ni se rotó su configuración en Secret Manager.

La inspección visual en una pestaña pública nueva reprodujo `The given origin is not allowed for the given client ID`. La revisión de Google Auth Platform confirmó que el mismo cliente ya autorizaba `https://finsight.com.mx`; no se modificó OAuth. Se identificó la política global `no-referrer` como interferencia con GIS. La corrección acotada aplica `strict-origin-when-cross-origin` sólo mientras Login está montado, antes de cargar/inicializar GIS, y restaura la política previa al salir. Mantiene `no-referrer` en recuperación, también al navegar por la SPA. La [documentación de configuración de Google](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid) recomienda esta política para GIS. En localhost se observó `Referer: http://localhost:5173/` durante Login y la restauración de `no-referrer` al navegar por la SPA hacia recuperación. GIS local siguió respondiendo 403, por lo que esa prueba no acredita el funcionamiento en producción. La revisión web final `platform-260924-fix2` ya recibe el 100 % del tráfico. Una pestaña nueva sobre el dominio HTTPS público mostró el botón Google, respuesta **200 del iframe GIS** en Network y cero mensajes de consola; el DOM confirmó la política temporal de Login. La restauración de la política por navegación SPA se comprobó localmente con el mismo código; no se repitió de forma independiente en público por un fallo de automatización del navegador. No se envió un formulario, correo ni un inicio de sesión real durante esta comprobación.

Ambas imágenes corregidas completaron Cloud Build. La API pasó además typecheck y pruebas unitarias dentro de la imagen; la web pasó compilación y `nginx -t`. Los primeros checks de la revisión `platform-260924-fix1` aprobaron HTTP y no registraron fallos del worker de billing, Momentum, mantenimiento o cron. La consulta de sólo lectura confirmó que billing ya reclamaba y completaba trabajos reales; los fallos de verificación de proveedores se reprograman por separado.

## Estado de proveedores y clientes

El preflight de proveedores fue de lectura: no efectuó cobros ni asignó entitlements por ese diagnóstico. De los nueve identificadores Stripe legacy consultados, cuatro se encontraron —dos activos y dos cancelados— y cinco no se encontraron con la configuración consultada. Los dos contratos Apple revisados estaban expirados. Un resultado no encontrado requiere investigación de cuenta/entorno e identidad; no justifica borrar el registro ni inventar un estado de pago.

La migración conserva una transición legacy de **30 días**, además de cuatro grants: dos exenciones previas y dos grants `legacy_unknown` con vencimiento. Requieren clasificación operativa, responsable y fecha límite. No deben contabilizarse como suscriptores pagados verificados; la transición no se renueva por reiniciar la aplicación.

Tras activar el worker corregido, la lectura de las 19:24:38 UTC confirmó seis trabajos completados y cinco reprogramados con `provider_sync_incomplete`, sin jobs terminales fallidos. La consulta por cliente descubrió contratos históricos adicionales: Stripe quedó con dos activos verificados, seis expirados verificados y cinco legacy sin verificar; Apple, con dos expirados verificados. Persisten cinco contratos legacy sin verificar y el preflight registró cinco referencias no encontradas; requieren revisión de cuenta/entorno. El resumen agregado no sustituye una conciliación individual de esas identidades. Estos conteos son una observación puntual, no un resumen de ingresos ni una garantía de verificaciones futuras.

No se certifican Google Play Publisher/RTDN, App Store Server Notifications, compras sandbox, restauración, renovaciones, reembolsos ni entrega real de correo o push por el hecho de desplegar la API. Los flags y permisos de publisher requieren su validación específica. Tampoco se publicaron los clientes Flutter en las tiendas mediante este procedimiento; los builds locales Android/iOS y sus límites constan en [mobile-upgrade.md](mobile-upgrade.md).

## Cierre y respuesta ante incidentes

Se verificaron ambas revisiones con condiciones `Ready`, `ConfigurationsReady` y `RoutesReady` en `True`, cada una con el 100 % de tráfico y sin la etiqueta temporal. [La web pública](https://finsight.com.mx) sirve `/assets/index-CeEo0_Ch.js`; [la salud de API](https://api.finsight.com.mx/api/health), recuperación de contraseña y manifiesto de Momentum respondieron 200. `/reset-password` conserva `Cache-Control: no-store` y `Referrer-Policy: no-referrer`. `npm run doctor:server`, ejecutado desde el repositorio con su `.env` habitual, devolvió **OK** contra la base remota.

La última observación de la revisión API final no encontró errores de arranque, billing, reconciliación de Momentum, mantenimiento ni cron. Esta observación cubre el despliegue, no garantiza disponibilidad futura de proveedores. Permanecen cinco verificaciones Stripe legacy pendientes de la investigación descrita arriba.

El respaldo cifrado y su `README.txt` se conservan en `~/Library/Application Support/FinSight/migration-rehearsals/20260924T190200611Z/`; los scripts y evidencias operativas, en `~/Library/Application Support/FinSight/deployments/20260924T184415Z/`. Se detuvo la instancia MySQL aislada, se retiraron sus fixtures y credenciales, y se eliminaron las copias temporales de secretos resueltos de Cloud. Los bindings en Secret Manager permanecen activos. Las referencias privadas de evidencia incluyen `remote-migration-audit.json`, `remote-legacy-before.json`, `remote-legacy-after.json`, `remote-invariants-result.json`, `api-candidate-smoke.json`, `deployment-final-verification.json` y resúmenes de runtime; no deben incorporarse secretos ni logs privados al repositorio.

Un rollback de aplicación consiste en dirigir tráfico a una revisión **compatible y revisada**, o reducir funciones mediante sus flags manteniendo recepción/verificación de compras y revocación de sesiones. Un binario antiguo que ignore `token_version` o las verificaciones de compras no es un rollback seguro por defecto. Conservar datos nuevos, ledger, inbox, bindings, tracker y auditoría.

La reversión de tráfico no revierte las migraciones. No ejecutar DROP, borrar columnas, restaurar el backup sobre la base activa ni modificar checksums como parte de un rollback de interfaz. Una restauración de datos sería una operación de incidente independiente que debe considerar todas las escrituras posteriores al respaldo. Este documento no ordena ejecutar un rollback ahora.
