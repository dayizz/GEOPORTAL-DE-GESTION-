# Eliminar Vistas de mapa

**Estado:** Implementado en rama de trabajo
**Fecha:** 2026-08-20
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Eliminar la función “Vistas de mapa” del mapa y del editor de composiciones, conservando el mapa, sus capas, filtros, capturas y herramientas de edición restantes.

## Diagnóstico / contexto actual

La función estaba integrada en el mapa mediante un botón, un panel de vistas guardadas, selección de área, diálogos de guardar y acciones de actualización/eliminación en Firestore. En Composiciones existía un panel lateral que cargaba vistas guardadas para insertarlas como elementos de mapa.

## Fases

### Fase 1: Retiro de la interfaz

- **Descripción:** Quitar el botón y panel de Vistas de mapa del mapa, así como el panel equivalente del editor de composiciones.
- **Archivos afectados:** `mapa_screen.dart`, `composicion_editor_screen.dart`.
- **Código clave:** Eliminación de `_buildVistasMapaButton`, el panel lateral y `_insertarVistaMapa`.
- **Tiempo estimado:** 5 minutos.
- **Riesgo:** Bajo.

### Fase 2: Retiro de lógica y archivos auxiliares

- **Descripción:** Eliminar selección de área, persistencia Firestore, proveedor, repositorio, modelo, diálogo y painter que solo servían a la función retirada.
- **Archivos afectados:** `mapa_screen.dart` y auxiliares de `mapa` y `composiciones`.
- **Código clave:** Eliminación de `_confirmarVistaSeleccionada`, `_eliminarVista` y estados asociados.
- **Tiempo estimado:** 5 minutos.
- **Riesgo:** Medio; se verificaron referencias antes y después.

## Resumen de esfuerzo

| Actividad | Resultado | Riesgo |
|---|---|---|
| Retiro del mapa | Botón, panel y overlay eliminados | Bajo |
| Retiro de composiciones | Panel de vistas eliminado | Bajo |
| Limpieza de dependencias | 6 archivos auxiliares eliminados | Medio |
| Validación | Sin errores de compilación; búsqueda de referencias limpia | Bajo |

## Criterio de éxito

- “Vistas de mapa” ya no aparece en Mapa ni Composiciones.
- No quedan imports, proveedores o widgets huérfanos en `lib/`.
- Mapa y composiciones pasan el análisis estático sin errores.
- Las funciones restantes del mapa conservan su flujo actual.

## Resultado / evidencia

- Búsqueda de referencias en `lib/`: sin coincidencias.
- `flutter analyze lib/features/mapa lib/features/composiciones`: sin errores; quedan avisos informativos preexistentes.
- `git diff --check`: correcto.

## Próximo paso

Abrir la página local y comprobar visualmente que el botón ya no aparece en Mapa y que el editor de Composiciones conserva únicamente sus propiedades y herramientas disponibles.