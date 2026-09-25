# Salario automático y notificaciones móviles

Actualización del 25 de septiembre de 2026. API publicada en `financial-api-salary-push-260925-0931`, proyecto `finsight-472418`, región `us-central1`, con el 100 % del tráfico. Verificación pública: 09:39:27 UTC. El frontend conserva `financial-web-momentum-260925-0857`; este cambio afecta al servidor y a Flutter.

## Salarios

Al abrir la pantalla móvil, las lecturas de cuentas, transacciones y salarios podían ejecutarse juntas. El código anterior comprobaba si existía un movimiento y luego lo insertaba sin una transacción. Dos solicitudes podían pasar la comprobación, registrar el mismo vencimiento y aumentar el saldo dos veces.

Ahora cada vencimiento se lee bajo un bloqueo en la base compartida por las instancias del servidor. El ingreso, saldo, historial, aportación de inversión y avance de `next_date` se confirman juntos. Un error revierte el lote y conserva la fecha pendiente. Los lotes tienen hasta ocho vencimientos; el límite de 48 por regla no elimina atrasos. Crear una regla y su primer ingreso también es atómico. Pausar o editar una regla no retrocede una fecha ya consumida. Las fechas de calendario conservan el último día del mes y no cambian por convertirlas a UTC.

En móvil, Guardar se deshabilita durante la operación y rechaza una segunda pulsación. Los errores permanecen visibles en el formulario. Se normalizaron los nombres del DTO y los cambios parciales omiten campos no suministrados: activar una regla ya no borra su cuenta ni calendario. No se reintenta automáticamente un POST. Un timeout después de un commit aún requiere revisar las reglas antes de volver a crearla; no se añadió un protocolo de idempotencia para creaciones independientes.

No se modificaron movimientos ni saldos históricos. Una inspección de sólo lectura identificó 27 grupos de movimientos coincidentes, con 49 filas adicionales posibles, y ninguna regla completamente duplicada. Es una señal para revisión, no prueba suficiente para borrar: los movimientos anteriores no guardan la regla que los originó. Dos reglas distintas y un ingreso manual coincidente siguen siendo operaciones válidas separadas.

## Push en Android e iOS

La credencial anterior de Cloud Run apuntaba a Firebase `finsight-8b0ec`; ambos clientes usan `finsight-2b791`. La nueva revisión utiliza `FCM_PROJECT_ID=finsight-2b791` y la identidad de servicio de Cloud Run mediante ADC. Se habilitó la API FCM en el proyecto del servidor y se concedió a esa identidad el rol de envío de Firebase en el proyecto destino. Se retiró de la revisión la referencia a la credencial anterior; el secreto no se borró. El resto de la configuración del servicio se comparó y conservó, incluida la instancia mínima y CPU continua del cron.

La migración `010_notification_delivery.sql` amplía los tokens sin truncarlos, usa comparación sensible a mayúsculas y crea evidencia de entrega por evento/dispositivo. Se aplicó a la base remota tras las pruebas aisladas, con respaldo cifrado y comprobación exacta de conservación de los 65 registros originales. No modifica tablas financieras. Los checksums de `000–009` coinciden y el diagnóstico de arranque reconoce `010`.

Los errores de correo y push quedan aislados. Los rechazos transitorios se reintentan por dispositivo, respetando backoff y Retry-After; los aceptados no se repiten. Los tokens se retiran únicamente ante `UNREGISTERED`. Un resultado incierto se registra como `unknown` para no repetir a ciegas un aviso que quizá llegó. Los eventos históricos sin evidencia de entrega no se reproducen. Detalles y límites: [entrega push](push-delivery.md).

El registro de dispositivos se serializa entre cuentas e instancias. Un token confirmado se asocia a una sola cuenta y el logout sólo puede desvincular su propio registro. Los tokens antiguos asociados a varias cuentas se excluyen hasta que el teléfono confirme la cuenta actual. Las notificaciones no incluyen tokens ni credenciales en los logs.

Flutter instala los listeners antes de adquirir el token, recupera fallos al volver al primer plano y espera al token APNs cuando tarda en estar disponible. Se corrigió la primera solicitud de permiso en Android y se mantienen reintentos acotados. El bloqueo biométrico conserva la asociación sin registrar una sesión bloqueada. iOS usa la presentación nativa para no duplicar una alerta con otra local. Runner tiene la capacidad Push y el entitlement APNs; los archivos de Firebase y los identificadores de las apps se conservan.

Inicialmente Firebase no tenía ninguna clave ni certificado APNs. El propietario creó y cargó una clave válida para Sandbox & Production. Se verificaron en la consola ambas entradas, para `mx.com.finsight`, con el equipo de Apple que usa Xcode. La clave privada fue gestionada por el propietario y no se copió al repositorio.

## Validación y publicación

- Servidor: **146/146 pruebas**, incluidas SQL sobre MySQL aislado; cero omitidas. TypeScript correcto. Concurrencia de nueve lecturas de salarios, rollback, creación atómica, dos dispositivos simultáneos, tres workers push, aislamiento entre propietarios y migraciones repetibles.
- Flutter: **119/119 pruebas**; análisis con cero errores y cero warnings. Permanecen 130 avisos informativos del código existente.
- Android: bundle release compilado y firma verificada. Se conserva la versión solicitada: `1.0.8`, `versionCode=52`, paquete `com.finsight.finsight`. SHA-256 `1e49bdb73d6bd4d9be9b9bbf2a419ef7fe017546922ff5f41bab2399260397e0`.
- iOS: compilación de simulador arm64 mediante Xcode correcta; instalada y arrancada en iPhone 17 Pro, con proceso activo en la comprobación posterior. El wrapper `flutter build ios --simulator` encontró una incompatibilidad de empaquetado de arquitecturas con Xcode 27; se validó con `xcodebuild`, destino genérico de simulador, `ARCHS=arm64`, `ONLY_ACTIVE_ARCH=YES` y sin firma. También se generó un archive Release firmado localmente con Apple Development, con app y widget en `1.0.9 (10)`; todavía no es una IPA exportada para App Store.
- Cloud Build: `41d970b5-7782-4d43-88ac-ee3f42693790`, con typecheck y pruebas sin DB dentro de la imagen. Imagen inmutable: `sha256:8f83428041d97e7b7bff41fba575e7801172b47f3fcb9348074836e828491769`.
- La candidata respondió salud 200 y rechazó con 401 las rutas protegidas sin sesión. Tras promoverla se verificaron el 100 % de tráfico, dominio público y URL Cloud Run. Se retiró la etiqueta temporal de validación.
- Un job temporal ejecutó `npm run doctor:push` con la misma imagen e identidad de Cloud Run. De diez registros Android recientes e inequívocos, FCM validó dos y declaró ocho `UNREGISTERED`. Se usó siempre `validate_only`; no se enviaron avisos ni se modificaron tokens durante esta prueba. El job fue eliminado después. [Referencia de validación FCM](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send).

La recepción visible en teléfonos físicos Android/iOS sigue sin verificarse. Hay que recompilar o instalar la app actualizada, abrirla con sesión activa y permitir las notificaciones para registrar el teléfono. La validación de FCM y la configuración APNs no equivalen a confirmar una alerta en pantalla. No se publicaron nuevas versiones en las tiendas.

## Entregables móviles

Carpeta local: `~/Desktop/FinSight-Releases/2026-09-25/`.

- `FinSight-android-1.0.8-52.aab`: bundle release firmado para subir a Google Play.
- `FinSight-ios-1.0.9-10.xcarchive`: archive para abrir en Xcode y continuar la distribución. La exportación/firma de distribución y la subida a App Store Connect siguen pendientes.

Para incrementar sólo iOS sin alterar la versión Android, Runner y su widget usan `MARKETING_VERSION=1.0.9` y `CURRENT_PROJECT_VERSION=10` en Xcode. `Runner/Info.plist` consume esas variables. Android conserva `pubspec.yaml` para el nombre de versión y su código explícito en Gradle. Las siguientes versiones iOS deben actualizar ambos targets; pasar únicamente `--build-name`/`--build-number` a Flutter ya no cambia estos valores nativos.

Evidencia operativa y respaldo fuera del repositorio: `~/Library/Application Support/FinSight/deployments/20260925T091920Z-salary-push/`.
