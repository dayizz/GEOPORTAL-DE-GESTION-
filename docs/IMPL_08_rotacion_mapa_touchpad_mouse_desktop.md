# IMPL_08_rotacion_mapa_touchpad_mouse_desktop

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Agregar rotación de mapa en desktop mediante controles tipo touchpad y mouse:
- Touchpad: gesto sostenido y desplazamiento de rotación.
- Mouse: botón medio sostenido con arrastre horizontal y rueda mientras está sostenido.

## 2. Diagnóstico / contexto actual
La pantalla de mapa tenía control de rotación por panel/botones, pero no una experiencia directa de entrada de escritorio para rotación continua con dispositivos de puntero.

## 3. Fases

### Fase 1 - Captura de gestos desktop para rotación
Descripcion: Se envolvió `FlutterMap` con `Listener` para capturar eventos de puntero y traducirlos a rotación.
Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
Código clave:
- `onPointerPanZoomStart/Update/End` para rotación en touchpad.
- `onPointerDown/Move/Up` con `kMiddleMouseButton` para arrastre de rotación.
- `onPointerSignal` con `PointerScrollEvent` para rueda de mouse con botón medio sostenido.
Tiempo estimado: 30 min
Riesgo: Medio-bajo (sensibilidad puede requerir ajuste fino por hardware)

### Fase 2 - Normalización y sincronía de ángulos
Descripcion: Se normalizó la rotación para mantener valores entre 0 y 360 grados y sincronizar con `MapController`.
Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
Código clave:
- Normalización: `((degrees % 360) + 360) % 360`
- Aplicación en `_rotateMap` y `_rotateToDegrees`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Descubribilidad en UI
Descripcion: Se agregó ayuda visual en el panel de rotación con instrucciones rápidas de touchpad y mouse.
Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
Código clave:
- Texto de ayuda en `_buildRotationPanel()`
Tiempo estimado: 5 min
Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Medio-bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de éxito
- En desktop, el mapa rota con gesto de touchpad en interacción sostenida.
- En desktop, el mapa rota con botón medio de mouse + arrastre.
- En desktop, el mapa rota con rueda cuando el botón medio está sostenido.
- El ángulo de rotación se mantiene estable entre 0° y 360°.

## 6. Resultado / evidencia
- Implementación aplicada en `MapaScreen` mediante `Listener` y control de eventos de puntero.
- Sin errores de compilación en el archivo modificado.
- Permanecen avisos informativos preexistentes no bloqueantes del archivo.

## 7. Próximo paso
Validar manualmente en navegador desktop (macOS):
1. Rotación con touchpad en gesto sostenido.
2. Botón medio + arrastre horizontal.
3. Botón medio + rueda.
4. Confirmar actualización de brújula y panel de grados.
