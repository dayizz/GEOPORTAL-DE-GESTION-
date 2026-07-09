# IMPL_23_fix_previsualizacion_timeout_fuentes_pdf

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir el bloqueo de previsualizacion del reporte PDF cuando la carga de fuentes externas tarda o falla.

## 2. Diagnostico / contexto actual
La generacion de previsualizacion dependia de `PdfGoogleFonts`; en escenarios de red lenta o fallo remoto podia quedarse esperando y la vista no terminaba de cargar.

## 3. Fases

### Fase 1 - Timeout de fuentes
Descripcion: Se agrego timeout a la carga de fuentes para evitar espera indefinida.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `PdfGoogleFonts.notoSansRegular().timeout(...)`
- `PdfGoogleFonts.notoSansBold().timeout(...)`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Fallback local de fuentes
Descripcion: Si falla la carga remota, se usan fuentes locales (`helvetica`) y se continua con la generacion del PDF.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `pw.Font.helvetica()`
- `pw.Font.helveticaBold()`
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| **Total** | **20 min** | **Bajo** |

## 5. Criterio de exito
- La previsualizacion no queda colgada por carga de fuentes.
- El PDF se genera aun sin acceso estable a fuentes externas.

## 6. Resultado / evidencia
- Cambio aplicado en el generador de reporte.
- Validacion con `flutter analyze` del archivo objetivo.
- Hot restart ejecutado.

## 7. Proximo paso
Validar en la UI la generacion de previsualizacion en al menos dos proyectos distintos y con opcion Proyecto/Segmento.
