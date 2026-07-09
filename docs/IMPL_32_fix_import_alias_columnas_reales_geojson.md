# IMPL_32 Fix Import GeoJSON – Alias Exactos de Columnas Reales

- Estado: Completado
- Fecha: 2026-07-07
- Rama: main

## 1. Objetivo
Corregir los alias de importacion GeoJSON con base en los nombres de columna reales del archivo fuente,
para que tipo de propiedad, km fin y km efectivos se registren correctamente.

## 2. Diagnostico (basado en muestra real de properties)

### Columnas del archivo fuente

| Columna real | Campo BD | Problema detectado |
|---|---|---|
| `"TIPO DE PROPIEDAD"` | `tipo_propiedad` | La palabra `"DE"` intermedia hace que el alias normalizado sea `tipodepropiedad`, distinto de `tipopropiedad`. No habia match. |
| `"KM FIN"` | `km_fin` | Clave con espacio. No estaba en el background parser ni en GeoJsonMapper._keyAliases. |
| `"KM EFECTIVOS"` | `km_efectivos` | Clave con espacio. No estaba en el background parser ni en GeoJsonMapper._keyAliases. |
| `"ANUENCIA"` | `cop` | No estaba en GeoJsonMapper._keyAliases (solo en sincronizacion_service). |
| `"KM INIICIO"` | `km_inicio` | Typo con doble I ya cubierto. OK. |
| `"SEGMENTO"` | `tramo` | Ya en aliases. OK. |
| `"OBSERVACIONES"` | `situacion_social` | Ya en aliases. OK. |
| `"PROYECTO"`, `"PROPIETARIO"`, etc. | varios | Ya en aliases. OK. |
| `"estado"`, `"municipio"` | estado / municipio | No existen en el archivo. No se pueden poblar desde esta fuente. |

## 3. Fases implementadas

### Fase 1: GeoJsonMapper._keyAliases
- Se agrego `'TIPO DE PROPIEDAD'` y `'tipo de propiedad'` a la clave `tipo_propiedad`.
- Se agrego `'KM FIN'` y `'km fin'` a la clave `km_fin`.
- Se agrego `'KM EFECTIVOS'` y `'km efectivos'` a la clave `km_efectivos`.
- Se agrego `'anuencia'` y `'ANUENCIA'` a la clave `cop`.
- Archivo: `lib/features/carga/utils/geojson_mapper.dart`

### Fase 2: Background parser (primer paso de lectura)
- Se agrego `'KM FIN'`, `'km fin'` a `kmFinKeys`.
- Se agrego `'KM EFECTIVOS'`, `'km efectivos'` a `kmEfectivosKeys`.
- Archivo: `lib/features/carga/services/geojson_background_parser.dart`

### Fase 3: SincronizacionService._resolveTipoPropiedad
- Se agrego `'TIPO DE PROPIEDAD'` y `'tipo de propiedad'` a la lista de aliases del metodo flexible.
- Archivo: `lib/features/carga/services/sincronizacion_service.dart`

## 4. Criterio de exito
- Al importar el GeoJSON real, `tipo_propiedad` queda como `ESTATAL` / `DESCONOCIDO` (segun el valor del archivo).
- `km_fin` y `km_efectivos` quedan con los valores numericos del archivo.
- `cop` queda en `false` para predios con ESTATUS "NO LIBERADO".

## 5. Nota sobre estado y municipio
El archivo fuente no contiene columnas `estado` ni `municipio`. Esos campos quedaran vacios de forma esperada.
Si en el futuro el archivo los incluya bajo otro nombre, agregar el alias al mapper.

## 6. Proximo paso
- Eliminar los predios ya importados con datos incorrectos desde la pantalla Archivos.
- Reimportar el GeoJSON para que los nuevos alias tomen efecto sobre registros nuevos.
