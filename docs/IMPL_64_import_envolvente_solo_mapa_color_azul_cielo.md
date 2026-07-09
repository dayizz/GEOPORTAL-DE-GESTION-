# IMPL_64 Import ENVOLVENTE Solo Mapa Color Azul Cielo

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo
Implementar una regla de importacion para archivos ENVOLVENTE que:
- no sincronice ni inserte registros en Gestion,
- se renderice solo en Mapa,
- aplique estilo visual en azul cielo sin opacidad,
- normalice metadatos para identificar facilmente estas features en el flujo.

## 2. Diagnostico / contexto actual
El flujo de importacion tenia una ruta especial para PKS (puntos solo mapa), pero no existia una ruta equivalente para ENVOLVENTE.
Como resultado, un archivo ENVOLVENTE podia entrar al flujo de sincronizacion de Gestion y perder la intencion de uso como capa de referencia visual.

## 3. Fases

### Fase 1: Deteccion de ENVOLVENTE en importacion
- Descripcion:
Se agrego deteccion por nombre de archivo y por contenido de propiedades para identificar imports ENVOLVENTE.
- Archivos afectados:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - _isEnvolventeImport(...)
  - _featureMentionsEnvolvente(...)
- Tiempo estimado: 30 min
- Riesgo: Bajo

### Fase 2: Ruta solo mapa + normalizacion de datos
- Descripcion:
Se implemento una ruta dedicada para guardar en listado de archivos y renderizar solo en mapa, sin sincronizacion a Gestion.
Tambien se normalizaron metadatos para identificacion canonica.
- Archivos afectados:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - _guardarEnvolventeSoloMapa(...)
  - _normalizeEnvolventeFeatures(...)
  - tags normalizados: __import_kind=envolvente, __envolvente=true, categoria=ENVOLVENTE
- Tiempo estimado: 45 min
- Riesgo: Medio

### Fase 3: Estilo de render en mapa
- Descripcion:
Se aplico estilo diferencial para features ENVOLVENTE: color azul cielo totalmente opaco (sin transparencia), tanto en relleno como en borde.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Codigo clave:
  - _isEnvolventeFeature(...)
  - _importedFeatureColor(...)
  - _buildImportedPolygons(...)
- Tiempo estimado: 35 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| 1. Deteccion ENVOLVENTE | 30 min | Bajo |
| 2. Ruta solo mapa + normalizacion | 45 min | Medio |
| 3. Render azul cielo opaco | 35 min | Bajo |
| Total | 110 min | Bajo-Medio |

## 5. Criterio de exito
- Si el nombre de archivo contiene ENVOLVENTE o sus propiedades contienen ENVOLVENTE, entonces:
  - no se ejecuta sincronizacion a Gestion,
  - las features se cargan solo en capa de importados del mapa,
  - se visualizan en azul cielo sin opacidad,
  - quedan marcadas con metadatos normalizados para identificacion rapida.

## 6. Resultado / evidencia
- Implementado en flujo de carga:
  - branch de decision ENVOLVENTE previo a PKS en _guardarYVerEnMapa(...).
  - ruta exclusiva _guardarEnvolventeSoloMapa(...).
- Implementado en visualizacion:
  - deteccion _isEnvolventeFeature(...).
  - color fijo Color(0xFF87CEEB).
  - render de poligonos ENVOLVENTE sin alpha.
- Validacion tecnica:
  - sin errores en analizador para los archivos modificados.

## 7. Proximo paso
Ejecutar prueba funcional con dos casos:
- archivo llamado ENVOLVENTE.geojson con poligonos,
- archivo sin nombre ENVOLVENTE pero con propiedad textual que contenga ENVOLVENTE,
para confirmar ruta solo mapa y estilo azul cielo opaco en ambos escenarios.
