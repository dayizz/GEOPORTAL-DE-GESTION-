# IMPL_67 - Gestion filtros dinamicos y color de texto modal

- Estado: Implementado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo

Corregir la experiencia de filtrado en la vista de Gestion para que:
- Las opciones de filtros se detecten dinamicamente segun los datos realmente registrados en el proyecto seleccionado.
- El texto del panel/modal de filtros sea legible y no se pierda visualmente por falta de contraste.

## 2. Diagnostico / contexto actual

Se detecto que el panel de filtros usaba listas fijas para T/F/S y Tipo de Propiedad. Estas listas no siempre coinciden con los valores reales capturados por proyecto, generando opciones irrelevantes o faltantes.

Tambien se detecto problema de contraste en el modal de filtros, donde el texto podia verse blanco sobre fondo claro, reduciendo legibilidad.

## 3. Fases

### Fase 1 - Deteccion dinamica de opciones de filtro

- Descripcion:
  - Se agregaron funciones para construir opciones de T/F/S y Tipo de Propiedad con base en los predios del proyecto activo.
  - Se incorporo ordenamiento alfanumerico para codigos tipo T1, T2, ..., T10.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - _opcionesTramoProyecto(List<Predio> predios)
  - _opcionesTipoProyecto(List<Predio> predios)
  - _compararCodigoAlfanumerico(String a, String b)
  - _showFiltros(BuildContext context, List<Predio> allPredios)
- Tiempo estimado: 45 min
- Riesgo: Bajo

### Fase 2 - Ajuste de contraste y legibilidad en modal de filtros

- Descripcion:
  - Se fijo el fondo del BottomSheet a AppColors.surface.
  - Se aplicaron estilos explicitos para texto, titulos, labels y controles (IconButton, TextButton, FilterChip) con AppColors.textPrimary/AppColors.textSecondary.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - showModalBottomSheet(..., backgroundColor: AppColors.surface, ...)
  - DefaultTextStyle.merge(style: TextStyle(color: AppColors.textPrimary), ...)
- Tiempo estimado: 30 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Filtros dinamicos | 45 min | Bajo |
| Fase 2 - Contraste visual | 30 min | Bajo |
| Total | 75 min | Bajo |

## 5. Criterio de exito

- El filtro T/F/S solo muestra valores realmente presentes para el proyecto seleccionado.
- El filtro Tipo de Propiedad solo muestra valores presentes en ese proyecto.
- El texto del modal de filtros se ve correctamente (sin texto blanco sobre fondo claro).
- La pantalla compila sin errores.

## 6. Resultado / evidencia

- Implementado en la vista de Gestion.
- Validado con analisis de errores del archivo modificado: sin errores en tabla_screen.dart.

## 7. Proximo paso

Realizar validacion funcional manual por proyecto (TQI, TSNL, TAP, TQM) para confirmar que las opciones de filtros reflejan exactamente la data cargada en cada uno y verificar contraste visual en desktop y web.
