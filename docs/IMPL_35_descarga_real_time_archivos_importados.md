# IMPL_35 - Descarga en tiempo real de archivos importados

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Agregar un icono de descarga en la lista de archivos importados de la pantalla Archivos para exportar el estado actual del archivo en `.geojson` o `.xlsx`, reflejando los cambios guardados en la app al momento de descargar.

## 2. Diagnóstico / contexto actual
La lista de archivos importados ya persistía `features`, pero no existía una acción directa para exportar desde el estado actual de la app.
Además, el flujo debía cumplir dos condiciones:
- permitir descargar el archivo importado desde el propio tile,
- usar el estado vigente de predios para que los cambios hechos en pantalla queden reflejados en la exportación.

## 3. Fases

### Fase 1 - Exportación basada en estado actual
Descripción: Se creó un exportador dedicado que construye el archivo descargable a partir de los predios actuales de la app. Para GeoJSON se reconstruye un `FeatureCollection`; para XLSX se genera una hoja con los datos vigentes del archivo.
Archivos afectados:
- lib/features/carga/utils/archive_exporter.dart
- lib/features/carga/utils/file_download.dart
- lib/features/carga/utils/file_download_io.dart
- lib/features/carga/utils/file_download_web.dart
Código clave:
- `buildArchiveExportPayload(...)`
- `downloadBytes(...)`
Tiempo estimado:
- 60 min
Riesgo:
- Medio

### Fase 2 - Botón de descarga en la lista de archivos
Descripción: Se añadió un menú de descarga por archivo en la pantalla Archivos con las opciones `.geojson` y `.xlsx`, conectado al estado actual de predios.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Código clave:
- `PopupMenuButton<String>` con opciones de formato
- `_descargarArchivoImportado(...)`
Tiempo estimado:
- 30 min
Riesgo:
- Bajo

### Fase 3 - Apoyo de limpieza y validación
Descripción: Se añadieron utilidades de limpieza de claves para que la exportación pueda identificar predios por clave catastral normalizada y generar descargas consistentes con el estado visible.
Archivos afectados:
- lib/features/carga/utils/imported_file_cleanup.dart
- test/features/carga/utils/imported_file_cleanup_test.dart
Código clave:
- `extractClavesFromFeatures(...)`
- `shouldClearImportedMapAfterFileDeletion(...)`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 60 min | Medio |
| Fase 2 | 30 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 110 min | Medio |

## 5. Criterio de éxito
- Cada archivo importado muestra un icono de descarga.
- El usuario puede elegir `.geojson` o `.xlsx`.
- La descarga usa el estado actual de los predios y no una copia obsoleta.
- Los cambios realizados desde la app quedan reflejados en el archivo descargado.

## 6. Resultado / evidencia
- Se implementó el exportador real-time por formato.
- Se integró el botón de descarga en el tile de archivos importados.
- Se validó la compilación de los archivos modificados sin errores estaticos.
- Se dejó cobertura básica con pruebas para la utilidad de limpieza usada por el flujo.

## 7. Próximo paso
Validar en la UI el flujo completo:
1. Importar un archivo.
2. Modificar campos desde la app.
3. Descargar `.geojson` o `.xlsx` desde Archivos.
4. Confirmar que el archivo descargado contiene los cambios más recientes.
