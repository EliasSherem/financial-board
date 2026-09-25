# FinSight platform upgrade — ejecución y operación

**Seguimiento posterior:** el [registro de despliegue en Cloud Run](cloud-run-deployment.md) documenta la autorización posterior, las migraciones remotas y el rollout. Se conserva a continuación la evidencia de implementación y las revisiones anteriores.

Verificado localmente el 2026-09-24. Base: `master`, commit `19c5651fc322cfacac5645ec92b618dbb92cc08e`. Se conserva Flutter, React, Express y MySQL. No se publicaron builds, se modificaron proveedores ni se ejecutaron migraciones en producción.

## Checklist

- [x] A. Auditoría integral de sólo lectura, inventario, contratos, baseline y checkpoint antes de implementar. Primera modificación deliberada: [repository-audit.md](repository-audit.md). El plan histórico nombrado no estaba adjunto; el prompt y el paquete de catálogo/assets fijaron el alcance.
- [x] B. Diez migraciones aditivas, transacciones por conexión, outbox, telemetría y RBAC.
- [x] C. Billing común Google/Apple/Stripe, identidad, verificación, inbox, ACK y reconciliación.
- [x] D. Momentum: 41 misiones, 34 insignias, caps atómicos, períodos, reviews, backfill, retorno, gracia y créditos IA.
- [x] E. React/Flutter, 168 SVG originales, caché por usuario, navegación y recuperación con revocación de sesión.
- [x] F. Admin privado, seis informes, filtros, métricas SQL reales, gráficos y exportación autorizada.
- [x] G. Integración local, migraciones desde cero, builds y runbooks.
- [ ] Validación externa antes de publicar: sandbox de proveedores, correo real, dispositivos, asociaciones HTTPS y staging del despliegue.

## Documentación

- [Auditoría y baseline](repository-audit.md): inventario, flujos, riesgos y matriz de requisitos.
- [Momentum](momentum.md): reglas, outbox, períodos, retención, IA y notificaciones.
- [Billing](billing-upgrade.md): versiones, fuentes oficiales, legacy, configuración y matriz sandbox.
- [Clientes/API](client-contract.md): DTO y payloads aditivos.
- [Web, Admin y telemetría](web-admin-analytics.md): informes, definiciones, cobertura, RBAC y privacidad.
- [Recuperación](recovery.md): tokens, identidad, correo, links y sesiones.
- [Flutter y builds](mobile-upgrade.md): archivos, QA, comandos y límites nativos.
- [Inversiones legacy](investment-account-backfill.md): preflight y reparación explícita de cuentas ausentes, sin ejecutar sobre datos reales.

## Decisiones y compatibilidad

Las respuestas financieras se conservan; Momentum se refresca por API separada. Los triggers escriben eventos dentro de la transacción financiera y el evaluador trabaja después. AsyncLocalStorage mantiene los helpers heredados sobre la conexión reservada; errores o cierre de request revierten lo pendiente. Un fallo posterior del evaluador conserva las finanzas confirmadas.

El arranque no crea tablas ni usuarios demo. `LEGACY_SCHEMA_BOOTSTRAP` es una excepción local explícita, deshabilitada en producción. Readiness requiere las diez migraciones completas y tablas InnoDB. No se usaron secretos ni datos de producción para los tests.

Los hitos de proyecto 25/50/75 no se deducen del gasto: el modelo no tiene progreso de trabajo y las insignias explican la limitación. Un proyecto `Completed` sí prueba una finalización. La IA reutiliza el chat móvil existente; el GPT externo de la web no prueba una respuesta ni da XP. Las capacidades ausentes no se presentan como acciones funcionales.

Las identidades antiguas sin proveedor quedan `unknown`: recuperación no les crea una contraseña sin evidencia. Un login local válido permite clasificarlas. Los emails normalizados ambiguos tampoco reciben reset. Los JWT anteriores funcionan mientras su versión sea vigente; reset/change-password revocan inmediatamente mediante comprobación del servidor.

Billing pasó de 7.1.1 a **8.0.0 nativo provisional**, comprobado en Gradle y manifiesto release. Google estable consultada era 9.1.0, pero el wrapper oficial inspeccionado aún usa 8.0.0. No se forzó una dependencia incompatible ni se afirma una migración a 9. Los contratos legacy se conservan para reconciliación; grants y trials se separan de suscriptores pagados. La transición legacy dura 30 días desde la migración y no se renueva al arrancar.

## Evidencia local

| Check | Resultado comprobado |
|---|---|
| `npm run test:db` | **83/83 PASS**, cero fallos y cero skips, después de las últimas correcciones; incluye unitarias y SQL real. |
| Migraciones `000`–`009` en base vacía | PASS: diez registros completos, 32 triggers, cero usuarios sembrados; segunda ejecución idempotente. Se elimina únicamente la base temporal creada por la prueba. |
| `npm run check:server` | PASS en todos los módulos de servidor y scripts. |
| Web `npx tsc --noEmit` y `npm run build` | PASS. Build final aislado: 2,945 módulos, principal 1,124.54 kB y chunk 3D heredado 901.32 kB sin comprimir. Vite conserva el aviso de chunks grandes. |
| Lint dirigido web | PASS. Baseline completo: 166 errores y seis warnings; no se afirma limpieza global. |
| `npm run assets:check` | PASS: 34 badges, cuatro niveles y 168 SVG, manifiesto/copias web y Flutter idénticos byte a byte. |
| Flutter tests | 16/16 PASS, incluidos caché, cuenta/logout, retries, URI de recuperación, errores de red, 168 SVG y ES/EN/claro/oscuro con texto al 200%. |
| Flutter análisis | Dirigido: cero incidencias. Completo: cero errores, cuatro warnings y 127 infos heredados; baseline cinco warnings y 128 infos. |
| Android release | PASS, 61.2 MB. [AAB local](../../mobile/build/app/outputs/bundle/release/app-release.aab), sin subir a Play. |
| iOS simulador arm64 sin firma | PASS. Universal sigue afectado por `lipo -verify_arch` de Xcode 27; no se afirma build universal, dispositivo firmado ni archive. |

SHA-256 del AAB final: `6a86bf87d26f357a1d40a60e11941e6aeb39bc946731866d122e60801e82c30d`.

MySQL 8.4.11 se instaló con autorización y se ejecutó aislado en `/tmp/finsight-mysql-isolated`, loopback puerto 13306, sin servicio al iniciar sesión. Los tests crean/eliminan sus fixtures sintéticos y no cargan `.env`. El runner elimina `MYSQL_URL` y claves de correo/IA. No ejecutar `npm start` con el `.env` legado para reproducirlos.

SQL cubre varios dispositivos, duplicados, ledger inmutable, backfill, caps 100+20/75, evidencia obsoleta, identidad canónica, rollback de outbox y fallo posterior del evaluador, holds IA, Pro caducado, IANA, payload real del recibo, ownership de pagos, ACK/inbox/pending-flow, revocación JWT, reset concurrente y rollback tras escribir contraseña. Admin comprueba D7/D30 exactos, cohortes inmaduras, multiplataforma, monedas separadas, MRR anual/mensual, trials/grants/refunds y N/D.

QA web utilizó copia sin `.env`, API local y usuario sintético. Se comprobó dashboard, activación limitada a tres acciones, misiones, revisión con checkbox obligatorio y respuesta real del servidor (0/3 a 1/3; XP 50 a 115 por revisión y activación), galería de 34 logros y motivos de capacidades. Admin mostró layout separado, seis secciones, filtros, N/D y cobertura; la cuenta sintética quedó excluida del entorno production. La consola inspeccionada no tenía errores. El control nativo de Chrome resultó intermitente: no se certifica una matriz visual web completa de oscuro/ES/recuperación. QA móvil usa widgets reales y fixtures renderizados, no un dispositivo físico.

La última regresión HTTP ejecuta el router financiero real: aportación de inversión, evento, saldo e historial comparten transacción. Fallos inyectados en outbox e historial revierten todas las escrituras; el caso exitoso conserva la respuesta anterior. También se verificaron propiedad, 401/404 y fecha inválida. La reparación legacy tiene cuatro pruebas de precisión, guards, rollback e idempotencia; sólo se ejecutó sobre fixtures sintéticos. La revisión mensual calcula neto como ingresos menos gastos incluso con signos legacy mixtos.

`git diff --check` final pasa. API/Vite temporales de QA apagados y fixture web eliminado con comprobación de conteo cero. El proceso MySQL temporal también quedó apagado tras la suite; el directorio aislado se conserva para reproducibilidad. No se publica nada como parte de este trabajo.

## Reproducir

En `financial-dashboard`:

```sh
npm run check:server
npx tsc --noEmit
npm run build
npm run assets:check
npm run test:server
npm run migrate:check
npm run test:db
```

`test:server` omite las pruebas SQL sin su entorno explícito. `test:db` requiere MySQL aislado en loopback y base `_test` preparada. Para una base vacía local, proporcionar explícitamente `MYSQL_HOST=127.0.0.1`, puerto/usuario/contraseña locales y `MYSQL_DATABASE=finsight_local`, sin `MYSQL_URL`, y ejecutar `npm run migrate:local`. No copiar las credenciales del `.env` del repositorio. El runner imprime checksums, bloquea concurrencia y registra cada statement.

Comandos exactos de Flutter/Gradle/Xcode en [mobile-upgrade.md](mobile-upgrade.md) y [billing-upgrade.md](billing-upgrade.md). Los logs `/tmp/finsight-mobile-*.log` son evidencia local, no artefactos permanentes de CI.

## Rollout, recuperación y rollback

1. Preparar copia aislada de staging y respaldo verificable. Comparar schema legacy, motores, duplicados, índices y permisos. MySQL probado aquí es 8.4, no evidencia de la versión de producción. Cargar tablas de zonas MySQL para informes IANA y verificar conversiones. Separar identidad de migración con DDL/TRIGGER de identidad runtime con DML mínimo.
2. Aplicar `000`–`009` en orden mediante proceso explícito y revisado. El runner incluido sólo admite loopback y nombres `_local`, `_test`, `_staging`; no es un comando de producción. Conservar `platform_migrations` y checksums. No editar una migración ya publicada/aplicada: publicar otra. La corrección de timestamps de 005 pertenece a esta entrega aún no aplicada en la base remota revisada; los esquemas locales antiguos requieren revisión o una base nueva, nunca falsificar su checksum. DDL MySQL hace autocommit; si hay crash entre DDL y registro, inspeccionar el schema antes de reanudar, sin ignorar errores ni avanzar el cursor a ciegas.
3. Resolver inversiones legacy sin cuenta, clasificar credenciales y reconciliar contratos/grants antes de 30 días. Nunca convertir un grant en ingreso. El procedimiento de inversiones es explícito, con mantenimiento y revisión previa, sin ejecutarlo al arrancar.
4. Configurar [.env.example](../../financial-dashboard/.env.example): JWT, cifrado/binding Billing, proveedores, orígenes HTTPS/CORS y proxy. API/worker primero, clientes después. Bootstrap owner con CLI que resuelve al usuario real; verificar 401/403. No asignar roles desde el cliente.
5. Activar Momentum, créditos, push y analytics gradualmente tras comprobar capacidades. Al pausar presentación/checkout no detener verificación, RTDN, ACK ni revocación JWT. Vigilar colas, eventos fallidos, sync, unknown y cobertura en Data health.
6. Ejecutar matrices Play internal, Apple/Stripe sandbox, correo y dispositivos. Verificar usuarios existentes/Free/Pro/SSO y rollback antes de publicar.
7. Rollback por flags conserva API de verificación, ledger, inbox, ownership, contratos y tokens consumidos. No restaurar handlers de self-grant o webhooks sin firma. Restauración DB sólo con respaldo y decisión operativa explícita.

## Seguimiento del arranque (2026-09-24)

Ante el error genérico comunicado por el propietario, se verificó con consultas de sólo lectura que el `.env` efectivo apunta a una base remota mediante `MYSQL_URL`: la conexión funciona, pero no existe `platform_migrations` ni las tablas nuevas de plataforma. Las migraciones locales anteriores no afectaron esa base. El propietario pidió **revisar** la migración remota, no aplicarla; ver [remote-migration-review.md](remote-migration-review.md).

El arranque ahora distingue tracker ausente, migraciones pendientes/incompletas, tablas faltantes, motor incompatible y errores de conexión/configuración, sin imprimir mensajes crudos de MySQL ni secretos. Cierra el pool tras fallar para que el proceso termine. Nuevo `npm run doctor:server`: usa la configuración real, sólo ejecuta SELECT y nunca llama al bootstrap ni a workers. `MYSQL_URL` prevalece; quitarla del shell permite que dotenv la recargue del archivo, mientras que un valor vacío explícito evita esa reposición.

Checks del ajuste: siete pruebas de diagnóstico/sanitización/cierre del pool y `npm run check:server` pasan. La prueba SQL de instalación y repetición de las diez migraciones pasa, incluida la comprobación de readiness sobre la base recién creada. El doctor se ejecutó contra la base configurada y devolvió `PLATFORM_MIGRATION_TRACKER_MISSING`, con salida 1 y cierre normal. No se cambió `.env` ni se escribió en la base remota. La revisión detectó y corrigió en los artefactos de entrega la preservación de `transactions.updated_at` durante 005; se añadió 009 para identidad exacta de Billing y tokens legacy. La suite final ampliada pasa 83/83, con dos escenarios de migración real y pruebas de identidad por mayúsculas/espacios. El seguimiento [remote-migration-rehearsal.md](remote-migration-rehearsal.md) documenta el respaldo cifrado restaurado y las diez migraciones ensayadas en MySQL 9.7.2: 22 tablas/1.409 filas con todos sus campos originales intactos, readiness OK y 83/83 pruebas en otra base sintética. Se hizo explícito FORMAT=TRADITIONAL en la prueba EXPLAIN de recuperación para no depender del formato configurado. La base remota sigue sin migrarse; quedan autorización, mantenimiento y respaldo final.

## Pendientes externos exactos

- Copia/privilegios del MySQL de despliegue y clasificación legacy. Secretos versionados anteriormente requieren rotación por el operador sin reproducirlos en logs.
- Play: productos/base plans/ofertas, permisos Publisher para verify/ACK/Orders, PubSub autenticado con audience/service account, DLQ y pruebas internas. Futuro wrapper compatible con Billing 9.
- Apple: app/bundle IDs, raíces oficiales, API keys, notificaciones V2 y sandbox restore/renewal/grace/revoke.
- Stripe: claves test/live, endpoint firmado, plan/precio existente confirmado y regresión test. No se modificaron precios por inferencia.
- Resend: remitente/dominio verificados, origen HTTPS/allowlist, entrega y apertura real de reset. Asociaciones App/Universal Links y certificados sólo de dominio poseído; fallback web implementado.
- FCM/permisos, quiet hours/zona en dispositivos, IA real, lector de pantalla/reducción de movimiento y builds firmados para distribución.

La auditoría y las pruebas reducen riesgo; no prueban que todas las configuraciones reales estén listas ni garantizan ausencia de errores.
