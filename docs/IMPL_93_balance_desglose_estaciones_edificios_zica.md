# Desglose de estaciones, edificios auxiliares y ZICA en Balance

**Estado:** Implementado
**Fecha:** 2026-10-05
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Agregar a la vista de Balance tres tarjetas de conteo para “Estaciones y Edificios Auxiliares”: predios para estaciones, predios para edificios auxiliares y predios para ZICA. La suma de estos conteos coincide con el total de registros clasificados del grupo.

## Diagnóstico / contexto actual

La vista agrupaba las estructuras Estación, Edificio Auxiliar, ZICA y el alias histórico SICA en una sola categoría. El avance general mostraba el total del grupo sin hacer visibles los conteos por tipo.

## Fases

### Fase 1: Clasificación y conteos

- **Descripción:** Clasificar las estructuras en tres subcategorías, normalizando acentos y variantes singulares/plurales. Considerar SICA como alias de ZICA.
- **Archivos afectados:** `lib/features/reportes/utils/balance_calculos.dart`.
- **Código clave:** `categoriaEstacionesBalance` y `conteoCategoriasEstacionesBalance`.
- **Tiempo estimado:** 20 minutos.
- **Riesgo:** Bajo; las subcategorías comparten la clasificación que alimenta el total existente.

### Fase 2: Tarjetas en avance general

- **Descripción:** Mostrar las tres tarjetas después del total clasificado, únicamente al seleccionar estaciones y edificios auxiliares, y ampliar el ancho desplazable para conservar legibles los títulos.
- **Archivos afectados:** `lib/features/reportes/presentation/balance_screen.dart`.
- **Código clave:** Tarjetas condicionales asociadas al grupo que usa m².
- **Tiempo estimado:** 20 minutos.
- **Riesgo:** Bajo.

### Fase 3: Prueba de regresión

- **Descripción:** Verificar categorías, alias SICA y suma igual al total clasificado.
- **Archivos afectados:** `test/features/reportes/balance_infraestructura_test.dart`.
- **Código clave:** Prueba de desglose con variantes singulares y plurales.
- **Tiempo estimado:** 10 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Fase | Estimación | Riesgo |
| --- | ---: | --- |
| Clasificación y conteos | 20 min | Bajo |
| Tarjetas en avance general | 20 min | Bajo |
| Prueba de regresión | 10 min | Bajo |
| **Total** | **50 min** | **Bajo** |

## Criterio de éxito

En “Estaciones y Edificios Auxiliares” se ven los tres conteos después del total clasificado y su suma coincide con ese total. Las tarjetas no aparecen para los demás grupos.

## Resultado / evidencia

Implementación aplicada. `flutter test test/features/reportes/balance_infraestructura_test.dart` pasó y cubre el desglose, las variantes plurales y el alias SICA.

## Próximo paso

Verificar visualmente la distribución de tarjetas en anchos de escritorio y ventanas más angostas.