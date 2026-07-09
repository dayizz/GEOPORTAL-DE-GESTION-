# IMPL_36 - Etiquetas de clave en mapa

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Mostrar una etiqueta textual con la clave de cada predio en el mapa y permitir encender o apagar esta capa desde un icono sobre el mapa.

## 2. Diagnóstico / contexto actual
El mapa ya mostraba polígonos y marcadores de selección, pero no existía una capa visible de texto con la clave catastral para todos los predios. Tampoco había un control rápido para activar o desactivar etiquetas.

## 3. Fases

### Fase 1 - Capa de etiquetas por predio
Descripción: Se agregó una capa de markers de texto puro para mostrar la clave catastral en el punto representativo de cada predio. La etiqueta no usa contenedor visible; solo texto con sombra para contraste.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Código clave:
- `_buildClaveLabelMarkersForPredios(...)`
- `_buildClaveLabelMarker(...)`
Tiempo estimado:
- 30 min
Riesgo:
- Bajo

### Fase 2 - Etiquetas para predios importados
Descripción: Se amplió la misma lógica para los features importados en el mapa, extrayendo la clave desde `properties` y pintándola sobre el polígono.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Código clave:
- `_buildClaveLabelMarkersForImportedFeatures(...)`
- `_extractImportedFeatureClave(...)`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 3 - Control rápido en el mapa
Descripción: Se añadió un botón flotante con icono de etiqueta para activar o desactivar la capa de claves sin entrar a otros paneles.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Código clave:
- `_buildClaveLabelsToggleButton()`
- `_showClaveLabels`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Total | 65 min | Bajo |

## 5. Criterio de éxito
- Cada predio visible en el mapa muestra su clave como texto cuando la capa está activa.
- No se dibuja un contenedor visible detrás de la etiqueta.
- El usuario puede activar y desactivar la capa con un icono de etiqueta sobre el mapa.

## 6. Resultado / evidencia
- Se implementó la capa de etiquetas y el toggle en `MapaScreen`.
- El archivo se mantiene compatible con la capa de predios persistidos e importados.

## 7. Próximo paso
Validar en UI el contraste y densidad de las etiquetas en zooms altos y bajos; si se saturan, conviene ocultarlas por nivel de zoom.
