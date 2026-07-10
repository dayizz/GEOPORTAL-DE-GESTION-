# IMPL_69 - Gestion columna Estructura desde importacion

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo

Agregar el campo `Estructura` en la tabla de Gestion y asegurar que su valor se detecte automaticamente desde el archivo importado (GeoJSON y XLSX), tanto en altas como en actualizaciones.

## 2. Diagnostico / contexto actual

La tabla de Gestion no mostraba el dato de `estructura`. Aunque la importacion incorporaba varios campos operativos, `estructura` no estaba modelado de forma formal en `Predio`, por lo que no se visualizaba como columna propia en la tabla.

## 3. Fases

### Fase 1 - Modelado y persistencia del campo estructura

- Descripcion:
  - Se agrego `estructura` al modelo `Predio`.
  - Se incluyo en `fromMap`, `toMap` y `copyWith`.
  - Se incorporo en normalizacion/repositorio/local provider para conservarlo en flujo local y remoto.
- Archivos afectados:
  - lib/features/predios/models/predio.dart
  - lib/features/predios/data/predios_repository.dart
  - lib/features/predios/providers/local_predios_provider.dart
- Codigo clave:
  - `final String? estructura;`
  - Mapeo de `estructura` en serializacion/deserializacion
- Tiempo estimado: 40 min
- Riesgo: Bajo

### Fase 2 - Deteccion desde importacion (GeoJSON/XLSX)

- Descripcion:
  - Se agregaron aliases para detectar `estructura` desde diferentes encabezados.
  - Se incluyo en construccion de datos nuevos y en updates del servicio de sincronizacion.
  - Se incluyo en normalizacion de filas XLSX y en construccion local de predios desde carga.
- Archivos afectados:
  - lib/features/carga/utils/geojson_mapper.dart
  - lib/features/carga/services/sincronizacion_service.dart
  - lib/features/carga/services/xlsx_import_service.dart
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - Alias: `estructura`, `tipo_estructura`, `clase_estructura`, `estruc`
  - Keys destino: `estructura`
- Tiempo estimado: 45 min
- Riesgo: Bajo

### Fase 3 - Visualizacion en tabla de Gestion

- Descripcion:
  - Se agrego la columna `ESTRUCTURA` en headers y filas de la tabla.
  - Se ajustaron anchos e indices de celdas para mantener alineacion.
  - Se incluyo `ESTRUCTURA` en exportacion Excel.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - Header tabla: `ESTRUCTURA`
  - Celda fila: `p.estructura ?? '-'`
- Tiempo estimado: 35 min
- Riesgo: Medio-Bajo (por desplazamiento de indices de columnas)

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Modelo y persistencia | 40 min | Bajo |
| Fase 2 - Importacion | 45 min | Bajo |
| Fase 3 - UI tabla y exportacion | 35 min | Medio-Bajo |
| Total | 120 min | Bajo |

## 5. Criterio de exito

- `Estructura` aparece como columna visible en la tabla de Gestion.
- El valor de `Estructura` se detecta desde archivos importados (GeoJSON/XLSX).
- El valor se mantiene en altas y actualizaciones de predios.
- La exportacion Excel incluye la columna `ESTRUCTURA`.
- No hay errores de compilacion en archivos modificados.

## 6. Resultado / evidencia

- Campo implementado de punta a punta: importacion, modelo, persistencia, UI y exportacion.
- Validacion de errores en archivos modificados: sin errores.
- Se agrega migracion SQL para `estructura`:
  - `ALTER TABLE predios ADD COLUMN IF NOT EXISTS estructura TEXT;`

## 7. Proximo paso

Ejecutar la migracion SQL de `estructura` en entorno Supabase productivo y validar importacion real de un archivo con columna `estructura` para comprobar visualizacion inmediata en Gestion y en exportacion Excel.
