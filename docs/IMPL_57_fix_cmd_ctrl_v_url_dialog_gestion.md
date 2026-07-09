# IMPL_57 - Fix Cmd+V/Ctrl+V en dialogo URL de Gestion

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Habilitar de forma confiable el pegado con `Cmd+V` y `Ctrl+V` en el campo URL del dialogo `Vincular URL de archivo`.

## 2. Diagnostico / contexto actual
En ciertos entornos web el pegado nativo no se dispara consistentemente en el input del dialogo.

## 3. Fases

### Fase 1 - Atajo explicito en foco del campo
Descripcion: Se agrego un `Focus` con `onKeyEvent` para capturar `Cmd+V/Ctrl+V` y ejecutar pegado programatico.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Deteccion `LogicalKeyboardKey.keyV` + `isMetaPressed/isControlPressed`
- Invocacion de `_pasteFromClipboard(ctrl)`
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
- Cmd+V/Ctrl+V pega texto en el campo URL del dialogo.
- Se mantiene validacion de URL y guardado.

## 6. Resultado / evidencia
- Cambio aplicado en input URL de Gestion.
- Validacion estatica sin errores.

## 7. Proximo paso
Probar en web: abrir dialogo, enfocar campo URL y pegar con Cmd+V.
