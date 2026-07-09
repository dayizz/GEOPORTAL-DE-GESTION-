# IMPL_48 - Gestion Detalle: ocultar estado COP

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Ocultar la tarjeta de estado `C.O.P.` en la vista de detalle de predio en Gestion para alinearla con el nuevo flujo (sin checklist de COP firmado en formulario).

## 2. Diagnostico / contexto actual
La pantalla de detalle mantenia una metrica visual de estado COP (`FIRMADO/PENDIENTE`) que ya no corresponde al flujo vigente.

## 3. Fases

### Fase 1 - Ajuste visual en detalle
Descripcion: Se removio la segunda tarjeta del bloque "Tramo y COP" y se dejo solo "Cadenamiento".
Archivos afectados:
- lib/features/tabla/presentation/gestion_predio_detail_screen.dart
Codigo clave:
- Eliminacion de `_buildMetricCard` para `C.O.P.`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Total | 10 min | Bajo |

## 5. Criterio de exito
- La vista detalle ya no muestra la tarjeta `C.O.P.`.
- La tarjeta de `Cadenamiento` se mantiene operativa.

## 6. Resultado / evidencia
- Cambio aplicado en pantalla de detalle de Gestion.
- Validacion estatica del archivo sin errores.

## 7. Proximo paso
Revisar visualmente en web la vista de detalle para confirmar espaciados y consistencia con el flujo de Gestion.
