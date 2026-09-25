# Recursos visuales de FinSight Momentum

168 archivos SVG originales y escalables:
- 34 insignias × light, dark, locked_light, locked_dark = 136.
- 4 niveles × light/dark = 8.
- 12 recursos de interfaz × light/dark = 24.

Abrir PREVIEW.html para ver la galería. assets/manifest.json es el contrato de claves/rutas. No usar PREVIEW.html como pantalla final de producto: es una hoja de revisión. Las insignias de este paquete son vectores de implementación; no imágenes generadas ni capturas de UI.

SVG viewBox 0 0 64 64, medallón redondeado, trazo 2, gradiente y highlight suaves; sin fuentes, JS, referencias externas ni filtros de blur. Fondo exterior transparente; medallón adaptado a light/dark. Locked conserva símbolo para reconocer requisito. Texto y candado semántico se dibujan en UI; no depender sólo de desaturación. Motivos complejos se han estilizado, conservando claves y significado del catálogo.

Paleta base: azul #2563EB, mint #22B66F, lavender #7C83FD, amber #F59E0B. UI usa tokens existentes del repositorio para texto y superficies. El color de insignia es decorativo; no usarlo como texto pequeño sin validar contraste.

Web: copiar assets a ubicación pública convencional y resolver por manifest; usar img para aislar IDs de gradientes. Si se inlinean múltiples SVG, prefijar IDs por instancia para evitar colisiones. Flutter: registrar assets en pubspec y usar renderer SVG ya adoptado o dependencia compatible verificada; comprobar render en dispositivo. Validación XML/render de este paquete no reemplaza test Flutter.

Tamaños: 64px galería, 40px lista. A 24px se recomienda icono UI simple xp/momentum_mark/mission_* o un componente nativo simplificado, no reducir detalle compuesto hasta volverlo ilegible. Insignia grande de celebración: puede escalar a 96/128px sin pérdida.

Recursos UI: momentum_mark, xp, weekly_review, monthly_review, mission_review, mission_maintenance, mission_goal, week_complete, ai_credit, comeback, empty_missions, all_achievements. Usar componer pantalla vacía/semana completa con el recurso y texto real, sin ilustración adicional obligatoria.

Progreso, niveles numéricos, gráficas de actividad, anillos de porcentaje, punto de notificación, skeleton y barras se implementan como componentes nativos/React con datos; no necesitan archivos de imagen. El anillo decorativo de un badge no representa progreso en vivo. Animación scale/fade 350–500ms + halo por código, con reduced-motion. No se entregan archivos Lottie ni se requieren.

build_assets.py permite reproducir/ajustar todo el conjunto; no cambia recursos del repositorio automáticamente. El prompt exige integrar y verificar estados, accesibilidad y traducciones.
