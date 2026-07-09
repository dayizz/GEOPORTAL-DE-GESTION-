# IMPL_66 Optimizacion Import ENVOLVENTE Rendimiento Mapa

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo
Corregir degradacion de rendimiento (lag/congelamiento) al importar archivos ENVOLVENTE, optimizando la recepcion y el render para mantener desplazamiento fluido en mapa.

## 2. Diagnostico / contexto actual
Al importar ENVOLVENTE, la vista de mapa podia volverse lenta por:
- geometria con anillos muy densos (muchos vertices),
- calculos de foco y deduplicacion sobre gran cantidad de puntos,
- calculos de etiquetas/centroides no necesarios para este tipo de capa.

## 3. Fases

### Fase 1: Optimizacion de recepcion de geometria ENVOLVENTE
- Descripcion:
Se simplifican anillos muy densos en importacion (muestreo por paso) y se preserva cierre de anillo.
Se agrego simplificacion adaptativa por carga total del archivo y se conservaron solo anillos exteriores para ENVOLVENTE para reducir complejidad de dibujo.
Se agregaron niveles adicionales de simplificacion para cargas grandes:
- modo ultra-ligero (>= 30000 puntos),
- modo extremo (>= 60000 puntos),
para priorizar fluidez en desplazamiento.
Adicionalmente, se calcula y almacena bbox por feature para evitar recorridos completos de puntos en foco inicial.
- Archivos afectados:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - _optimizeEnvolventeGeometry(...)
  - _simplifyGeoJsonRing(...)
  - _computeGeoJsonGeometryBbox(...)
  - metadato __bbox en properties
- Tiempo estimado: 55 min
- Riesgo: Medio

### Fase 2: Render/foco liviano para ENVOLVENTE en mapa
- Descripcion:
Se optimiza la capa importada para evitar trabajo pesado por frame en casos ENVOLVENTE:
- omitir dedupe por firma de poligono cuando todas las features importadas son ENVOLVENTE,
- omitir labels de clave para ENVOLVENTE,
- usar bbox precomputada para focus inicial sin iterar todos los vertices.
- evitar setState por cambios de zoom cuando no hay capa PKS activa,
- reducir costo de borde para ENVOLVENTE.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Codigo clave:
  - _combinedFeatureBbox(...)
  - _featureBbox(...)
  - _focusImportedIfNeeded(...)
  - _buildClaveLabelMarkersForImportedFeatures(...)
- Tiempo estimado: 45 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| 1. Simplificacion y bbox en importacion | 55 min | Medio |
| 2. Render/focus optimizado | 45 min | Medio |
| Total | 100 min | Medio |

## 5. Criterio de exito
- Importar ENVOLVENTE ya no congela la vista del mapa.
- El desplazamiento/zoom se mantiene utilizable tras importacion.
- El enfoque inicial de capa ENVOLVENTE se resuelve rapidamente.
- No se introducen errores de analizador en archivos modificados.

## 6. Resultado / evidencia
- Optimizacion aplicada en recepcion de ENVOLVENTE (simplificacion + bbox).
- Endurecimiento adicional aplicado: simplificacion adaptativa y descarte de anillos internos (huecos) para ENVOLVENTE.
- Ajuste adicional aplicado: umbrales ultra/extremo para bajar mas puntos por anillo en archivos ENVOLVENTE pesados.
- Optimizacion aplicada en render/focus de capa ENVOLVENTE.
- Endurecimiento adicional aplicado: menos repaints por zoom sin PKS y borde ENVOLVENTE mas liviano.
- Validacion tecnica local:
  - sin errores de analizador en:
    - lib/features/carga/presentation/carga_archivo_screen.dart
    - lib/features/mapa/presentation/mapa_screen.dart

## 7. Proximo paso
Probar con archivo ENVOLVENTE de alta densidad (anillos grandes) y validar:
- tiempo de carga,
- fluidez de pan/zoom,
- que el color/estilo y el encuadre inicial se mantengan correctos.
