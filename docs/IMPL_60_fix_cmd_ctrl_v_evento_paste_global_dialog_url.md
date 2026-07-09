# IMPL_60 - Fix Cmd+V/Ctrl+V con evento paste global en dialogo URL

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Corregir de forma robusta el pegado de URL con `Cmd+V` / `Ctrl+V` en el dialogo `Vincular URL de archivo` de Gestion.

## 2. Diagnostico / contexto actual
El pegado nativo en Flutter web puede fallar en algunos contextos de dialogo. Se requiere compatibilidad real de teclado sin botones extra.

## 3. Fases

### Fase 1 - Listener global de evento paste mientras el dialogo esta abierto
Descripcion: Se agrego escucha de `document.onPaste` en web, activa solo durante la vida del dialogo.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `StreamSubscription<html.Event>? pasteSub`
- `html.document.onPaste.listen(...)`
- Insercion en controlador solo si el input URL tiene foco (`focusNode.hasFocus`)
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Limpieza de recursos
Descripcion: Se cancela el listener y se libera `FocusNode` al cerrar el dialogo.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `await pasteSub?.cancel()`
- `focusNode.dispose()`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito
- Con foco en el input URL, `Cmd+V` y `Ctrl+V` insertan texto del portapapeles.
- No requiere boton de pegado.
- El valor guardado sigue abriendose en navegador al tocar COP/DOT.

## 6. Resultado / evidencia
- Integracion de evento paste global aplicada.
- Validacion estatica sin errores.

## 7. Proximo paso
Validar en web el flujo: pegar URL con teclado, guardar y abrir desde COP/DOT.
