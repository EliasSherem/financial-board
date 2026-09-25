# Rendimiento del servidor y visibilidad de Momentum

Actualización posterior: [carga y pasos de Momentum](momentum-loading-and-copy.md), del 25 de septiembre, reduce la lectura estable a seis viajes SQL y registra la revisión actualmente desplegada. Las cifras y revisiones siguientes documentan el trabajo anterior.

Trabajo del 24 de septiembre de 2026 a petición del propietario. Conserva los cambios existentes del repositorio y la autorización de despliegue registrada en `cloud-run-deployment.md`. No requiere nuevas migraciones de producción.

## Diagnóstico medido

Las compilaciones Flutter debug usan `127.0.0.1:3001` en iOS y `10.0.2.2:3001` en Android, salvo `API_BASE_URL`. La API local utiliza la base remota. Su `.env` no incluía `MOMENTUM_ENABLED`; se activó y se reinició la API. No se activó un segundo worker local contra la base remota. `doctor:server` confirmó las migraciones instaladas y la salud local devolvió HTTP 200.

Después de activar el flag, una petición real de Momentum de la sesión ya abierta en el simulador tardó **38,24 s**, devolviendo HTTP 200 y `enabled:true`. Flutter abandonaba la petición a los 15 s y conservaba un caché `enabled:false`; la tarjeta ocultaba también el error. Esto explica por qué activar el flag no bastaba.

Comparación antes/después, misma API local y sesión existente, peticiones secuenciales, sin imprimir tokens ni contenido financiero (una muestra por ruta; no es una prueba de carga ni una garantía de percentiles):

| GET | HTTP antes/después | Segundos antes | Segundos después |
| --- | --- | ---: | ---: |
| `/api/accounts` | 200 / 200 | 1,691 | 0,852 |
| `/api/transactions` | 200 / 200 | 1,963 | 0,925 |
| `/api/projects` | 200 / 200 | 1,928 | 0,688 |
| `/api/payments` | 200 / 200 | 0,826 | 0,484 |
| `/api/balance-history` | 200 / 200 | 6,522 | 1,051 |
| `/api/investments` | 200 / 200 | 2,092 | 0,750 |
| `/api/expense-categories` | 200 / 200 | 0,523 | 0,530 |
| `/api/engagement/me` | 200 / 200 | 38,049 | 15,746 |

Evidencia de tiempos y tamaños, sin payloads: `/tmp/finsight-performance-before.json` y `/tmp/finsight-performance-after.json`, también archivadas en el directorio privado de despliegue. La distancia entre la API local y MySQL contribuye al coste por consulta. Estas cifras no describen la latencia de Cloud Run. Categorías no mejoró en esta muestra; todas las respuestas conservaron su tamaño, aunque esa coincidencia no sustituye las pruebas de contenido.

## Cambios realizados

- Momentum: agrupar consultas de conteos y escrituras de misiones/logros/recompensas, omitir secciones financieras que la respuesta de progreso no utiliza, conservando locks, caps y autoridad del servidor.
- Finanzas: agrupar la reparación del historial, quitar consultas/logs redundantes, reutilizar agregaciones de aportaciones y evitar procesar reglas salariales futuras.
- Permisos: consulta actual a contratos/grants sin escribir ni bloquear al usuario en cada lectura financiera. La materialización de `users.is_pro` conserva su transacción y sólo escribe cuando cambia.
- Móvil: refrescar Momentum junto al Dashboard, mostrar carga/reintento si falla un caché deshabilitado, permitir una espera acotada para evaluaciones lentas y reducir peticiones/cargas seriales innecesarias.

Las respuestas permanecen autoritativas; no se introduce caché de permisos ni de saldos. El permiso Pro se consulta con una sentencia contra contratos/grants vigentes; un test demuestra que no espera el bloqueo exclusivo de Momentum. El historial conserva meses existentes y aritmética decimal. La reparación de 205 cuentas vacías usa cuatro consultas en vez de 1.026. La prueba de evaluación completa de Momentum impone un máximo de 42 consultas, frente a unas 120–130 observadas por inspección del flujo anterior; este último número es una estimación de código.

Las pruebas SQL se ejecutan con fixtures sintéticos en MySQL 9.7.2, loopback `13307`, base `finsight_performance_test`; nunca contra la base remota. Un intento previo contra el entorno aislado antiguo detectó un checksum histórico distinto y se detuvo; se preparó una base nueva sin modificar ni saltarse ese checksum.

Flutter ahora realiza seis peticiones del Dashboard en vez de siete: no pedía ningún dato de inversiones que después utilizara. Transacciones y formularios cargan listas independientes en paralelo conservando sus fallbacks. Las evaluaciones de Momentum tienen un límite específico de 90 s para tolerar la conexión local a la base remota; el límite general continúa siendo 15 s, sin reintento automático de escrituras. Esto evita abandonar respuestas válidas, pero no se presenta como una optimización del servidor.

## Verificación local

- `npm run check:server`: aprobado.
- `FINSIGHT_TEST_PORT=13307 FINSIGHT_TEST_DATABASE=finsight_performance_test npm run test:db`: **99/99**, cero fallos y cero omitidas. Incluye equivalencia de permisos, saldos e inversiones; reglas salariales futuras; caps, replay concurrente y conservación de objetivos/fechas en operaciones agrupadas.
- `flutter test --no-pub`: **32/32**. Incluye caché Momentum desactivada → error → reintento → estado autorizado, actualización del Dashboard, respuesta lenta, timeout acotado y cargas paralelas.
- Análisis de diez archivos Flutter: cero diagnósticos nuevos; los **52 infos existentes** coinciden con el análisis anterior por archivo y código. No se declara el análisis estricto completamente limpio.
- Build iOS arm64 de simulador: aprobado. Aplicación reinstalada conservando la sesión; se observó la tarjeta Momentum y se comprobó que recibió `enabled:true` y misiones del servidor. Captura local: `/tmp/finsight-momentum-visible-ios.png`.
- Build Android release AAB: aprobado. `mobile/build/app/outputs/bundle/release/app-release.aab`, SHA-256 `033c1b77c72c25ec95b1c909c76151e645b3da99a23ef3c36e194a742b6d7a61`.
- Revisión independiente del cambio de Momentum: no encontró diferencias concretas en reglas, caps, criterios de recibos ni evidencia de revisiones.

No se publicó en tiendas ni se comprobó un dispositivo Android físico. La verificación visual corresponde al simulador iOS, no a ambas plataformas.

## Despliegue

Imagen construida por [Cloud Build](https://console.cloud.google.com/cloud-build/builds;region=us-central1/2f114b11-ca9f-41c1-9dbe-94735aaf7cfb?project=finsight-472418), digest `sha256:970757bb619c5c433ed8ed506d93e2f3093dea0371d468243684af43db83d452`. Revisión `financial-api-perf-260924-2016` desplegada en `finsight-472418`, `us-central1`, y promovida al **100 %** tras verificar salud HTTP 200 y protección HTTP 401 de cuentas, Momentum y contratos. La etiqueta temporal de validación fue retirada.

Se conservaron variables, referencias de secretos, recursos y cuenta de servicio. La salud del dominio público de API devuelve 200; la web y la API local también responden 200. Las comprobaciones anónimas no representan una medición autenticada de rendimiento en Cloud Run. La sesión real y los tiempos de datos anteriores corresponden a la API local contra la base remota. No se modificó ni desplegó el frontend web.

Evidencia privada sin archivos de secretos resueltos: `/Users/elias/Library/Application Support/FinSight/deployments/20260924T201612Z-performance`. Logs de pruebas, build, controles de configuración y verificaciones de runtime se conservan allí. Los dos procesos MySQL de pruebas iniciados para este trabajo se detuvieron; la API local continúa en el puerto 3001.

Rollback de código, si se necesitara: devolver el tráfico API a `financial-api-platform-260924-fix1` en el mismo proyecto/región. No hay migración de schema que revertir para esta optimización. No se ejecutó rollback.
