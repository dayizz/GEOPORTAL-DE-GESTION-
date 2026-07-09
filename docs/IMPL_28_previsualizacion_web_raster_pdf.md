# IMPL_28 - Previsualizacion web por raster de PDF

Estado: Completado  
Fecha: 2026-07-03  
Rama: main

## 1. Objetivo
Corregir el problema de previsualizacion que quedaba en carga infinita en web, manteniendo el flujo:
- Aceptar -> Previsualizar
- Generar PDF -> Descargar

## 2. Diagnostico / contexto actual
El visor `PdfPreview` en web quedaba en spinner permanente en algunos casos, impidiendo ver el documento aunque el PDF ya se habia generado correctamente.

## 3. Fases

### Fase 1 - Render de previsualizacion web por imagenes
Descripcion: Se implemento una ruta web alternativa que rasteriza el PDF y muestra sus paginas como imagenes dentro del panel de previsualizacion.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `_rasterizarPreviewWeb(Uint8List pdfBytes)` usando `Printing.raster`.
- `_prepararPreviewWeb(Uint8List pdfBytes)` con control de estado y timeout.
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 2 - Estados de carga/error/reintento
Descripcion: Se agregaron estados para carga de preview web, error de render y accion de reintento.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- Variables de estado: `_isRenderingWebPreview`, `_webPreviewImages`, `_webPreviewError`.
- Widget `_buildWebPreviewContent()` con spinner, mensaje y boton de reintento.
Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 3 - Integracion en flujo actual
Descripcion: Se conecto la preparacion de miniaturas web en `Aceptar` y se limpio estado al volver a editar.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- En `_aceptar()`, al generar bytes se dispara `_prepararPreviewWeb` en web.
- En boton `Editar`, limpieza de estados de preview web.
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| 1. Raster web | 20 min | Medio |
| 2. Estados y reintento | 15 min | Bajo |
| 3. Integracion flujo | 10 min | Bajo |
| Total | 45 min | Bajo-Medio |

## 5. Criterio de exito
- La previsualizacion en web deja de quedarse congelada en spinner.
- El usuario visualiza paginas del PDF en el panel de previsualizacion.
- La descarga solo ocurre al pulsar "Generar PDF".

## 6. Resultado / evidencia
- Implementacion aplicada en `lib/features/reportes/presentation/generar_reporte_screen.dart`.
- `flutter analyze` ejecutado sobre el archivo sin errores de compilacion.
- Hot restart ejecutado para validar en tiempo real.

## 7. Proximo paso
Validar manualmente en la vista de reportes:
1) Aceptar -> previsualizacion visible en panel derecho.
2) Generar PDF -> descarga del archivo.