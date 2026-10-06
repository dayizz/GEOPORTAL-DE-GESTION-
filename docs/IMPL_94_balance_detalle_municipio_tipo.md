# Detalle municipal y por tipo en avance de Balance

**Estado:** Implementado
**Fecha:** 2026-10-05
**Rama:** `fix/gestion-control-versiones`

## Objetivo

En el grupo “Estaciones y Edificios Auxiliares”, subdividir la tabla de avance por T/F/S, municipio y tipo de infraestructura, manteniendo los indicadores de superficie y liberación existentes.

## Diagnóstico / contexto actual

El resumen de tramos presentaba una fila agregada por T/F/S. Los predios ya contienen municipio, estructura y superficie, pero la tabla no mostraba esos detalles ni sus métricas de liberación por subdivisión.

## Fases

### Fase 1: Agrupación municipal

- **Descripción:** Agrupar por T/F/S, municipio normalizado y categoría de infraestructura; mostrar `Sin municipio` cuando falte el dato y mapear el alias SICA a ZICA.
- **Archivos afectados:** `lib/features/reportes/utils/resumen_tramos.dart`.
- **Código clave:** `resumenMunicipioInfraestructuraBalance` calcula superficie total, predios clasificados y liberados, m² liberados y porcentaje.
- **Tiempo estimado:** 30 minutos.
- **Riesgo:** Bajo; no modifica el cálculo ni la presentación del resumen por kilómetros.

### Fase 2: Tabla de detalle

- **Descripción:** Para la vista m², presentar T/F/S, municipio, tipo de infraestructura, superficie total y las columnas de conteo y avance existentes.
- **Archivos afectados:** `lib/features/reportes/presentation/widgets/resumen_tramos_widget.dart`.
- **Código clave:** Columnas y filas específicas para superficie; la tabla por km conserva cadenamiento y longitud.
- **Tiempo estimado:** 25 minutos.
- **Riesgo:** Bajo.

### Fase 3: Pruebas

- **Descripción:** Verificar agrupación de municipios con diferencias de mayúsculas, tipos de infraestructura, estatus y superficies.
- **Archivos afectados:** `test/features/reportes/resumen_tramos_test.dart`.
- **Código clave:** Prueba de suma de superficies desglosadas y avance liberado por agrupación.
- **Tiempo estimado:** 15 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Fase | Estimación | Riesgo |
| --- | ---: | --- |
| Agrupación municipal | 30 min | Bajo |
| Tabla de detalle | 25 min | Bajo |
| Pruebas | 15 min | Bajo |
| **Total** | **70 min** | **Bajo** |

## Criterio de éxito

Cada fila m² representa una combinación de T/F/S, municipio y tipo; incluye superficie total, número de predios clasificados y liberados, m² liberados y porcentaje de avance. La suma de superficies de las filas coincide con la superficie de los predios agrupados.

## Resultado / evidencia

Implementación aplicada. `flutter test test/features/reportes/resumen_tramos_test.dart` pasó después de aplicar formato.

## Próximo paso

Revisar la tabla en la vista local con datos reales y confirmar que los municipios sin dato aparezcan como `Sin municipio`.