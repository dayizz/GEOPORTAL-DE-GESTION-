# IMPL_56 - Fix pegado nativo en dialogo URL de Gestion

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Restaurar el pegado nativo (`Cmd+V` / `Ctrl+V`) en el dialogo `Vincular URL de archivo` de Gestion.

## 2. Diagnostico / contexto actual
El campo URL tenia personalizaciones del editor de texto que podian interferir en el comportamiento de pegado de Flutter Web en ciertos navegadores.

## 3. Fases

### Fase 1 - Campo URL con comportamiento nativo
Descripcion: Se cambio el control a `TextFormField` nativo y se eliminaron personalizaciones de menu contextual.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `TextField` -> `TextFormField`
- Eliminacion de `contextMenuBuilder`
- Se mantiene `enableInteractiveSelection` y se agrega helper para atajo de teclado
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
- El campo URL acepta pegado con Cmd+V/Ctrl+V en navegador.
- Se conserva validacion de URL y guardado.

## 6. Resultado / evidencia
- Ajuste aplicado en dialogo de Gestion.
- Validacion estatica sin errores.

## 7. Proximo paso
Validar en web el pegado en el campo URL con atajo de teclado y guardar.
