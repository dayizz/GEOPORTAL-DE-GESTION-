# IMPL_33 - Fix Import Estado/Municipio Aliases y Parsing

- Estado: Implementado
- Fecha: 2026-07-07
- Rama: main

## 1. Objetivo
Asegurar que durante la importacion GeoJSON se registren correctamente los campos estado y municipio, incluso cuando el origen use variantes de llaves (espacios, mayusculas, acentos, guiones o slash).

## 2. Diagnostico / contexto actual
- El mapeo existente contemplaba alias comunes, pero no suficientes variantes reales para estado/municipio.
- Algunas llaves con formato diferente (ej. "NOMBRE DEL ESTADO", "nombre_municipio") podian no ser detectadas.
- Existia una sobreescritura en normalizacion del repositorio que podia reemplazar valores normalizados de estado/municipio con valores crudos.
- El parsing combinado estado/municipio no distinguia orden cuando el dato venia invertido.

## 3. Fases

### Fase 1 - Robustecer extraccion flexible en backend
- Descripcion: Se agrego normalizacion de llaves (sin acentos, espacios ni simbolos) y busqueda flexible para _pick_text.
- Archivos afectados:
  - backend/app/main.py
- Codigo clave:
  - _normalize_key
  - _pick_text (segunda pasada por llaves normalizadas)
- Tiempo estimado: 25 min
- Riesgo: Bajo

### Fase 2 - Expandir alias estado/municipio en pipeline Flutter
- Descripcion: Se ampliaron alias en mapper y parsing de modelo para aceptar variantes adicionales de estado y municipio.
- Archivos afectados:
  - lib/features/carga/utils/geojson_mapper.dart
  - lib/features/predios/models/predio.dart
- Codigo clave:
  - aliases de estado/municipio
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Mejorar parsing combinado estado/municipio
- Descripcion: Se robustecio el parser combinado con mas aliases y heuristica para identificar cuando el valor parece nombre de estado.
- Archivos afectados:
  - lib/features/carga/services/sincronizacion_service.dart
- Codigo clave:
  - _resolveEstadoMunicipio
  - _looksLikeEstadoName
- Tiempo estimado: 30 min
- Riesgo: Medio (heuristica de orden)

### Fase 4 - Evitar sobreescritura de estado/municipio ya normalizados
- Descripcion: Se elimino la doble asignacion de estado/municipio en normalizacion de repositorio.
- Archivos afectados:
  - lib/features/predios/data/predios_repository.dart
- Codigo clave:
  - _normalizePredioMap
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 30 min | Medio |
| Fase 4 | 10 min | Bajo |
| Total | 85 min | Bajo-Medio |

## 5. Criterio de exito
- Al importar GeoJSON, estado y municipio quedan poblados cuando existan en cualquier alias soportado.
- No se pierde estado/municipio por sobreescritura durante normalizacion.
- Si el origen trae estado/municipio en un solo campo combinado, se separa correctamente en la mayoria de casos.

## 6. Resultado / evidencia
- Cambios aplicados en backend, mapper, sync, repositorio y modelo.
- Validacion estatica sin errores en archivos modificados.

## 7. Proximo paso
Ejecutar una reimportacion controlada con el archivo problematico y validar por clave catastral que estado y municipio se persistan en backend y se reflejen en Gestion.
