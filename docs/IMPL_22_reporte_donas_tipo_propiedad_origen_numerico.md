# IMPL_22_reporte_donas_tipo_propiedad_origen_numerico

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Agregar al reporte PDF las graficas de dona por tipo de propiedad con su avance (liberados/no liberados), y permitir elegir en el formulario el origen de los datos numericos: Proyecto o Segmento.

## 2. Diagnostico / contexto actual
El reporte generaba solo resumen textual sin donas de avance por tipo de propiedad y sin selector para definir si los datos debian cuantificarse a nivel de proyecto completo o segmento especifico.

## 3. Fases

### Fase 1 - Selector de origen numerico en formulario
Descripcion: Se agrego al final del formulario la opcion "Colocar Datos Numericos de:" con marcaje para Proyecto o Segmento; al elegir Segmento se habilita selector de tramo.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `_datosNumericosDe`
- `_segmentoSeleccionado`
- Radio/selector de segmento
Tiempo estimado: 25 min
Riesgo: Medio

### Fase 2 - Filtrado de cuantificacion por origen
Descripcion: El motor del PDF ahora calcula estadisticas segun la opcion seleccionada (proyecto completo o segmento).
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `prediosBase` condicionado por `_datosNumericosDe`
- `Datos numericos de: ...` en salida PDF
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 3 - Donas de avance por tipo de propiedad en PDF
Descripcion: Se agrego una pagina con donas de avance para Propiedad privada y Propiedad social/dominio pleno, incluyendo total, liberados y no liberados.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `_buildDonutSvg`
- `_buildPdfDonutCard`
- seccion "Avance por tipo de propiedad"
Tiempo estimado: 35 min
Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Medio |
| Fase 2 | 20 min | Medio |
| Fase 3 | 35 min | Medio |
| **Total** | **80 min** | **Medio** |

## 5. Criterio de exito
- El formulario permite elegir Proyecto o Segmento para la cuantificacion.
- Si se selecciona Segmento, el reporte usa solo ese subconjunto de datos.
- El PDF incluye donas de avance por tipo de propiedad, con base numerica visible.

## 6. Resultado / evidencia
- Cambio implementado y validado con `flutter analyze` sobre el archivo objetivo.
- El PDF ahora muestra la seccion visual de avance por tipo de propiedad.

## 7. Proximo paso
Validar visualmente en Reportes la proporcion de donas y espacios de pagina para cada proyecto/segmento, y ajustar tamanos si se requiere.
