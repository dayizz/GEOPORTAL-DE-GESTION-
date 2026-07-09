# IMPL_39 - Normalizacion de datos PKS en GeoJSON de puntos

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Normalizar datos de importacion PKS para que la deteccion, etiquetado y renderizado de puntos sea robusto ante variaciones de columnas y formato de coordenadas.

## 2. Diagnostico / contexto actual
La primera version funcional de PKS dependia de coincidencias de llaves relativamente directas (ej. `propiedad`, `label`) y de coordenadas ya limpias. Esto podia fallar cuando el archivo traia:
- aliases con mayusculas, acentos o separadores,
- valores de texto con formato irregular,
- coordenadas en string con comas/espacios.

## 3. Fases

### Fase 1 - Normalizacion de features PKS al importar
Descripcion: Se agrego una etapa de normalizacion previa al guardado/renderizado para construir una etiqueta canónica (`pks_label`) y depurar geometria de puntos.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `_normalizePksPointFeatures(...)`
- `_normalizePksGeometry(...)`
- `_normalizePointCoordinate(...)`
Tiempo estimado:
- 30 min
Riesgo:
- Bajo

### Fase 2 - Deteccion PKS flexible
Descripcion: Se robustecio la deteccion PKS usando normalizacion de texto en nombre/propiedades y búsqueda por aliases tolerantes.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `_featureMentionsPks(...)`
- `_pickTextByAliases(...)`
- `_normalizeKey(...)`
- `_normalizeValue(...)`
Tiempo estimado:
- 25 min
Riesgo:
- Bajo

### Fase 3 - Consumo de etiqueta normalizada en mapa
Descripcion: El renderer de etiquetas PKS prioriza `pks_label` para asegurar consistencia visual aunque cambien las columnas de origen.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_extractPksPointLabel(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Total | 65 min | Bajo |

## 5. Criterio de éxito
- PKS de puntos sigue sin inyectarse en Gestión.
- Etiquetas PKS aparecen aunque el archivo traiga aliases heterogéneos.
- Coordenadas de puntos con strings/formatos mixtos se normalizan para render correcto.

## 6. Resultado / evidencia
- Normalizacion PKS implementada en flujo de Carga.
- Etiqueta canónica `pks_label` incorporada.
- Mapa consume la etiqueta normalizada.

## 7. Próximo paso
Probar con al menos dos archivos PKS reales con nomenclaturas distintas para verificar cobertura de aliases y ajustar lista de etiquetas si aparece un nuevo patrón.
