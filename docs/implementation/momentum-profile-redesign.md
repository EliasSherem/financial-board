# Momentum: perfil de logros

La vista principal de Momentum pasa de un resumen informativo a un perfil de progreso personal, tanto en web como en Flutter.

La [corrección posterior de carga y pasos](momentum-loading-and-copy.md) añade caché y deduplicación de peticiones, optimiza SQL y simplifica los textos. Ese registro contiene las revisiones actuales; el despliegue de este documento corresponde al rediseño inicial.

## Jerarquía visual

- Una cabecera con la insignia del nivel, el XP acumulado y el avance al siguiente nivel.
- Una colección de insignias como contenido principal. Las tarjetas muestran el logro y su estado; sus requisitos, progreso y recompensa se consultan al abrir el detalle.
- Un resumen semanal breve. Las actividades y sus acciones de revisión se despliegan a petición del usuario.
- Historial, reglas de XP, créditos y preferencias en un segundo nivel, sin ocupar la primera vista.
- Una tarjeta de inicio compacta que enlaza al perfil, sin repetir toda la información de Momentum.

Se reutilizan las insignias SVG de FinSight y los componentes visuales existentes. La interfaz mantiene versiones en español e inglés, temas claro y oscuro y estados de carga, desconexión y ausencia de progreso.

## Comportamiento conservado

Los valores de XP, niveles, ritmo y logros proceden del servidor. El rediseño no añade recompensas, no marca revisiones como completadas y no modifica las reglas de evaluación. Los reconocimientos de avisos siguen siendo explícitos; consultar un perfil o abrir una insignia no completa una misión. Las misiones, preferencias, créditos y revisiones siguen siendo accesibles.

## Validación del 25 de septiembre de 2026

- Web: compilación TypeScript/Vite y ESLint de los archivos modificados aprobados. Interacciones comprobadas en español e inglés, temas claro y oscuro, y anchuras de 320, 390 y 1440 px: detalle de insignia, cierre con Escape y restitución del foco, filtros de colección y enlace a revisión semanal. Sin desbordamiento horizontal ni errores de JavaScript en esos escenarios.
- La tarjeta de inicio y el estado de desconexión con datos almacenados se comprobaron por separado. Las capturas usan componentes reales con un perfil sintético: 34 insignias, tres obtenidas y 300 XP. No se realizaron acciones de progreso sobre cuentas reales.
- Flutter: **91/91 pruebas aprobadas**, incluidas las regresiones de sesión y biometría y siete pruebas del nuevo perfil. Se comprobaron navegación a actividades y revisión explícita, detalle y reconocimiento de insignias, español/inglés, ambos temas y texto al 200 % en 320 px. Análisis estático de los cuatro archivos modificados sin incidencias.
- Android: `flutter build appbundle --release` aprobado; artefacto en `mobile/build/app/outputs/bundle/release/app-release.aab`. SHA-256: `504fc093dff37c32897632d0350970ca3e7ac23ef8a67a07884303cb2de85515`.
- iOS: build Debug para simulador arm64 aprobado mediante Xcode; instalado sobre la app existente y abierto en el simulador iPhone 17 Pro. No se ha publicado una versión en las tiendas ni realizado una prueba en dispositivo físico.

Capturas de referencia con datos sintéticos: [perfil web](previews/momentum-profile-web.png) y [perfil móvil](previews/momentum-profile-mobile.png). La captura web aísla los componentes de Momentum del marco de navegación de la aplicación; la móvil procede del renderizador de widgets de Flutter.

## Publicación web

Proyecto `finsight-472418`, región `us-central1`, servicio `financial-web`. La revisión **`financial-web-momentum-260925-0826`** recibe el **100 % del tráfico**. Verificación final: **2026-09-25 08:35:39 UTC**.

- [Cloud Build](https://console.cloud.google.com/cloud-build/builds;region=us-central1/5baa301c-0314-456c-8dd4-cf0f5fe99943?project=finsight-472418): correcto, incluida compilación y comprobación de configuración nginx.
- Imagen desplegada por digest: `us-central1-docker.pkg.dev/finsight-472418/containers/financial-web@sha256:d1657d76cfbafa50bd041b68ce00e6a50065699f82fa0177ac668c83b0abc920`.
- Candidata validada antes de dirigir tráfico: página principal, ruta `/momentum`, JavaScript, CSS, manifiesto y variantes SVG devuelven 200; recuperación mantiene `no-store` y `no-referrer`.
- El dominio `https://finsight.com.mx` sirve los mismos hashes de JavaScript y CSS que la candidata. Condiciones Ready, ConfigurationsReady y RoutesReady correctas. Etiqueta temporal de validación retirada.
- API existente `financial-api-perf-260924-2016` mantiene el 100 % del tráfico y `/api/health` responde 200. Este rediseño no necesitó despliegue de API ni migración de datos.

La evidencia de build, revisión y comprobaciones HTTP se conserva fuera del repositorio, en el archivo local de despliegues de FinSight. Las comprobaciones públicas verifican distribución de recursos; las interacciones autenticadas del perfil se validaron con datos sintéticos aislados.
