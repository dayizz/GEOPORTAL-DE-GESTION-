# IMPL_65 Encuesta Previa de Importacion Tipo y Contenido

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo
Agregar una encuesta previa a la importacion para reducir errores de carga y forzar reglas de negocio segun el tipo de archivo y su contenido.

## 2. Diagnostico / contexto actual
El flujo previo dependia principalmente de la extension del archivo y de detecciones automaticas por propiedades (por ejemplo PKS o ENVOLVENTE).
Eso permitia ambiguedades cuando el usuario queria forzar un comportamiento especifico para una importacion.

## 3. Fases

### Fase 1: Encuesta previa obligatoria
- Descripcion: Se agrego modal antes de seleccionar archivo con dropdown de tipo de archivo.
- Archivos afectados: lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - _mostrarEncuestaPreviaImportacion()
  - _ImportSurveyResult
- Tiempo estimado: 25 min
- Riesgo: Bajo

### Fase 2: Sub-encuesta condicional para GeoJson
- Descripcion: Si el usuario elige GeoJson, se despliega segundo dropdown para contenido del archivo: Predios, Envolvente o PKs.
- Archivos afectados: lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - Dropdown condicional de contenido GeoJson en _mostrarEncuestaPreviaImportacion()
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Enrutamiento estricto por seleccion
- Descripcion: Se forzo el flujo de importacion segun la encuesta:
  - XLSX: inyeccion en Gestion por proyecto detectado.
  - GeoJson Predios: sincronizacion en Gestion y render en mapa.
  - GeoJson Envolvente: solo mapa.
  - GeoJson PKs: solo mapa.
  Tambien se ajusto el selector de extensiones para evitar errores de tipo.
- Archivos afectados: lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - _seleccionarArchivo()
  - _guardarYVerEnMapa(forcedGeoJsonContent: ...)
  - _buildSurveySummaryLabel()
- Tiempo estimado: 45 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| 1. Encuesta previa | 25 min | Bajo |
| 2. Sub-encuesta GeoJson | 20 min | Bajo |
| 3. Enrutamiento por seleccion | 45 min | Medio |
| Total | 90 min | Bajo-Medio |

## 5. Criterio de exito
- Siempre se muestra encuesta antes de seleccionar archivo.
- Si se elige GeoJson, siempre aparece dropdown de contenido.
- El flujo final respeta la seleccion del usuario:
  - XLSX solo Gestion.
  - GeoJson Predios Gestion + mapa.
  - GeoJson Envolvente solo mapa.
  - GeoJson PKs solo mapa.
- No hay errores de analizador en los cambios implementados.

## 6. Resultado / evidencia
- Implementada encuesta previa y forzada.
- Implementada validacion de extension segun tipo elegido.
- Implementado enrutamiento forzado de GeoJson por contenido seleccionado.
- Conservadas reglas existentes para deteccion automatica cuando no aplica forzado.
- Verificado: sin errores en analizador para el archivo modificado.

## 7. Proximo paso
Validar manualmente los 4 escenarios con archivos reales:
- XLSX,
- GeoJson Predios,
- GeoJson Envolvente,
- GeoJson PKs,
confirmando pantalla destino esperada (Gestion o Mapa) y contenido renderizado.
