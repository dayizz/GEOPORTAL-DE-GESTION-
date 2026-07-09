# IMPL_62 - Fix Cmd+V/Ctrl+V con keydown + navigator.clipboard.readText

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Hacer funcional el pegado por teclado (`Cmd+V` / `Ctrl+V`) en el dialogo `Vincular URL de archivo` de Gestion, aun cuando el pegado nativo falle.

## 2. Diagnostico / contexto actual
El paste nativo no era consistente en Flutter web para este dialogo. Se requiere un fallback directo por teclado.

## 3. Fases

### Fase 1 - Listener de keydown en web
Descripcion: Se agrego un listener temporal `document.onKeyDown` mientras el dialogo esta abierto para detectar `V` con `Meta/Ctrl`.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `key == 'v' && (event.metaKey || event.ctrlKey)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Lectura directa de portapapeles
Descripcion: En el atajo detectado, se lee `navigator.clipboard.readText()` y se inserta en el controlador del campo URL.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `html.window.navigator.clipboard?.readText()`
- Helper `_insertTextInController(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 3 - Limpieza de recursos
Descripcion: Se cancela la suscripcion de teclado al cerrar el dialogo.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `await keyDownSub?.cancel()`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de exito
- Con foco en URL, `Cmd+V` / `Ctrl+V` pega el link en el campo.
- Se mantiene guardado y apertura en navegador desde COP/DOT.

## 6. Resultado / evidencia
- Fallback de teclado aplicado en dialogo.
- Validacion estatica sin errores.

## 7. Proximo paso
Validar en web pegado por teclado y guardado de URL vinculada.
