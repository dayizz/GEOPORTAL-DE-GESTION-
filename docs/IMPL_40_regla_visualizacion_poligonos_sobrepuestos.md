# IMPL_40 - Regla de visualizacion para poligonos sobrepuestos

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Evitar diferencias de tono por acumulacion de opacidad cuando el mismo poligono se renderiza en mas de una capa del mapa.

## 2. Diagnostico / contexto actual
El mapa renderiza varias capas de poligonos (predios, importados y capturados). Cuando una misma geometria aparece en mas de una capa, el relleno semitransparente se acumula y altera el tono visual.

## 3. Fases

### Fase 1 - Firma canonica de geometria
Descripcion: Se implemento una firma estable para poligonos a partir de anillo exterior e interiores, normalizando precision, orientacion y punto inicial del anillo.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_polygonSignature(...)`
- `_ringSignature(...)`
- `_minRotation(...)`
Tiempo estimado:
- 35 min
Riesgo:
- Medio (riesgo de colision por precision si los vertices son casi iguales)

### Fase 2 - Deduplicacion en render
Descripcion: Antes de pintar cada `PolygonLayer`, se aplica deduplicacion por firma para mostrar solo la primera ocurrencia de un poligono y omitir superposiciones iguales.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_dedupeRenderedPolygons(...)`
- `visiblePredioPolygons`
- `visibleImportedPolygons`
- `visibleCapturedPolygons`
Tiempo estimado:
- 25 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 35 min | Medio |
| Fase 2 | 25 min | Bajo |
| Total | 60 min | Bajo-Medio |

## 5. Criterio de exito
- Si un mismo poligono existe en mas de una capa, se visualiza una sola vez.
- Desaparecen los cambios de tono por opacidad acumulada en superposiciones identicas.
- La seleccion y logica de datos no se altera (solo la visualizacion).

## 6. Resultado / evidencia
- Se aplica regla de deduplicacion en render para predios, importados y capturados.
- Se mantiene la prioridad de primer render segun orden de capas.

## 7. Proximo paso
Validar visualmente en escenarios con poligonos duplicados exactos y, si se detectan casos de casi-duplicado por decimales, ajustar precision de firma (actualmente 6 decimales).
