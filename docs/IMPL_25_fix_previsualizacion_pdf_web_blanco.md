# IMPL_25 - Fix previsualizacion PDF web en blanco

Estado: Completado  
Fecha: 2026-07-03  
Rama: main

## 1. Objetivo
Corregir el problema donde la previsualizacion PDF en web aparecia en blanco antes de la descarga.

## 2. Diagnostico / contexto actual
La previsualizacion web dependia de un iframe con ciclo de vida sensible en Flutter Web. En ciertos casos el iframe quedaba en estado obsoleto y mostraba pantalla blanca aun teniendo bytes de PDF validos.

## 3. Fases

### Fase 1 - Robustecer bridge web de PDF
Descripcion: Se hizo el componente de preview mas resiliente para web, evitando estados obsoletos y recargando correctamente el source del PDF.
Archivos afectados:
- lib/features/reportes/presentation/pdf_preview_bridge_web.dart
Codigo clave:
- Nuevo contador para viewType unico por instancia.
- Reuso de IFrameElement interno con actualizacion de src mediante object URL.
- didUpdateWidget para refrescar el PDF cuando cambian bytes.
- Query de visor agregada en src: #toolbar=1&navpanes=0&scrollbar=1.
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 2 - Forzar reconstruccion del preview en pantalla
Descripcion: Se agrego key estable al widget de preview en la vista de reportes para evitar caches visuales del bridge web.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- buildWebPdfPreview(..., key: ValueKey<int>(Object.hash(...))).
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Compatibilidad de firma en stub
Descripcion: Se actualizo el bridge stub para aceptar parametro key y mantener firma comun en import condicional.
Archivos afectados:
- lib/features/reportes/presentation/pdf_preview_bridge_stub.dart
Codigo clave:
- buildWebPdfPreview(Uint8List bytes, {Key? key})
Tiempo estimado: 5 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| 1. Bridge web resiliente | 20 min | Medio |
| 2. Reconstruccion con key | 10 min | Bajo |
| 3. Firma compatible stub | 5 min | Bajo |
| Total | 35 min | Bajo-Medio |

## 5. Criterio de exito
- En web, al pulsar Aceptar, la previsualizacion renderiza PDF sin quedar en blanco.
- Se mantiene flujo: Aceptar = previsualizar, Generar PDF = descargar.

## 6. Resultado / evidencia
- Cambios aplicados en:
  - lib/features/reportes/presentation/pdf_preview_bridge_web.dart
  - lib/features/reportes/presentation/pdf_preview_bridge_stub.dart
  - lib/features/reportes/presentation/generar_reporte_screen.dart
- Analisis ejecutado sobre los archivos modificados sin errores de compilacion.
- Hot restart ejecutado para probar inmediatamente en entorno web.

## 7. Proximo paso
Validar en navegador (sesion autenticada) el flujo completo de reportes para confirmar que la previsualizacion ya no aparece en blanco y que la descarga ocurre solo con el boton Generar PDF.