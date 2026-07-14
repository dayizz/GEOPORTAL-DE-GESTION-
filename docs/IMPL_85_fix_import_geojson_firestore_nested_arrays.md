# IMPL_85 - Fix Import GeoJSON Firestore Nested Arrays

- Estado: Implementado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo
Corregir el fallo de importacion en Gestion cuando Firestore rechaza el guardado con el error `invalid-argument` por `Nested arrays are not supported`.

## 2. Diagnostico / contexto actual
Durante la importacion GeoJSON se estaba enviando `geometry` como objeto GeoJSON completo. Ese objeto contiene `coordinates` con arreglos anidados (`[[...], [...]]`), formato no permitido por Firestore.

Adicionalmente, al incluir propiedades originales del archivo (`propsOriginal`), algunas podian traer estructuras de listas/mapas incompatibles para Firestore.

## 3. Fases

### Fase 1 - Saneamiento de payload para Firestore
- Descripcion: agregar utilidades para detectar arrays anidados y sanear valores complejos antes del `set`.
- Archivos afectados: `lib/features/carga/services/sincronizacion_service.dart`
- Codigo clave:
  - `_containsNestedArray(dynamic value)`
  - `_sanitizeForFirestore(dynamic value)`
- Tiempo estimado: 20 min
- Riesgo: Bajo (cambio encapsulado en el servicio de sincronizacion)

### Fase 2 - Serializacion segura de geometria
- Descripcion: persistir `geometry` como JSON string para evitar arrays anidados en Firestore.
- Archivos afectados: `lib/features/carga/services/sincronizacion_service.dart`
- Codigo clave:
  - `'geometry': geometry == null ? null : jsonEncode(geometry)`
- Tiempo estimado: 10 min
- Riesgo: Bajo (repositorio ya soporta lectura de `geometry` como string JSON)

### Fase 3 - Saneamiento de propiedades originales
- Descripcion: al anexar propiedades originales del GeoJSON, convertir valores incompatibles a formato serializado.
- Archivos afectados: `lib/features/carga/services/sincronizacion_service.dart`
- Codigo clave:
  - `final sanitizedValue = _sanitizeForFirestore(entry.value)`
- Tiempo estimado: 10 min
- Riesgo: Medio-bajo (depende de diversidad de archivos de entrada)

## 4. Resumen de esfuerzo

| Fase | Esfuerzo |
|---|---:|
| Fase 1 | 20 min |
| Fase 2 | 10 min |
| Fase 3 | 10 min |
| Total | 40 min |

## 5. Criterio de exito
- La importacion GeoJSON no falla con `Nested arrays are not supported`.
- Los predios se crean o actualizan en Firestore durante la sincronizacion.
- Se mantiene compatibilidad de lectura de geometria en el repositorio.

## 6. Resultado / evidencia
- Se agrego saneamiento de datos previo a persistencia.
- Se serializa `geometry` a string JSON.
- Se sanean propiedades originales potencialmente incompatibles.

## 7. Proximo paso
- Ejecutar importacion con el mismo archivo que detonaba el error y validar:
  - contador de creados/encontrados/errores
  - presencia de estado/municipio
  - visualizacion correcta en Gestion y Tabla
