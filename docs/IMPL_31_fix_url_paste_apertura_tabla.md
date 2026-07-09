# Fix URL de archivo en tabla

**Estado:** Hecho
**Fecha:** 2026-07-09
**Rama:** main

## Objetivo
Corregir el flujo de vinculación y apertura de URL de archivo en la tabla de predios para que el usuario pueda pegar enlaces sin fricción y abrir la página asociada de forma consistente.

## Diagnóstico / contexto actual
El cuadro de diálogo de URL en la tabla dependía de un wrapper de teclado manual alrededor del campo de texto. Ese enfoque podía interferir con el pegado estándar del sistema y hacía que la validación de guardado y la apertura usaran rutas distintas.

Además, la apertura del enlace no normalizaba la URL antes de lanzar el navegador, por lo que enlaces sin esquema o con formato incompleto podían guardarse pero no abrirse correctamente.

## Fases
### Fase 1: Normalizar apertura de URL
- Descripción: Unificar la validación y la conversión de texto a `Uri` antes de abrir el enlace.
- Archivos afectados: [lib/features/tabla/presentation/tabla_screen.dart](../lib/features/tabla/presentation/tabla_screen.dart)
- Código clave: helper `_normalizedHttpUrl()` y uso de `LaunchMode.externalApplication` en `_openPdfUrl()`.
- Tiempo estimado: 20 minutos
- Riesgo: Bajo

### Fase 2: Simplificar el diálogo de captura
- Descripción: Eliminar el wrapper manual de `Focus` con captura de `Ctrl/Cmd+V` y dejar que el `TextFormField` use el pegado nativo del sistema.
- Archivos afectados: [lib/features/tabla/presentation/tabla_screen.dart](../lib/features/tabla/presentation/tabla_screen.dart)
- Código clave: `TextFormField` directo con `enableInteractiveSelection: true` y botón explícito de pegar.
- Tiempo estimado: 20 minutos
- Riesgo: Bajo

### Fase 3: Validación puntual
- Descripción: Ejecutar verificación de errores del archivo modificado.
- Archivos afectados: [lib/features/tabla/presentation/tabla_screen.dart](../lib/features/tabla/presentation/tabla_screen.dart)
- Código clave: chequeo de errores Dart del archivo.
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo | Resultado |
|---|---:|---:|---|
| Normalizar apertura de URL | Bajo | Bajo | Implementado |
| Simplificar captura de pegado | Bajo | Bajo | Implementado |
| Validación puntual | Bajo | Bajo | Sin errores |

## Criterio de éxito
- El usuario puede pegar el enlace en el diálogo sin bloqueo artificial.
- La URL guardada se normaliza antes de abrirse.
- La acción de abrir lleva a la página correcta cuando la URL es válida.

## Resultado / evidencia
- Se corrigió la lógica en [lib/features/tabla/presentation/tabla_screen.dart](../lib/features/tabla/presentation/tabla_screen.dart).
- Validación del archivo: sin errores detectados por el análisis de Dart.

## Próximo paso
Probar manualmente en la interfaz de tabla: pegar una URL con y sin esquema, guardar y abrir el enlace desde el indicador de archivo vinculado.
