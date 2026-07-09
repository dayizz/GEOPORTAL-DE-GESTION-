# IMPL_31 Fix Import GeoJSON Backend Campos y Tipos

- Estado: Completado
- Fecha: 2026-07-07
- Rama: main

## 1. Objetivo
Corregir la importacion GeoJSON para que:
- los predios queden asociados al proyecto real del archivo,
- se persistan estado, municipio, km fin y km efectivos,
- no se clasifiquen indebidamente como PRIVADA los predios con tipo de propiedad distinto.

## 2. Diagnostico / contexto actual
Se detectaron varios puntos donde la importacion perdia informacion:
- El backend FastAPI forzaba `tipo_propiedad` a `PRIVADA` cuando el valor no quedaba mapeado de forma exacta.
- La normalizacion del tipo de propiedad en Flutter usaba una regla demasiado amplia (`contains('PRI')`), que clasificaba erróneamente textos como `PROPIEDAD SOCIAL` como PRIVADA.
- La ruta local de predios y el modelo de lectura no contemplaban suficientes aliases para estado, municipio y kilometrajes.

## 3. Fases

### Fase 1: Endurecer el backend
- Descripcion: Se agregaron helpers de resolucion flexible para textos, numeros y tipo de propiedad en `backend/app/main.py`.
- Archivos afectados: `backend/app/main.py`
- Codigo clave:
  - `_pick_text(...)`
  - `_pick_float(...)`
  - `_normalize_tipo_propiedad(...)`
  - normalizacion de `estado`, `municipio`, `km_inicio`, `km_fin` y `km_efectivos`
- Tiempo estimado: 30 min
- Riesgo: Bajo/medio.

### Fase 2: Corregir normalizacion de tipo de propiedad
- Descripcion: Se reemplazo la deteccion por `contains('PRI')` por una deteccion basada en forma compacta y tokens reales.
- Archivos afectados:
  - `lib/features/carga/utils/geojson_mapper.dart`
  - `lib/features/carga/services/sincronizacion_service.dart`
  - `lib/features/carga/services/xlsx_import_service.dart`
  - `lib/features/carga/presentation/carga_archivo_screen.dart`
  - `lib/features/predios/providers/local_predios_provider.dart`
- Codigo clave:
  - uso de `compact.contains('PRIVAD')`
  - prioridad a SOCIAL / DOMINIO PLENO / EJIDAL antes de PRIVADA
- Tiempo estimado: 35 min
- Riesgo: Bajo.

### Fase 3: Cubrir aliases en lectura y fallback local
- Descripcion: Se ampliaron aliases para `estado`, `municipio`, `km_fin` y `km_efectivos` en el modelo y en la caché local.
- Archivos afectados:
  - `lib/features/predios/models/predio.dart`
  - `lib/features/predios/data/predios_repository.dart`
  - `lib/features/predios/providers/local_predios_provider.dart`
- Codigo clave:
  - lectura por aliases en `Predio.fromMap`
  - persistencia local con `estado` / `municipio`
  - preservacion de km en el fallback local
- Tiempo estimado: 30 min
- Riesgo: Bajo.

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo/medio |
| Fase 2 | 35 min | Bajo |
| Fase 3 | 30 min | Bajo |
| **Total** | **95 min** | **Bajo/medio** |

## 5. Criterio de exito
- El archivo GeoJSON se importa conservando el proyecto correcto.
- `estado`, `municipio`, `km_fin` y `km_efectivos` quedan visibles en Gestion.
- Se registran predios con tipos de propiedad distintos a PRIVADA cuando el origen los contiene.

## 6. Resultado / evidencia
Cambios aplicados y validados sin errores en:
- `backend/app/main.py`
- `lib/features/carga/utils/geojson_mapper.dart`
- `lib/features/carga/services/sincronizacion_service.dart`
- `lib/features/carga/services/xlsx_import_service.dart`
- `lib/features/carga/presentation/carga_archivo_screen.dart`
- `lib/features/predios/providers/local_predios_provider.dart`
- `lib/features/predios/data/predios_repository.dart`
- `lib/features/predios/models/predio.dart`

## 7. Proximo paso
Probar nuevamente la importacion con el GeoJSON problemático y validar en Gestion que los campos ya no lleguen vacios y que los tipos de propiedad se conserven correctamente.