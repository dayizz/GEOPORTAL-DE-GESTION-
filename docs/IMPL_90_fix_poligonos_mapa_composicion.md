# Corrección de polígonos en mapas de Composiciones

**Estado:** Implementado en rama de trabajo
**Fecha:** 2026-08-20
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Mostrar correctamente la capa de predios y polígonos cuando un elemento de mapa se coloca dentro de una composición.

## Diagnóstico / contexto actual

El lienzo pasaba a cada elemento de mapa únicamente los predios filtrados por el proyecto de la composición. Los mapas guardan además `mapaProyecto`, pero ese campo no se utilizaba al construir `MapaViewportWidget`; por ello una vista asociada a otro proyecto podía renderizar el mapa base sin sus polígonos.

## Fases

### Fase 1: Resolver predios por elemento

- **Descripción:** Pasar todos los predios disponibles al lienzo y filtrar cada mapa por `mapaProyecto`.
- **Archivos afectados:** `lib/features/composiciones/presentation/composicion_editor_screen.dart`.
- **Código clave:** `_prediosParaElementoMapa` y `_predioPerteneceAProyecto`.
- **Tiempo estimado:** 5 minutos.
- **Riesgo:** Medio; las gráficas mantienen el filtro del proyecto de la composición.

### Fase 2: Validación y actualización local

- **Descripción:** Ejecutar análisis estático y aplicar hot reload al servidor local.
- **Archivos afectados:** Sin archivos adicionales de ejecución.
- **Código clave:** `flutter analyze lib/features/composiciones`.
- **Tiempo estimado:** 2 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Actividad | Resultado | Riesgo |
|---|---|---|
| Resolver proyecto del mapa | Implementado | Medio |
| Render de polígonos | Usa la lista del proyecto del elemento | Medio |
| Gráficas | Conservan comportamiento anterior | Bajo |
| Validación | Sin errores de análisis | Bajo |

## Criterio de éxito

- Un elemento de mapa renderiza predios del proyecto guardado en `mapaProyecto`.
- `PolygonLayer` recibe geometrías cuando existen en los predios.
- Las gráficas no cambian su fuente de datos.
- La composición continúa compilando sin errores.

## Resultado / evidencia

- `flutter analyze lib/features/composiciones`: sin errores; queda un aviso informativo preexistente.
- Hot reload aplicado correctamente en la página local.

## Próximo paso

Recargar la composición local y verificar una vista con un proyecto que tenga geometrías importadas.