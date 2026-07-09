# IMPL_58 - Fix evento paste web en vincular URL (Gestion)

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Forzar pegado funcional de URL en el dialogo `Vincular URL de archivo` en web cuando el atajo nativo no responde.

## 2. Diagnostico / contexto actual
En algunos entornos Flutter Web, el atajo de pegado no se reflejaba en el campo del dialogo aunque el usuario presionara Cmd+V/Ctrl+V.

## 3. Fases

### Fase 1 - Escucha de evento paste del navegador (web)
Descripcion: Se agrego listener `document.onPaste` activo durante el dialogo. Si el campo URL tiene foco, inserta el texto del portapapeles y previene comportamiento duplicado.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `StreamSubscription<html.Event>? pasteSub`
- `html.document.onPaste.listen(...)`
- Cancelacion segura con `await pasteSub?.cancel()`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Insercion centralizada de texto
Descripcion: Se creo helper para insertar texto respetando cursor/seleccion, reutilizado por pegado por boton y evento web.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `_insertTextInController(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de exito
- En web, al pegar (Cmd+V/Ctrl+V) con foco en URL, el texto se inserta en el campo.
- Se mantiene guardado y validacion de URL.

## 6. Resultado / evidencia
- Integracion de evento paste web aplicada en dialogo de Gestion.
- Validacion estatica sin errores.

## 7. Proximo paso
Validar en interfaz web real el flujo de pegado y guardado en `Vincular URL de archivo`.
