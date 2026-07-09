# IMPL_10_fix_arrastre_captura_mapa

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir la captura de pantalla del mapa para permitir la seleccion de area mediante arrastre del cursor (mouse/touchpad) en el modo de seleccion en vivo.

## 2. Diagnostico / contexto actual
La seleccion de region en captura de pantalla se apoyaba en `GestureDetector` con `onPanStart/onPanUpdate` sobre un mapa interactivo.
En escritorio, el gesto de arrastre competia con los recognizers del mapa y en escenarios reales no iniciaba la caja de seleccion.
Adicionalmente, el modo de captura estaba reutilizando el `MapController` principal dentro del overlay, provocando excepciones de build (`setState() or markNeedsBuild() called during build`) que interrumpian la interaccion de recorte.

## 3. Fases

### Fase 1 - Identificacion de conflicto de gestos
Descripcion: Revision del overlay de captura en vivo para confirmar que el detector de pan competia contra los gestos del mapa.
Archivos afectados: `lib/features/mapa/utils/screenshot_crop_controller.dart`
Codigo clave:
- `LiveCropOverlay`
- Capa de gestos para seleccion de recorte
Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2 - Migracion a eventos de puntero
Descripcion: Reemplazo de `GestureDetector` por `Listener` para procesar `PointerDown/Move/Up` directamente y evitar perdida de eventos de arrastre.
Archivos afectados: `lib/features/mapa/utils/screenshot_crop_controller.dart`
Codigo clave:
- `onPointerDown`: inicia seleccion y valida boton primario en mouse
- `onPointerMove`: actualiza rectangulo de seleccion
- `onPointerUp/onPointerCancel`: finaliza estado de seleccion
- `HitTestBehavior.opaque`: prioridad completa del overlay
Tiempo estimado: 30 min
Riesgo: Medio (impacta UX de captura, no flujo de datos)

### Fase 3 - Validacion tecnica
Descripcion: Verificacion por analizador del archivo modificado.
Archivos afectados: `lib/features/mapa/utils/screenshot_crop_controller.dart`
Codigo clave:
- `flutter analyze lib/features/mapa/utils/screenshot_crop_controller.dart`
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 30 min | Medio |
| Fase 3 | 10 min | Bajo |
| **Total** | **60 min** | **Medio-Bajo** |

## 5. Criterio de exito
- Al activar captura de pantalla del mapa, el usuario puede dibujar una region con arrastre de cursor.
- El rectangulo de seleccion se actualiza en tiempo real durante el movimiento.
- La seleccion no queda bloqueada por interacciones del mapa.
- El archivo compila sin errores de sintaxis/tipos.

## 6. Resultado / evidencia
Resultado actual:
- Implementacion aplicada en el overlay de captura en vivo con eventos de puntero.
- Ajuste adicional aplicado para corregir errores de hit-test por widgets sin tamano en overlays de recorte.
- Cambio final de estrategia: se usa seleccion sobre imagen capturada (modo estatico) para evitar conflictos de build/interaccion del mapa en el overlay vivo.
- Reimplementacion definitiva: la captura ahora se realiza sobre el mapa ya renderizado en pantalla (`Screenshot` envolviendo el `FlutterMap`) y luego se recorta en overlay estatico.
- Se implemento modo alterno operacional por `2 puntos` (clic inicio + clic fin) con marca visual de punto inicial y opcion de reiniciar seleccion.
- Analisis estatico ejecutado sin errores de compilacion para el archivo intervenido.

Evidencia tecnica:
- Cambio en `LiveCropOverlay` usando `Listener` + `HitTestBehavior.opaque`.
- Reemplazo de `MouseRegion` sin tamano efectivo por `SizedBox.expand()`/`CustomPaint` con hijo expandido, evitando `Cannot hit test a render box with no size`.
- En captura en vivo del mapa, se removio el uso de `mapController: _mapCtrl` para evitar conflictos de estado durante build del overlay.
- Se encapsulo el mapa del overlay con `IgnorePointer` para desactivar gestos del mapa mientras se dibuja el recorte y evitar que el arrastre sea interceptado.
- La capa de seleccion en vivo ahora usa `GestureDetector` con `onPanStart/onPanUpdate` y fallback de dos clics (inicio/fin) para equipos donde el drag no se detecta de forma estable.
- El flujo principal de `_capturarPantalla` quedo en `startSelectionCapture(...)` (imagen estatica) para mantener arrastre de recorte estable en web/desktop.
- Se acotaron los botones de accion del overlay con ancho fijo para evitar errores de `BoxConstraints(w=Infinity, ...)`.
- Se elimino la reconstruccion de un segundo `FlutterMap` para captura (`captureFromWidget`), eliminando los errores de `MapInteractiveViewer` durante build.
- El overlay de recorte incluye selector de modo `2 puntos` / `Arrastre`, quedando `2 puntos` como enfoque recomendado para estabilidad en web.
- Validacion con `flutter analyze lib/features/mapa/utils/screenshot_crop_controller.dart`.

## 7. Proximo paso
Validar en UI el flujo completo en entorno web:
1. Ir a Mapa.
2. Abrir panel de captura de pantalla.
3. Arrastrar con cursor para dibujar area.
4. Confirmar que la captura se recorta y descarga correctamente.
