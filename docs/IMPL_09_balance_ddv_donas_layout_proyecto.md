# IMPL_09_balance_ddv_donas_layout_proyecto

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir tres aspectos de la pantalla Balance:
1. Mostrar en Avance DDV una barra de progreso por estatus liberado vs no liberado.
2. Mostrar siempre las gráficas de dona en Avance por Tipo de Propiedad, incluso cuando el total sea cero.
3. Distribuir los 4 contenedores de Avance de Proyecto de forma equitativa ocupando toda la fila.

## 2. Diagnóstico / contexto actual
La pantalla Balance presentaba tres problemas:
- Avance DDV usaba una barra segmentada basada en superficie y tres estados, no una barra simple por estatus liberado/no liberado.
- Las donas de tipo de propiedad se degradaban a texto cuando el total era cero, ocultando la visualización esperada.
- Los KPI de proyecto estaban dentro de un `ListView` horizontal, por lo que no llenaban la fila de extremo a extremo.

## 3. Fases

### Fase 1 - Barra DDV por estatus
Descripcion: Se reemplazó la barra de avance DDV basada en superficie por una barra de estatus con solo dos segmentos: liberado y no liberado, usando conteo de predios.
Archivos afectados: `lib/features/reportes/presentation/balance_screen.dart`
Código clave:
- `prediosLiberados` y `prediosNoLiberados`
- `_buildAvanceDdvStatusBar(...)`
Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2 - Donas visibles en cero
Descripcion: Se forzó la representación visual de las donas en tipo de propiedad incluso con total cero, usando un anillo tenue y rotulación `0 / 0`.
Archivos afectados: `lib/features/reportes/presentation/balance_screen.dart`
Código clave:
- Rama `if (total == 0)` en `_buildDonaSeparada(...)`
Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 3 - KPI de proyecto a ancho completo
Descripcion: Se cambió la fila de KPI de proyecto para usar distribución equitativa con `Expanded`, ocupando todo el ancho disponible. En pantallas angostas cae a una disposición en 2 filas.
Archivos afectados: `lib/features/reportes/presentation/balance_screen.dart`
Código clave:
- `LayoutBuilder` + `Row` con `Expanded`
- Eliminación del ancho fijo en `_buildKpiPanel(...)`
Tiempo estimado: 20 min
Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 55 min | Bajo |

## 5. Criterio de éxito
- Avance DDV muestra una barra clara de liberado vs no liberado.
- Las donas de tipo de propiedad se muestran incluso con valores cero.
- Los 4 KPI de proyecto llenan la fila de extremo a extremo de manera uniforme.
- La pantalla compila sin errores.

## 6. Resultado / evidencia
- Cambios aplicados en la pantalla Balance.
- Validación ejecutada: `flutter analyze lib/features/reportes/presentation/balance_screen.dart`
- Resultado: sin issues.

## 7. Próximo paso
Validar visualmente en Balance:
1. Proyecto con datos liberados y no liberados.
2. Proyecto/segmento sin predios para confirmar donas visibles en cero.
3. Desktop ancho para revisar que los 4 KPI ocupan toda la fila.
