# IMPL_68 - Gestion filtro Tipo de liberacion en lugar de COP

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo

Reemplazar el filtro de COP en la pantalla de Gestion por un filtro de Tipo de liberacion para alinear la interfaz con la informacion real operativa de los predios.

## 2. Diagnostico / contexto actual

El modal de filtros en Gestion usaba un bloque de filtro llamado C.O.P. con opciones binarias (Con COP / Sin COP). Esto no permitia filtrar por el valor real de `tipo_liberacion` (por ejemplo COP, DOT, AOP o sin valor), que es el campo que se muestra en la tabla y se usa en analisis funcionales.

## 3. Fases

### Fase 1 - Sustitucion de estado y logica de filtro

- Descripcion:
  - Se sustituyo el estado interno de filtro `_filtroCop` por `_filtroTipoLiberacion`.
  - Se actualizo la memoizacion para considerar `_lastTipoLiberacion`.
  - Se cambio la condicion de filtrado para comparar contra `predio.tipoLiberacion` normalizado.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - `_normalizarTipoLiberacion(String? value)`
  - `_applyFilters(List<Predio> all)`
- Tiempo estimado: 30 min
- Riesgo: Bajo

### Fase 2 - Opciones dinamicas y UI de filtros

- Descripcion:
  - Se agrego deteccion dinamica de opciones de tipo de liberacion por proyecto activo.
  - Se reemplazo el bloque visual de C.O.P. por Tipo de liberacion en el modal.
  - Se actualizaron chips de filtros activos para reflejar Tipo de liberacion.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - `_opcionesTipoLiberacionProyecto(List<Predio> predios)`
  - `_showFiltros(BuildContext context, List<Predio> allPredios)`
- Tiempo estimado: 35 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Logica de filtro | 30 min | Bajo |
| Fase 2 - UI y opciones dinamicas | 35 min | Bajo |
| Total | 65 min | Bajo |

## 5. Criterio de exito

- El modal ya no muestra C.O.P. con opciones binarias.
- El modal muestra Tipo de liberacion con opciones detectadas desde los predios del proyecto seleccionado.
- Al aplicar el filtro, la tabla queda filtrada por `tipo_liberacion`.
- Los chips activos reflejan el nuevo filtro de Tipo de liberacion.
- El archivo modificado compila sin errores.

## 6. Resultado / evidencia

- Cambio aplicado en la pantalla de Gestion.
- Validacion de errores en `tabla_screen.dart`: sin errores.

## 7. Proximo paso

Validar manualmente en UI con proyectos que incluyan combinaciones COP, DOT, AOP y SIN TIPO para confirmar que las opciones visibles en el modal coinciden con los datos de cada proyecto.
