# Landing editorial y nueva coreografía 3D

25 de septiembre de 2026. **Publicada y verificada:** `financial-web-editorial-260925-105943` recibe el 100 % del tráfico. La comprobación HTTP pública terminó correctamente a las **11:04:23 UTC**. El propietario autorizó publicar después de corregir los iconos superpuestos de Momentum. Sustituye a `financial-web-landing-260925-102523`.

La petición posterior del propietario amplía el rediseño hacia una presentación y navegación inspiradas en Apple: portada centrada, tipografía grande, superficies neutras, más espacio y un escenario 3D con protagonismo. La barra fija incluye indicador de sección, acceso y registro; en móvil usa un menú desplegable con enlaces, idioma y acceso. Escape lo cierra y devuelve el foco. Las anclas compensan la altura de la barra. El estilo claro está acotado a la landing y no modifica la preferencia global del tema.

La animación conserva Three.js y ahora tiene una coreografía de 16 segundos: entran tarjetas de movimientos, se construyen las barras y la línea del gráfico con el presupuesto, y emerge una insignia original de Momentum. Los datos están identificados como ejemplo. Hay control de pausa, parada fuera de vista o al ocultar la pestaña, y una composición estática con movimiento reducido. El módulo se carga por separado; no se eliminó el coste del motor 3D ni se afirma una mejora medida de rendimiento.

Las demostraciones de Cuentas, Movimientos, Presupuestos y Revisión incorporan trazado del gráfico, revelado de su área, crecimiento de barras y entradas de filas, sólo al mostrarse. Las transiciones entre pestañas son direccionales y la altura del contenedor se mantiene. La selección por teclado, los paneles inactivos `inert` y los estados finales sin movimiento se conservan.

Momentum presenta un perfil de ejemplo con una entrada coordinada de nivel e insignias. El contenido general se redujo a funciones, Momentum, beneficios breves, planes y descargas. Se conservaron las rutas públicas, los enlaces correctos a tiendas y los precios declarados previamente; este cambio no verifica ni modifica la configuración de facturación de los proveedores.

## Verificación

- Compilación TypeScript/Vite, ESLint de los tres TSX modificados y `git diff --check`: correctos.
- Revisión manual en Safari a 320, 390, 768 y 1280 px, sin desbordamiento horizontal; español e inglés.
- Menú móvil, cambio de idioma y Escape con retorno de foco comprobados.
- Navegación mediante flecha derecha desde Presupuestos a Revisión comprobada.
- Las tres etapas de la escena 3D se observaron en fotogramas separados; encuadre móvil y escritorio revisados.
- Se corrigió el contraste de textos pequeños y un texto duplicado del escenario que quedaba detrás de una tarjeta.
- Tras la revisión del propietario, la insignia de la portada usa `public/landing/momentum-badge.svg`, con un único ojo, sin el pequeño gráfico superpuesto. El gráfico termina de desaparecer a los 10.15 s y Momentum entra a los 10.3 s. Se comprobó la insignia corregida en Safari y la entrega HTTP 200 del SVG.
- La preferencia de movimiento reducido se revisó en el código; no se cambió la configuración del sistema durante la prueba.

Archivos: `Landing.tsx`, `landing.css`, `LandingHeroScene.tsx`, `LandingHeroScene.css`, `AppCarousel.tsx` y `public/landing/momentum-badge.svg`. Los logs locales finales están en `/tmp/finsight-editorial-publish-build.log` y `/tmp/finsight-editorial-publish-lint.log`. El build local corregido genera `index-BdvIzVrg.js`, `index-FFfU_89k.css` y `LandingHeroScene-CrGJ-JYo.js`; mantiene la advertencia de Vite sobre chunks grandes. Los argumentos públicos de producción pueden cambiar el hash del módulo principal durante Cloud Build.

## Publicación

- Servicio `financial-web`, proyecto `finsight-472418`, región `us-central1`.
- [Cloud Build](https://console.cloud.google.com/cloud-build/builds;region=us-central1/99e8cc76-a039-4525-8d25-f0c765215b6a?project=finsight-472418): `99e8cc76-a039-4525-8d25-f0c765215b6a`, `SUCCESS`; compilación de imagen y `nginx -t` correctos.
- Imagen inmutable: `sha256:6a482a5498aa2c791aa603f07766f9996186cd71eb95fd687f98b0dd7221c677`.
- Revisión: `financial-web-editorial-260925-105943`, 100 % del tráfico y etiqueta temporal retirada.
- Activos públicos: `index-BJae1z49.js`, `index-FFfU_89k.css`, `LandingHeroScene-CDVWUvMG.js` y `LandingHeroScene-Cnajr2z8.css`.

La candidata se desplegó por digest sin tráfico general. Safari mostró el gráfico y después la insignia corregida con un solo ojo, sin el mini gráfico ni la escena anterior detrás; se comprobó el botón de pausa. El smoke HTTP validó textos ES/EN, módulos JS/CSS, siete SVG contra sus hashes de fuente, rutas públicas, parámetros públicos de API/OAuth y las cabeceras de recuperación de contraseña. Tras la promoción, los hashes de los recursos de `https://finsight.com.mx` coinciden exactamente con los de la candidata.

Los ajustes de runtime, escalado e ingreso comprobados se conservaron. La API y la base de datos no se modificaron. Las evidencias, manifiestos, contexto público de build y scripts de publicación se guardan fuera del repositorio en `~/Library/Application Support/FinSight/deployments/20260925T105943Z-editorial/`.

El [registro de la primera publicación](landing-momentum.md) documenta la versión anterior y el [registro general de Cloud Run](cloud-run-deployment.md) conserva el historial.
