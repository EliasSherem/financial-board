# Ensayo de migración remota — aplicado sólo a copias locales

**Seguimiento posterior:** la aplicación remota autorizada y el despliegue en curso están documentados en [cloud-run-deployment.md](cloud-run-deployment.md). Los resultados de este informe corresponden al ensayo local previo.

El 24 de septiembre de 2026 se creó un respaldo lógico cifrado de la base configurada, se restauró en una instancia aislada de **MySQL 9.7.2** y se aplicaron las diez migraciones `000–009` a esa copia. La revisión remota anterior está en [remote-migration-review.md](remote-migration-review.md).

**Resultado:** la copia migrada supera readiness y conserva todos los campos originales de las **1.409 filas de las 22 tablas legacy**. La suite sintética separada pasa **83/83**, sin fallos ni omisiones. La base remota no recibió DDL/DML; sigue sin `platform_migrations`. No se cambió `.env`, arrancó la aplicación con datos reales, ejecutó workers ni llamó a proveedores.

## Respaldo y restauración comprobados

- Ubicación privada, fuera del repositorio: `/Users/elias/Library/Application Support/FinSight/migration-rehearsals/20260924T183034023Z/`.
- Archivo: `legacy.sql.gz.aes256gcm`, **58.998 bytes**. SHA-256 del archivo cifrado: `6fbca248902249d03ba4a4ff5d7076c1ed759b488afd4fb018afe544695ed9de`.
- Compresión gzip y cifrado autenticado AES-256-GCM con clave aleatoria de 32 bytes. La clave está en el directorio separado `FinSight/backup-keys`; su ruta exacta, IV y etiqueta de autenticación figuran en `backup-manifest.json`. Directorios con modo `0700`, archivos privados con `0600`. La clave permanece en este Mac: esto no constituye un respaldo fuera del equipo.
- No se guardó un dump SQL en texto claro. Se verificaron checksum y autenticación GCM antes de restaurar mediante stdin del cliente local. La restauración terminó con código 0 y stderr vacío.
- El inventario de origen confirmó 22 tablas InnoDB y cero vistas, triggers, rutinas y eventos. El dump incluye las opciones para esos objetos y no incluye usuarios/permisos globales del servidor.

Se usó `mysqldump` 9.7.2 con `--defaults-file` privado temporal, `--no-login-paths`, `--single-transaction`, `--skip-lock-tables`, `--no-tablespaces`, `--set-gtid-purged=OFF`, `--routines`, `--events`, `--triggers`, `--hex-blob`, `--column-statistics=0`, `--skip-comments` y `--skip-add-locks`. Las credenciales no se pasaron en argumentos ni se imprimieron. El archivo temporal de conexión remota se eliminó al terminar. El dump final terminó con código 0 y stderr vacío. Dos intentos previos rechazaron una opción de conexión no admitida por el cliente; no llegaron a exportar datos.

La transacción del dump proporciona una instantánea de las tablas InnoDB; no se coordinó una ventana contra DDL concurrente durante este ensayo. Antes del cambio real hay que detener escritores y tomar un respaldo nuevo. [Semántica y restricciones de mysqldump 9.7](https://dev.mysql.com/doc/refman/9.7/en/mysqldump.html).

## Entorno aislado

Homebrew instaló únicamente el keg `mysql@9.7` **9.7.2_2**, omitiendo `post_install` y enlaces globales. No se inició un servicio de login ni se usó el datadir existente de MySQL 8.4. La instancia temporal usó un datadir privado nuevo, puerto loopback `13307`, contraseña local aleatoria, binlog y event scheduler desactivados.

La copia recibió el mismo `sql_mode` observado remotamente, sesión UTC y `utf8mb4_0900_ai_ci`. La versión SQL coincide; el sistema operativo y `lower_case_table_names` no: la instancia macOS usa `2`. Las tablas de este esquema usan nombres en minúsculas. No se presenta este ensayo como una réplica idéntica de la infraestructura remota.

Se cargaron las zonas del sistema local. Las conversiones SQL para `America/Mexico_City` y `America/New_York` devolvieron valores válidos. La suite de pruebas se ejecutó en otra base vacía y sintética; nunca sobre los usuarios restaurados.

## Evidencia de aceptación

| Comprobación | Resultado |
| --- | --- |
| Migraciones completas, checksum y cursor de cada archivo | 10/10 coinciden con los artefactos revisados |
| Tablas tras migrar | 54, todas InnoDB |
| Triggers | 32; nombres exactos de los archivos |
| Columnas originales de las 22 tablas | Hash SHA-256 idéntico antes/después; 1.409 filas |
| Transacciones históricas | 550 identidades canónicas correctas; importes y timestamps originales idénticos |
| Outbox generado por migrar | 0 eventos |
| Otras tablas nuevas que debían quedar vacías | 28/28 vacías, incluidos roles, analytics, Momentum y recuperación |
| Contratos importados | 9 Stripe + 2 Apple; identidad exacta, propietario, producto, estado, vencimiento y entorno coinciden |
| Verificación/ingresos inventados | Ninguno; contratos `legacy`, `verified=false`, sin importes ni moneda deducidos |
| Grants | 2 exenciones existentes + 2 `legacy_unknown`, propietarios exactos; expiración de 30 días correcta |
| Nuevas columnas de usuarios | `credential_kind=unknown`, `token_version=0`, normalización de email correcta |
| Columnas de identidad con colación binaria | 5/5 `utf8mb4_0900_bin` |
| `doctor:server` contra la copia | OK |
| Repetición del runner | PASS; hashes legacy y tracker, incluidos timestamps, idénticos |
| Suite sintética en MySQL 9.7.2 | 83/83 PASS; cero skips/fallos |
| `npm run check:server` | PASS |

Los hashes se calcularon sobre todas las columnas **preexistentes**, conservando NULL, decimales como cadenas, fechas UTC, mayúsculas, espacios y contraseñas/recibos originales; se ordenaron las filas serializadas y sólo se guardaron conteos y hashes. No se expusieron filas privadas. Se verificaron aparte las columnas nuevas, las identidades importadas y la ausencia de filas nuevas no previstas.

El primer pase de migraciones tardó **567 ms en esta instancia local**, sin warnings de nivel Warning/Error; hubo 22 notas `1050` de tablas legacy que ya existían, previstas por `CREATE TABLE IF NOT EXISTS`. La repetición produjo una nota `1050` del tracker y diez warnings `1062` previstos por sus `INSERT IGNORE` de registros existentes. No son pérdida de contratos ni truncamientos. Estos tiempos no predicen metadata locks ni duración en producción.

La primera suite terminó 82/83 porque una prueba accedía a `possible_keys` de un `EXPLAIN` implícito. Esta instancia devuelve `@@explain_format=TREE`. Se cambió sólo esa consulta de prueba a `EXPLAIN FORMAT=TRADITIONAL`, conservando la aserción sobre `idx_users_recovery_email`; la repetición completa dio 83/83. No se modificaron consultas de recuperación ni migraciones por este ajuste. [FORMAT en MySQL 9.7](https://dev.mysql.com/doc/refman/9.7/en/explain.html).

Los manifiestos, hashes antes/después, auditoría de warnings, resultado de invariantes y logs de las suites quedan en el directorio privado del respaldo. El servidor temporal se detiene y el datadir restaurado se elimina al cerrar el ensayo, conservando el respaldo cifrado y su clave.

## Paso pendiente para desbloquear el servidor configurado

El doctor es de sólo lectura: repetirlo no instala las migraciones. Queda aplicar **estos mismos archivos `000–009`** a la base remota durante una ventana con API, crons y workers escritores detenidos, con preflight y respaldo final nuevos. DDL no ofrece rollback global; conservar el tracker y no saltar errores/cursors si se interrumpe.

Esa aplicación requiere una instrucción nueva del propietario: el prompt original prohíbe ejecutar migraciones en producción, y la autorización posterior fue **revisar** la base remota. El ensayo no levanta esa restricción. No se ha configurado un túnel ni alterado las guardas locales del runner para eludirla.

Antes de arrancar bajo `NODE_ENV=production` también hay que configurar un `JWT_SECRET` de al menos 32 caracteres mediante gestión de secretos; el valor actualmente observado no cumple esa longitud. Su rotación puede invalidar sesiones existentes. La migración no sustituye las configuraciones y pruebas externas de pagos, correo o notificaciones indicadas en el runbook general.
