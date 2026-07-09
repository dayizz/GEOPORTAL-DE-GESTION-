# IMPL_26 - Bloqueo de descarga temprana en previsualizacion web

Estado: Completado  
Fecha: 2026-07-03  
Rama: main

## 1. Objetivo
Eliminar cualquier descarga temprana del PDF durante la previsualizacion en web y mantener la descarga solo en el boton "Generar PDF".

## 2. Diagnostico / contexto actual
La ruta de previsualizacion basada en iframe web podia invocar el comportamiento nativo del navegador para guardar el archivo antes de tiempo (dialogo de descarga), rompiendo el flujo requerido.

## 3. Fases

### Fase 1 - Unificar previsualizacion con PdfPreview
Descripcion: Se removio la bifurcacion web por iframe y se dejo `PdfPreview` como visor de previsualizacion para todas las plataformas.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- Reemplazo del bloque `kIsWeb ? buildWebPdfPreview(...) : PdfPreview(...)` por `PdfPreview(...)` unico.
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Verificacion de triggers de descarga
Descripcion: Se verifico que no queden llamadas de descarga en la previsualizacion.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `anchor.click()` y object URL solo en `_generarPdf()`.
Tiempo estimado: 5 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| 1. Unificar preview | 10 min | Bajo |
| 2. Verificar descargas | 5 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- Al pulsar "Aceptar" no se abre dialogo de descarga.
- La descarga se ejecuta solamente al pulsar "Generar PDF".

## 6. Resultado / evidencia
- Cambio aplicado en `lib/features/reportes/presentation/generar_reporte_screen.dart`.
- Hot restart ejecutado para reflejar cambios en web.
- Busqueda de codigo confirma que `anchor.click()` solo existe en `_generarPdf()`.

## 7. Proximo paso
Validacion manual del flujo en navegador:
1) Aceptar (solo previsualiza), 2) Generar PDF (descarga).