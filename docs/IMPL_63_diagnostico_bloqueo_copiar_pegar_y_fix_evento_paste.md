# IMPL_63 - Diagnostico bloqueo copiar/pegar y fix por evento paste

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Identificar el bloqueo de copiar/pegar en el dialogo de URL en Gestion y aplicar ajuste para que `Cmd+V/Ctrl+V` funcione.

## 2. Diagnostico / contexto actual
Se detecto que el flujo de pegado dependia de:
- listener `keydown`, y
- condicion `focusNode.hasFocus`.

En Flutter web/dialogos, ese estado de foco puede no reflejarse consistentemente para atajos de teclado, bloqueando el pegado.

## 3. Fases

### Fase 1 - Cambio a evento paste del navegador
Descripcion: Se reemplazo el listener por `document.onPaste`, que responde directamente al pegado por teclado (`Cmd+V/Ctrl+V`) y menu contextual.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `StreamSubscription<html.Event>? pasteSub`
- `html.document.onPaste.listen(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Limpieza de dependencia de foco
Descripcion: Se elimino el bloqueo por `focusNode.hasFocus` del flujo de pegado.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- remocion de condicion de foco en pegado
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- `Cmd+V/Ctrl+V` inserta texto en el campo URL del dialogo.
- Se mantiene guardado y apertura del link en navegador.

## 6. Resultado / evidencia
- Bloqueo identificado y ajuste aplicado.
- Validacion estatica sin errores.

## 7. Proximo paso
Validar en web: abrir dialogo URL, pegar con teclado y guardar.
