# IMPL_38 - Importacion GeoJSON PKS de puntos solo en mapa

Estado: Implementado
Fecha: 2026-07-07
Rama: main

## 1. Objetivo
Agregar una funcion de importacion especial para GeoJSON de PKS con geometria de puntos, de modo que:
- no se inyecte a Gestion,
- solo se renderice en el mapa,
- cada punto muestre etiqueta de su propiedad,
- exista un control sobre el mapa con texto `PKS` para encender o apagar las etiquetas.

## 2. Diagnostico / contexto actual
El flujo de importacion de GeoJSON enviaba los features al motor de sincronizacion de predios, lo que terminaba inyectando datos en Gestion. Para archivos PKS de puntos esto no era deseado.

## 3. Fases

### Fase 1 - Estado dedicado para PKS en mapa
Descripcion: Se creo un provider exclusivo para almacenar features PKS de puntos y se incluyo en la limpieza global del estado de mapa.
Archivos afectados:
- lib/features/mapa/providers/mapa_provider.dart
- lib/features/mapa/providers/mapa_state_cleanup.dart
- test/features/mapa/providers/mapa_state_cleanup_test.dart
Codigo clave:
- `pksPointFeaturesProvider`
- `clearImportedMapState(...)` limpia tambien PKS
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 2 - Deteccion PKS de puntos en Carga
Descripcion: En el flujo `Guardar y ver en mapa` se detecta si el archivo corresponde a PKS de puntos (por nombre/propiedades y geometria Point/MultiPoint). Si aplica, se evita sincronizacion con Gestion y se guarda como archivo de mapa.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `_isPksPointImport(...)`
- `_guardarPksSoloMapa(...)`
- `_featureMentionsPks(...)`
- `_geometryType(...)`
Tiempo estimado:
- 35 min
Riesgo:
- Medio-bajo

### Fase 3 - Visualizacion PKS en Mapa + toggle PKS
Descripcion: Se agregaron marcadores de puntos PKS y marcadores de etiquetas con texto de propiedad. Se añadió boton superior con texto `PKS` para encender/apagar etiquetas.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_buildPksPointMarkers(...)`
- `_buildPksLabelMarkers(...)`
- `_extractPksPointLabel(...)`
- `_buildPksLabelsToggleButton()`
Tiempo estimado:
- 40 min
Riesgo:
- Bajo

### Fase 4 - Navegacion y limpieza desde Archivos
Descripcion: Al usar `Ver en mapa` desde Archivos se distingue entre archivo normal e importacion PKS de puntos. Tambien se limpia estado PKS al eliminar archivos.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `_verEnMapaDesdeTabla(...)`
- `_shouldClearPksPointsAfterFileDeletion(...)`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 35 min | Medio-bajo |
| Fase 3 | 40 min | Bajo |
| Fase 4 | 20 min | Bajo |
| Total | 115 min | Bajo-medio |

## 5. Criterio de éxito
- Importar un GeoJSON PKS de puntos no genera filas en Gestion.
- Los puntos PKS se muestran en mapa.
- Cada punto muestra su etiqueta de propiedad cuando el toggle PKS esta activo.
- El boton `PKS` permite encender/apagar etiquetas sin afectar capas normales.

## 6. Resultado / evidencia
- Implementacion aplicada en Carga, Mapa y Providers.
- Validacion estatica sin errores en los archivos modificados.
- Prueba de limpieza actualizada para incluir provider PKS.

## 7. Proximo paso
Validar en runtime con un archivo real PKS de puntos:
1. Importar desde Archivos.
2. Confirmar que no aparece en Gestion.
3. Abrir mapa y verificar puntos + etiquetas.
4. Alternar boton `PKS` para encender/apagar etiquetas.
