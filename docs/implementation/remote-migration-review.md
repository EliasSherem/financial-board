# Revisión de migración remota — no aplicada

**Seguimiento posterior:** el propietario autorizó después la aplicación remota y el despliegue. Su estado actual está en [cloud-run-deployment.md](cloud-run-deployment.md). Este informe conserva los hallazgos y el alcance de la revisión anterior.

Revisión autorizada el **24 de septiembre de 2026**, entre **18:12:32 y 18:14:56 UTC**. Se consultó la configuración efectiva del servidor sin mostrar host, usuario, nombre de base, contraseña, URL, tokens ni registros personales. En la base remota se usaron únicamente `SELECT` y `SHOW`, con timeout de conexión/consulta de 10 segundos y límite MySQL de ejecución de 10 segundos para los SELECT. No se importó la aplicación, arrancó un worker, ejecutó bootstrap, llamó a proveedores ni aplicó DDL/DML remoto. Después de cerrar esa revisión se corrigieron artefactos locales y se probaron en MySQL aislado; se distinguen a continuación.

**Resultado:** la base remota sigue en el esquema heredado; la ausencia de `platform_migrations` explica el bloqueo de readiness. Las comprobaciones no encontraron un conflicto actual de duplicados o claves foráneas que impida las restricciones revisadas. Los artefactos locales ya preservan `updated_at` en `005` e incluyen `009` para colación exacta de identidades de billing. **Seguimiento:** el respaldo cifrado y su restauración, el ensayo en MySQL 9.7.2 y la suite 83/83 ya se completaron; ver [remote-migration-rehearsal.md](remote-migration-rehearsal.md). Continúan pendientes la autorización de aplicación remota, la ventana de mantenimiento y el respaldo final durante esa ventana. Esta revisión no autoriza aplicación remota y ninguna de las diez migraciones se aplicó allí.

## Evidencia del servidor y esquema

| Comprobación | Resultado observado |
| --- | --- |
| Motor/version | `MySQL Community Server - GPL`, `9.7.2` |
| Tablas actuales | 22, todas InnoDB |
| Tracker de migraciones | Ausente |
| Tablas nuevas de `001–003/006` | Las 31 están ausentes; no hay instalación parcial visible de estas tablas |
| Triggers existentes | 0; no hay colisiones de nombres con los 32 de `004/005` |
| Columnas legacy inspeccionadas | 236; columnas declaradas en los CREATE de `000` presentes y con tipos coincidentes |
| Adiciones condicionales de `000` | Las 15 columnas ya están presentes |
| Claves foráneas actuales | 40; cero referencias huérfanas en sus comprobaciones agregadas |
| Charset/collation de la base y tablas actuales | `utf8mb4` / `utf8mb4_0900_ai_ci` |
| Zona del servidor | Sesión `SYSTEM`; sistema `UTC` |
| Tablas IANA | Las conversiones de prueba para México y Nueva York devolvieron valores válidos |
| Binary logging | `log_bin=0`; `log_bin_trust_function_creators=0` |
| Sesiones con transacciones activas en la consulta | 0; tampoco se observaron transacciones de más de 60 segundos |
| Modo SQL | Incluye `STRICT_TRANS_TABLES`, `ONLY_FULL_GROUP_BY`, `NO_ZERO_DATE`, `NO_ZERO_IN_DATE` |

`users.id` y las columnas legacy que lo referencian son `INT` con signo, compatibles con las nuevas FK. `transactions.type` ya tiene `Income/Expense/Transfer`; `investments.annual_rate` ya es `DECIMAL(10,4) NOT NULL`. Los dos ALTER MODIFY de `000` no requieren transformación del tipo observado, aunque siguen siendo DDL y pueden necesitar metadata locks.

Los índices `uniq_investment_account` y `uniq_investment_contribution_tx`, las FK de categorías/subcategorías y `fk_investments_account` ya existen con las columnas y reglas esperadas. El índice de `payments.account_id` tiene otro nombre pero cubre la columna; esto no impide el plan. Las columnas nuevas de `003`, `005`, `007` y `008` no existen, y no se detectaron los índices/triggers nuevos de esas migraciones. `CREATE TABLE IF NOT EXISTS` no sustituye esta comparación: no adapta una tabla existente con otra estructura.

Los conteos son lecturas sucesivas, no una copia consistente ni una congelación de escrituras. Los `TABLE_ROWS` de InnoDB se trataron como estimaciones; los números siguientes proceden de `COUNT(*)`. Deben repetirse durante la ventana real de cambio.

## Conteos de preflight

| Dato o restricción | Conteo |
| --- | ---: |
| Usuarios | 172 |
| Transacciones | 550 |
| Cuentas | 88 |
| Inversiones / contribuciones | 4 / 40 |
| Categorías / subcategorías | 42 / 43 |
| Pagos recurrentes / proyectos | 23 / 13 |
| Facturas / pagos de factura | 23 / 14 |
| Grupos duplicados de investment.account_id | 0 |
| Grupos duplicados de contribution.transaction_id no nulo | 0 |
| Inversiones sin account_id | 0 |
| Vínculos inversión–cuenta de distinto propietario o tipo incorrecto | 0 |
| Contribuciones con propietario distinto de la inversión | 0 |
| Huérfanos de las nuevas FK de categoría/subcategoría | 0 |
| Transacciones/pagos con cuenta de distinto propietario | 0 |
| Tipos de transacción o tasas incompatibles con `000` | 0 |
| Grupos de emails duplicados tras LOWER(TRIM(email)) | 0 |
| Usuarios sin email utilizable | 0 |

Hay **7 cuentas de tipo Investment sin una fila en investments**. Pueden ser cuentas creadas manualmente; este conteo no prueba corrupción y no autoriza fusionarlas ni eliminarlas. Hay **2 contribuciones con transaction_id que ya no existe**; no hay FK para ese enlace en el esquema ni en `000–008`, por lo que no bloquean esas migraciones. Deben clasificarse por separado sin reconstruir importes ni historial automáticamente. Las cuatro inversiones tienen enlaces válidos, por lo que el backfill de cuentas documentado en `investment-account-backfill.md` no tiene candidatos en este snapshot.

## Billing y transición legacy

| Clasificación observada | Conteo |
| --- | ---: |
| Usuarios con caché `is_pro=true` | 11 |
| Candidatos a exenciones legacy ya existentes | 2 |
| Candidatos exactos a grant `legacy_unknown` de 30 días | 2 |
| Usuarios Pro en caché con algún registro de proveedor | 8 |
| Suscripciones Stripe legacy no nulas | 9 |
| Registros Apple legacy | 2 |
| Registros Google Play legacy | 0 |
| Duplicados Stripe por comparación actual o binaria | 0 |
| Duplicados Apple / Google detectados | 0 / 0 |
| Longitudes de campos incompatibles con la copia a `002` | 0 |

Las dos filas Apple están etiquetadas `Production`, contienen receipts legacy en texto claro y ninguna tiene expiración futura según la fecha del servidor. No se leyó ni imprimió su contenido. No hubo consulta a Apple/Google/Stripe: **estos conteos no prueban compras pagadas, renovaciones, ingresos ni acceso vigente**. Las categorías pueden solaparse y no deben sumarse como particiones.

`002` crearía 11 contratos legacy candidatos —9 Stripe y 2 Apple— con `verified=false`, conservaría las dos exenciones y añadiría dos grants temporales según sus reglas actuales. Debe compararse el resultado exacto en staging; `INSERT IGNORE` no debe ocultar warnings, truncamientos o pérdidas de filas. La ventana de 30 días comienza al ejecutar la migración, no al publicar el cliente: hace falta responsable y fecha límite de clasificación/reconciliación. Las exenciones no conceden rol admin. Los tokens/receipts históricos no se cifran por el mero hecho de instalar `002`; su tratamiento posterior requiere una operación revisada aparte.

## Correcciones y condiciones antes del cambio

1. **Timestamps históricos: corregido en el artefacto local `005`.** La versión inicialmente revisada hacía `UPDATE transactions SET momentum_identity=...`; como la columna remota `transactions.updated_at` tiene `ON UPDATE CURRENT_TIMESTAMP`, habría cambiado las fechas de las 550 filas candidatas. La versión local posterior incluye explícitamente `updated_at=updated_at`. Su regresión de migración con fechas de 2020 aprobó la comparación de importes/campos/timestamps y ausencia de eventos artificiales. El checksum previo `339189662a2fd204df90ce15ddf35747c7fffe4784ccf4769458859dc96fabc9` identifica el artefacto aún no publicado remotamente que se revisó; la corrección deliberadamente invalida ese checksum en las antiguas bases sintéticas locales. No se reescribió ningún ledger para fingir coincidencia: se comprobó la secuencia en una base aislada nueva. Si se descubre otro entorno que ya hubiera aplicado el checksum antiguo, debe revisarse su historial antes de reanudar; una corrección posterior sin copia previa no recupera fechas sobrescritas.

2. **Identidad exacta: corregida mediante el nuevo artefacto local `009`.** `002` no fija colación para `billing_contracts.contract_key` (línea 6, unique línea 23), `billing_inbox.event_key` (64/74), `billing_jobs.job_key` (81/91) y `billing_charges.provider_charge_id` (101/108). Heredarían la colación remota insensible a mayúsculas/acentos. Esto era un riesgo de ownership/deduplicación futura; **no se encontró una colisión actual**. `billing_purchase_tokens.token_hash` ya usa `ascii_bin`. La migración aditiva `009_billing_identity_collation.sql` conserva `002` y declara identidad exacta sin cambiar longitudes, nullabilidad ni índices. Estos ALTER se aplicaron sólo al MySQL aislado local, nunca al remoto:

   ```sql
   ALTER TABLE billing_contracts MODIFY COLUMN contract_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
   ALTER TABLE billing_inbox MODIFY COLUMN event_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
   ALTER TABLE billing_jobs MODIFY COLUMN job_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
   ALTER TABLE billing_charges MODIFY COLUMN provider_charge_id VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
   ALTER TABLE play_subscriptions MODIFY COLUMN purchase_token VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
   ```

   El legacy `play_subscriptions.purchase_token` también tiene UNIQUE con `utf8mb4_0900_ai_ci`, aunque hoy está vacío. Su conversión está incluida porque `server/billing/repository.ts` todavía lo compara en `tokenOwner`, validación de ownership/reemplazos y actualización de expiración. No se convierten nombres/emails ni toda la base a colación binaria. La diferencia entre `utf8mb4_bin` y `utf8mb4_0900_bin` incluye el tratamiento de espacios finales. [Reglas oficiales de colación binaria](https://dev.mysql.com/doc/refman/8.4/en/charset-binary-collations.html).

   Verificación local: `npm run test:db -- server/billing/billing_sql.test.ts` aprobó **6/6**, incluidas dos regresiones nuevas que conservan ownership separado entre variantes de mayúsculas, rechazan la reasignación de la identidad exacta, distinguen espacios finales y mantienen la deduplicación de repeticiones exactas en inbox/jobs/charges. TypeScript focal aprobado. Sólo se usaron fixtures sintéticos en `127.0.0.1:13306`, no proveedores.

   La suite SQL final completa aprobó **83/83**, sin omisiones ni fallos, sobre MySQL aislado 8.4.11. Incluye instalación fresca de las diez migraciones, repetición del runner, 32 triggers, readiness y la actualización del fixture legacy preservando timestamps y valores. `npm run check:server` también aprobó. Estos resultados no equivalen a un ensayo en MySQL 9.7.2.

3. **Ensayo de versión: completado posteriormente.** Ver la evidencia final en [remote-migration-rehearsal.md](remote-migration-rehearsal.md). El párrafo siguiente describe la situación al cerrar la revisión inicial: La validación previa del proyecto se ejecutó en MySQL 8.4.11, no en el 9.7.2 remoto. Existe documentación y release oficial de [MySQL 9.7.2](https://dev.mysql.com/doc/relnotes/mysql/9.7/en/news-9-7-2.html); la diferencia de versión no prueba incompatibilidad, pero tampoco permite afirmar que el proyecto ya pasó pruebas en esa versión. Restaurar una copia controlada sobre la misma versión y ejecutar la secuencia y regresión SQL allí.

4. **Backup ensayado posteriormente; operador y aplicación pendientes.** Se creó un respaldo cifrado y se comprobó su restauración en el [ensayo posterior](remote-migration-rehearsal.md). Sigue siendo necesario un respaldo final durante la ventana de cambio. El alcance de la revisión inicial fue el siguiente: Esta revisión no verifica que exista backup reciente, que sea restaurable, el espacio libre ni el tiempo real de los ALTER. Tampoco ejecuta el canal de producción. Preparar respaldo cifrado con esquema, datos, índices, vistas/triggers si corresponden y comprobación de restauración. Con `log_bin=0`, no asumir recuperación a un instante mediante binlogs. Separar credencial runtime de credencial migradora: la observada tiene privilegios globales y GRANT OPTION, muy superiores a los necesarios para la API.

## Compatibilidad SQL y permisos

El runner usa `PREPARE` sólo para el DDL condicional de `000`; MySQL 9.7 permite preparar `ALTER TABLE`. Los `CREATE TRIGGER` de `004/005` se envían como consultas directas, apropiado porque no están en la lista de sentencias SQL preparables. No sustituir indiscriminadamente `conn.query` por prepared statements para las migraciones. [Prepared statements 9.7](https://dev.mysql.com/doc/refman/9.7/en/sql-prepared-statements.html).

No hay CHECK en la secuencia `000–009` ni en las tablas remotas consultadas. La limitación histórica anterior a MySQL 8.0.16 no afecta a este plan; no se pretende que existan garantías CHECK que los archivos no crean. [CHECK](https://dev.mysql.com/doc/refman/8.0/en/create-table-check-constraints.html).

Las capacidades actuales incluyen SELECT, INSERT, UPDATE, CREATE, ALTER, INDEX, REFERENCES y TRIGGER. No apareció un bloqueo de privilegios para el plan, aunque sólo un ensayo puede demostrar la ejecución efectiva. El usuario que cree los triggers será su definer por defecto y deberá conservar los permisos mínimos necesarios para ejecutarlos; no eliminarlo sin revisar esa dependencia. No hay que activar `log_bin_trust_function_creators` para resolver la situación observada: el binlog está deshabilitado. Si se habilita posteriormente, revisar permisos y formato de replicación por los UUID de los triggers. [CREATE TRIGGER 9.7](https://dev.mysql.com/doc/refman/9.7/en/create-trigger.html), [logging de programas almacenados](https://dev.mysql.com/doc/refman/9.7/en/stored-programs-logging.html).

El DDL hace commit implícito; ni una transacción alrededor del runner ni “atomic DDL” convierten toda la secuencia en una operación reversible. El progreso por sentencia y los checksums deben conservarse. Si hay un fallo entre DDL y registro de progreso, inspeccionar el estado físico antes de reanudar; no avanzar el cursor ni ignorar errores. [Atomic DDL 9.7](https://dev.mysql.com/doc/refman/9.7/en/atomic-ddl.html).

## Secuencia propuesta para una aplicación posterior

1. Cerrar las correcciones anteriores en un plan versionado, con checksums y criterios de comparación. Inventariar instancias API, cron financiero y workers que escriben. Confirmar responsable del backup, de rollback y de clasificación de grants.
2. Obtener y restaurar una copia aislada en MySQL 9.7.2; mantener integraciones de correo, push, pagos y webhooks deshabilitadas. La copia contiene datos sensibles y debe quedar en un entorno autorizado, con acceso y retención controlados.
3. Repetir metadatos y agregados. Ensayar en orden `000`, `001`, `002`, `003`, `004`, `005` corregida, `006`, `007`, `008`, `009`, antes de habilitar billing. Verificar conservación de timestamps durante el paso `005`. El runner incluido sólo acepta loopback y bases `_local/_test/_staging`; no saltar sus guardas para apuntarlo a producción.
4. Validar tracker/checksums, todas las tablas/columnas/índices, 32 triggers, motores, zonas horarias, conteos y ausencia de warnings. Comparar importes y timestamps legacy mediante verificaciones controladas, sin volcarlos a logs. Ejecutar pruebas de transacciones/outbox, Momentum, recuperación y billing, incluidas identidades que sólo difieren en mayúsculas.
5. Programar una ventana con escritores detenidos, drenar requests y confirmar cero transacciones prolongadas. Tomar backup final y repetir preflight. Aplicar únicamente por el canal remoto del operador, expresamente autorizado para ese momento; este informe y la elección “revisar” no son esa autorización.
6. Arrancar con readiness y flags de rollout, verificar login y lecturas financieras antes de habilitar progresivamente escrituras y workers. Los recibos y webhooks requieren claves/provider setup revisados; probarlos en los entornos de proveedor correspondientes, sin suponerlos verificados por esta revisión SQL.
7. Vigilar errores, locks, outbox, contratos y discrepancias de entitlement. Mantener calendario de los dos grants temporales y reconciliar contratos legacy. Una reversión de aplicación conserva el esquema aditivo; cualquier restauración completa de datos requiere mantener la pausa de escritores y el procedimiento de backup ensayado.

## Identidad de los archivos revisados

Los siguientes hashes identifican los artefactos locales actuales tras las correcciones; no indican aplicación remota. `005` cambió respecto al snapshot inicial y `009` se añadió después. El checksum histórico de `005` figura en la explicación del hallazgo, no en este manifiesto actual.

| Migración | SHA-256 |
| --- | --- |
| `000_legacy_baseline.sql` | `65a8795e9e8c3ffd6ea9209638b12dadd7686d7f3646084e6c789edf2b68fac1` |
| `001_platform.sql` | `976928ca37f8cc663e375e37db6b2d786a2adaf2890ad4b38cb632531f4385a9` |
| `002_billing.sql` | `49fa561196328f48e98a69c97cad82e709273acf9719ee58f58a52b1e6c12d62` |
| `003_recovery.sql` | `3182956312b8098f401684e129378029e3d69063bf98fe791517ee5ae4071970` |
| `004_domain_outbox.sql` | `2570810f080056836b19e2ea64b04069068823cf81eb0777e1b4be2687d2625a` |
| `005_financial_identity.sql` | `c35a6cb72bdcf68ae95f38d12341a3c2af6b5ba53ff1a2a247ab5ed41bb11909` |
| `006_analytics.sql` | `7b5d8f5c7969c91337e4fc8302ef80f6675d6e1c02795e7631e6e2dbafd9b8aa` |
| `007_momentum_preferences.sql` | `8be6c4d2b48a3f6bfeb5a2421da876c04c36beb2bae4e0fb77c4e88c7f9f4193` |
| `008_recovery_email_index.sql` | `5a67bc6e394d63f1c6d09ba738490f5efa4c38b3db23d1c28f45ce5662522a85` |
| `009_billing_identity_collation.sql` | `554e0ca722c02fda8b3e5ca631bbfbf0601cad1678452baa305869ae6e126713` |
