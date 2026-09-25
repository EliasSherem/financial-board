# Landing: Momentum, animación y demos

**Iteración posterior publicada:** el [rediseño editorial y nueva coreografía](landing-editorial-redesign.md) sustituyó esta revisión por `financial-web-editorial-260925-105943`, con el 100 % del tráfico y la insignia superpuesta corregida. Este documento conserva el registro histórico de la primera publicación.

Registro del **25 de septiembre de 2026**. Implementación, QA local y publicación completados. **`financial-web-landing-260925-102523` recibió el 100 % del tráfico en esta primera publicación.** Comprobación pública satisfactoria a las **10:31:21 UTC**.

## Implementación

La landing presenta FinSight Momentum antes de la demostración de la aplicación. La navegación y el anuncio del hero enlazan a `#momentum`; la llamada a comenzar dirige a `/signup`. Los textos están disponibles en español e inglés.

La sección muestra un perfil de ejemplo con el nivel Organizador y las insignias Organizador de cuentas, Mapa financiero y Ritmo semanal. Reutiliza cinco SVG existentes del catálogo: marca de Momentum, nivel y tres insignias. La vista está identificada como ejemplo; sus datos no proceden de una cuenta ni modifican XP, logros o revisiones.

El hero conserva y refina la **animación Three.js original con movimiento continuo**, incluida su composición financiera y la respuesta al puntero en dispositivos compatibles. La presentación normal sigue siendo una escena renderizada, no una imagen estática. El render continuo se pausa cuando la escena queda fuera de vista o la pestaña deja de estar visible. Existe una presentación de respaldo cuando WebGL no está disponible o se pierde su contexto.

Las entradas de las secciones comparten transiciones breves y una curva de movimiento coherente. La preferencia `prefers-reduced-motion` desactiva el movimiento continuo del hero, reduce las transiciones y elimina el desplazamiento suave entre anclas. El indicador de foco usa un azul con contraste suficiente sobre las superficies claras de la landing.

La demostración de la aplicación ofrece cuatro pestañas: **Cuentas, Movimientos, Presupuestos y Revisión**. Usa datos de ejemplo y componentes de interfaz, con importes y gráficos ilustrativos; no consulta información financiera del visitante. Las pestañas tienen relaciones `tab`/`tabpanel`, selección explícita y navegación por teclado. Los paneles inactivos quedan ocultos para las tecnologías de asistencia y fuera de la interacción. Su disposición mantiene el espacio de la demo al cambiar de pestaña.

Los cambios están concentrados en `Landing.tsx`, `landing.css`, `LandingHeroScene.tsx` y `AppCarousel.tsx`. No requieren migraciones ni cambios en las reglas del servidor.

## Validación local

- QA visual manual en anchuras de **320, 390, 768 y 1280 px**, en español e inglés: composición del hero, sección Momentum, navegación por anclas y demostración de cuatro pestañas.
- Cambio de pestañas mediante las flechas del teclado. El código también contempla Inicio y Fin, conserva el foco en la pestaña seleccionada y excluye los paneles inactivos.
- Comparación de **dos fotogramas del hero en momentos diferentes**, que confirmó movimiento real de la escena durante la prueba.
- Compilación TypeScript/Vite, ESLint de los archivos modificados y comprobación del diff aprobados.
- Comprobación de existencia de los cinco SVG usados por Momentum y correspondencia de los nombres de insignias con el catálogo.

**Movimiento reducido se revisó en el código; no se emuló esa preferencia durante el QA de runtime.** Los controles de pausa por visibilidad también constan en la implementación; las dos capturas de movimiento no constituyen una medición de rendimiento ni de consumo.

## Despliegue y verificación pública

Destino: proyecto `finsight-472418`, región `us-central1`, servicio `financial-web`.

- [Cloud Build completado](https://console.cloud.google.com/cloud-build/builds;region=us-central1/6ef450c7-1b68-467d-8674-2a880cf0ae22?project=finsight-472418): `6ef450c7-1b68-467d-8674-2a880cf0ae22`, estado `SUCCESS`.
- Revisión pública: `financial-web-landing-260925-102523`, 100 % del tráfico y sin etiqueta temporal.
- Digest: `sha256:991a8323628cf34ef22d966b8b508000c3b51c51a468a413a6e609aa8b04e69e`.
- Revisión anterior: `financial-web-momentum-260925-0857`.
- El contexto de build usa la allowlist pública y `Dockerfile.web`, conserva los parámetros Vite de la web vigente y excluye configuración privada del servidor.

La candidata se desplegó por digest sin tráfico general y aprobó las comprobaciones HTTP antes de promoverse. La configuración de runtime de `spec.template.spec`, salvo la imagen, coincide con la del servicio anterior. La fuente desplegada coincide con los hashes del contexto preparado.

La [landing pública](https://finsight.com.mx/landing) sirve `index-h0zTEPHi.js`, `index-PkUMaOgA.css` y el módulo Three.js `LandingHeroScene-DvcjzIfn.js`. Se comprobaron los textos ES/EN, los cinco SVG de Momentum, `/login` y `/signup`. `/reset-password` conserva `Cache-Control: no-store` y `Referrer-Policy: no-referrer`. Safari mostró la escena 3D en la candidata y la sección Momentum en español en el dominio público. La validación adaptable detallada se realizó localmente antes del build de Cloud.

Las evidencias, manifiestos de hashes, logs y configuración de despliegue se conservan fuera del repositorio en `~/Library/Application Support/FinSight/deployments/20260925T102523Z-landing/`. El [registro general de Cloud Run](cloud-run-deployment.md) conserva los despliegues anteriores. La API y la base de datos no se modificaron en esta publicación.
