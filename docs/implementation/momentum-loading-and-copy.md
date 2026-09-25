# Momentum: carga y pasos más breves

Corrección del 25 de septiembre de 2026, posterior al [rediseño del perfil](momentum-profile-redesign.md).

## Resultado medido

Con la misma sesión existente y la API local conectada a la base remota, `GET /api/engagement/me` pasó de **11,754 y 12,561 s** a **2,729, 2,753 y 2,580 s**. Media: **12,157 → 2,687 s**, reducción del **77,9 %**. Todas esas respuestas fueron HTTP 200 y conservaron las 27 misiones de esa cuenta.

Son muestras secuenciales de una cuenta, no percentiles ni una prueba de carga. No representan tiempos autenticados de Cloud Run: la sesión del entorno local no fue aceptada por producción. Las pruebas automatizadas utilizaron exclusivamente MySQL local aislado; la medición remota se hizo mediante el endpoint normal de la aplicación.

## Servidor

La evaluación anterior hacía muchas consultas consecutivas y reescribía misiones y logros aunque nada hubiera cambiado. Ahora agrupa lecturas dentro de la misma transacción y persiste sólo cambios efectivos. Una lectura estable necesita **seis viajes a MySQL, incluidos BEGIN y COMMIT, sin INSERT, UPDATE ni DELETE**. El endpoint añade sus comprobaciones de autenticación, límites y zona horaria.

No se almacena una respuesta temporal en el servidor: cada evaluación consulta datos y permisos actuales. Se mantienen los bloqueos por usuario, los límites de XP, la idempotencia y las revisiones explícitas con evidencia fresca. Las respuestas de lectura agrupan fechas UTC con milisegundos; los datos financieros de las revisiones conservan los tipos de mysql2.

También se evita recolectar dos veces el mismo contexto al abrir una revisión. Las confirmaciones vuelven a comprobar sus datos. El worker conserva sus evaluaciones necesarias, pero reutiliza el contexto de la primera dentro de la misma operación.

## Web y móvil

- Las lecturas simultáneas comparten una petición. Abrir la pantalla durante la carga inicial ya no programa otra carga completa.
- Eventos, revisiones y preferencias adoptan el estado que devuelve su POST. Reconocer una insignia sólo actualiza su marca de vista después del éxito del servidor.
- El progreso guardado se muestra mientras se actualiza. La frescura de 30 segundos evita repetir lecturas al regresar; una modificación financiera, un reintento explícito o el cambio de período requieren actualizar.
- La caché web usa sessionStorage, una huella de sesión y usuario, con un máximo de diez minutos; no copia el JWT a esa caché y se elimina al cerrar sesión. El caché móvil conserva sus controles de cuenta, sesión y bloqueo biométrico.
- Se descartan respuestas antiguas y se conserva una nueva actualización cuando hay cambios financieros durante una petición. La invalidación web incluye las rutas reales de categorías, subcategorías, clientes y cuotas de crédito.

## Instrucciones

Se simplificaron los textos comunes del catálogo: **41 pasos** con títulos de hasta cinco palabras e instrucciones de hasta doce, en español e inglés, y requisitos breves para **34 insignias**. Por ejemplo, «Cinco transacciones canónicas» pasa a «Añade 5 movimientos».

Cada tarjeta muestra una acción y el progreso. Los requisitos y la recompensa se consultan en «Detalles»; las actividades completadas están plegadas. La revisión sigue necesitando confirmar las secciones correspondientes, con una introducción breve y ayuda opcional. Los campos de reglas, objetivos, recompensas, capacidades y destinos del catálogo permanecen idénticos.

Capturas con datos sintéticos: [pasos web](previews/momentum-steps-web.png) y [pasos móvil](previews/momentum-steps-mobile.png).

## Validación

- Servidor: **106/106 pruebas**, sin omisiones, en MySQL 9.7.2 aislado (`127.0.0.1:13307`, base `finsight_performance_test`); TypeScript aprobado. Incluye lectura sin escrituras, cambios financieros visibles en la siguiente lectura, cuatro replays sin XP duplicado, expiración de Pro, revisiones concurrentes, fechas, decimales e historial de ritmo.
- Web: **33 pruebas** de cliente/transporte/invalidación y build aprobados. Lint de Momentum y authApi correcto; api.ts conserva sus 58 diagnósticos anteriores, sin nuevos en el bloque cambiado. QA de perfil en cinco variantes y de pasos/revisión en tres: español/inglés, claro/oscuro, 320/390/1440 px, sin desbordamiento, errores de JavaScript ni peticiones externas. La revisión sólo envía un POST al confirmar explícitamente.
- Flutter: **101/101 pruebas**, análisis focal sin incidencias; incluye sesión y biometría, peticiones compartidas, respuestas fuera de orden, marca de vista sin recarga y texto al 200 % en 320 px.
- Android release AAB y iOS Debug arm64 para simulador compilados. iOS instalado sobre la app existente y abierto. SHA-256 del AAB: `15d3142eb38b606aa7b9333e81ca8839e0d3a531e21572c851606819029b2dd4`. No se publicó en tiendas.

El test de latencia SQL añade 15 ms artificiales por viaje: primera evaluación 20 viajes/397 ms; lectura estable seis viajes/124 ms. Sirve para detectar regresiones en cantidad de consultas, no para estimar latencia de producción.

## Despliegue

La API local y Cloud Run ya ejecutan esta versión. Proyecto `finsight-472418`, región `us-central1`. Verificación final **2026-09-25 09:07:26 UTC**:

| Servicio | Revisión | Tráfico |
| --- | --- | ---: |
| API | `financial-api-momentum-260925-0857` | 100 % |
| Web | `financial-web-momentum-260925-0857` | 100 % |

Builds correctos: [API](https://console.cloud.google.com/cloud-build/builds;region=us-central1/bd75a604-1612-4e83-a3b3-3926c79f56a5?project=finsight-472418) y [web](https://console.cloud.google.com/cloud-build/builds;region=us-central1/02eba095-2656-4df3-97e6-020e05296395?project=finsight-472418). La imagen de API incluye typecheck y pruebas sin base externa; la web incluye compilación y `nginx -t`.

- Digest API: `sha256:459bba15e348c367a884bac041998a3a1baed116189570684cf7ad7e45ab4b91`.
- Digest web: `sha256:e298046caa17db776a78887bf32cf1243b26b57f5f499b0d5c7107e41806bb2d`.
- Candidatas verificadas antes de promoverlas; se conservaron configuración de runtime, variables y referencias de secretos. Etiquetas de validación retiradas.
- `https://finsight.com.mx` sirve los mismos hashes de JavaScript y CSS comprobados en la candidata. Recursos de Momentum y rutas SPA responden 200; recuperación conserva `no-store` y `no-referrer`.
- Salud de API pública: 200. Momentum anónimo: 401. Las condiciones de ambos servicios están listas y sus revisiones reciben el 100 % del tráfico. Consulta inicial de logs de la revisión nueva sin errores de arranque o workers coincidentes; no equivale a una observación de larga duración.
- Sin nuevas migraciones de producción ni cambios de reglas o recompensas.

Evidencia privada local de build, configuración y comprobaciones: `~/Library/Application Support/FinSight/deployments/20260925T085745Z-momentum-speed`. Las mediciones autenticadas son de la API local; los controles públicos comprueban distribución, disponibilidad y protección de rutas.
