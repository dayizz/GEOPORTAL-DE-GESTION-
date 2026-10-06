# Balance de estaciones y edificios auxiliares en m²

**Estado:** Implementado
**Fecha:** 2026-10-05
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Usar exclusivamente la superficie en m² como medida de avance para el grupo “Estaciones y Edificios Auxiliares” en la vista de Balance. Mantener kilómetros efectivos para los demás grupos que usan longitud.

## Diagnóstico / contexto actual

La vista distinguía ambos grupos, pero la selección de medida estaba dispersa entre sus indicadores y el resumen por tramo. El cálculo temporal aceptaba una medida personalizada, aunque su nombre y parámetro seguían vinculados a kilómetros, dejando ambigua la unidad para estaciones y edificios.

## Fases

### Fase 1: Centralizar y aplicar la medida

- **Descripción:** Definir una función común para seleccionar superficie o km efectivos y usar una API de cálculo temporal con nombres neutrales. Aplicarla a los indicadores, el avance temporal y el resumen por T/F/S.
- **Archivos afectados:** `lib/features/reportes/utils/balance_calculos.dart`, `lib/features/reportes/presentation/balance_screen.dart`, `lib/features/reportes/presentation/widgets/resumen_tramos_widget.dart`.
- **Código clave:** `medidaPredioBalance` elige `superficie` cuando se muestran m²; el cálculo por periodo recibe la medida y el total con nombres neutrales.
- **Tiempo estimado:** 30 minutos.
- **Riesgo:** Bajo; se conserva el cálculo por km para grupos distintos de estaciones y edificios.

### Fase 2: Prueba de regresión y verificación

- **Descripción:** Comprobar que estaciones usan superficie y los predios normales conservan los km efectivos.
- **Archivos afectados:** `test/features/reportes/balance_infraestructura_test.dart`.
- **Código clave:** Prueba con superficie y km distintos para ambos tipos de registro.
- **Tiempo estimado:** 10 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Fase | Estimación | Riesgo |
| --- | ---: | --- |
| Centralizar y aplicar la medida | 30 min | Bajo |
| Prueba y verificación | 10 min | Bajo |
| **Total** | **40 min** | **Bajo** |

## Criterio de éxito

Los indicadores y avances del grupo de estaciones y edificios auxiliares calculan y presentan superficie en m², sin depender de `kmEfectivos`; los demás grupos mantienen su métrica de km.

## Resultado / evidencia

Implementación aplicada en los archivos indicados. `flutter test test/features/reportes/balance_infraestructura_test.dart` pasó: todas las pruebas finalizaron correctamente.

## Próximo paso

Validar visualmente en Balance con registros de estaciones y edificios que tengan valores distintos de superficie y km efectivos.