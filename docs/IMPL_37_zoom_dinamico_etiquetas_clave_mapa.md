# IMPL_37 - Zoom dinamico para etiquetas de clave en mapa

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Evitar saturacion visual en mapa mostrando etiquetas de clave solo cuando el zoom es suficiente, manteniendo el control manual de encendido y apagado.

## 2. Diagnostico / contexto actual
La capa de etiquetas de clave se podia activar correctamente, pero al alejar el mapa podia sobrecargar la vista con demasiados textos.

## 3. Fases

### Fase 1 - Umbral minimo de zoom para etiquetas
Descripcion: Se incorporo un umbral de zoom minimo para renderizar la capa de etiquetas.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_minZoomForClaveLabels = 13.0`
- `_currentZoom`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Seguimiento de zoom en tiempo real
Descripcion: Se amplio `onPositionChanged` para actualizar estado de zoom junto con rotacion, con tolerancia para evitar renders innecesarios.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `zoomChanged = (newZoom - _currentZoom).abs() > 0.05`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 3 - Integracion de capa y feedback visual
Descripcion: Se renderizan etiquetas solo si el toggle esta activo y el zoom cumple el umbral. El icono muestra estado de advertencia cuando esta activo pero aun no visible por zoom.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `canShowClaveLabels = _showClaveLabels && _currentZoom >= _minZoomForClaveLabels`
- Tooltip con mensaje de acercamiento
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 55 min | Bajo |

## 5. Criterio de exito
- Con etiquetas activadas, al alejar el mapa no se muestran textos de clave.
- Al acercar por encima del umbral, las etiquetas aparecen automaticamente.
- El icono de etiquetas mantiene control de encendido y apagado.

## 6. Resultado / evidencia
- Se aplico el gating por zoom en la capa de etiquetas de claves.
- Se corrigio el alcance de variables de etiquetas dentro del bloque de datos del mapa para evitar referencias fuera de contexto.
- Validacion estatica del archivo sin errores.

## 7. Proximo paso
Validar manualmente en UI con diferentes niveles de zoom para ajustar el umbral si se requiere mas o menos densidad de etiquetas.
