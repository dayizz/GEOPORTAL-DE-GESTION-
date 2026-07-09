# IMPL_59 - Vincular URL: sin boton portapapeles y normalizacion de link

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Asegurar que en Gestion se pueda vincular un link y abrirlo posteriormente en navegador, eliminando el boton `Pegar desde portapapeles`.

## 2. Diagnostico / contexto actual
El flujo tenia capas extra de manejo de portapapeles que podian interferir con el pegado nativo en web y ademas se solicito retirar el boton de pegado.

## 3. Fases

### Fase 1 - Simplificacion del dialogo URL
Descripcion: Se elimino toda la logica personalizada de portapapeles/eventos de pegado y el boton `Pegar desde portapapeles`.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Remocion de listener `onPaste` y helpers de clipboard
- Dialogo con `TextFormField` nativo
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Normalizacion de URL para facilitar guardado
Descripcion: Se agrego normalizacion del input para aceptar links sin esquema y convertirlos automaticamente a `https://`.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Nuevo helper `_normalizeUrl(...)`
- Validacion y guardado usan valor normalizado
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
- El dialogo permite capturar/pegar URL nativamente sin boton extra.
- URL sin esquema se guarda como `https://...`.
- Al existir URL vinculada, puede abrirse en navegador.

## 6. Resultado / evidencia
- Dialogo de vinculo simplificado.
- Flujo de validacion y guardado robustecido.
- Validacion estatica sin errores en archivo modificado.

## 7. Proximo paso
Probar en web: vincular URL (con y sin `https://`) y confirmar apertura del archivo al volver a tocar el icono COP/DOT.
