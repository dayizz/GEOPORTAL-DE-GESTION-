# IMPL_42 - Fix etiquetas de clave visibles al activar toggle

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Asegurar que las etiquetas de clave se muestren al encender la funcion de etiquetas en mapa, sin depender de un umbral de zoom.

## 2. Diagnostico / contexto actual
La capa de etiquetas de clave estaba condicionada por zoom minimo. En escenarios de uso normal, el usuario encendia el toggle pero no veia etiquetas, lo que se percibia como fallo de la funcion.

## 3. Fases

### Fase 1 - Eliminar bloqueo por zoom en etiquetas clave
Descripcion: Se removio la condicion de zoom para renderizar etiquetas de clave.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `canShowClaveLabels = _showClaveLabels`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Ajustar feedback visual del boton de clave
Descripcion: Se simplifico el estado visual y tooltip del boton para que refleje solo ON/OFF.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_buildClaveLabelsToggleButton()`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito
- Al activar el boton de etiquetas de clave, las etiquetas aparecen en el mapa.
- El comportamiento ya no depende de acercar el zoom.

## 6. Resultado / evidencia
- Implementacion aplicada en la pantalla de mapa para render y control de etiquetas.

## 7. Proximo paso
Validar en mapa con distintos niveles de zoom que las etiquetas se mantengan visibles al activar la funcion.
