# IMPL_61 - Fix Cmd+V/Ctrl+V sin dependencia de foco en dialogo URL

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Corregir el pegado por teclado (`Cmd+V` / `Ctrl+V`) en el dialogo `Vincular URL de archivo` cuando el clic derecho ya funcionaba pero el atajo no.

## 2. Diagnostico / contexto actual
El listener web de `paste` estaba condicionado por `focusNode.hasFocus`. En Flutter web, el foco del campo puede no reflejarse de forma confiable para atajos de teclado aunque el usuario este escribiendo en ese input.

## 3. Fases

### Fase 1 - Ajuste de listener de paste
Descripcion: Se elimino la validacion estricta de foco para permitir insertar texto pegado siempre que el dialogo este abierto.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Eliminacion de `if (!focusNode.hasFocus) return;`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Total | 5 min | Bajo |

## 5. Criterio de exito
- `Cmd+V` / `Ctrl+V` inserta el link en el campo URL del dialogo.
- Se mantiene la apertura posterior del link en navegador desde COP/DOT.

## 6. Resultado / evidencia
- Cambio aplicado y validado sin errores estaticos.

## 7. Proximo paso
Verificar en web: abrir dialogo URL, pegar con teclado y guardar.
