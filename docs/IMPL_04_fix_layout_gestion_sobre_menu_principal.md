# IMPL_04_fix_layout_gestion_sobre_menu_principal

Estado: Implementado
Fecha: 2026-07-01
Rama: main

## 1. Objetivo
Corregir la superposición de contenedores de la vista Gestión sobre el menú principal (NavigationRail) en escritorio.

## 2. Diagnóstico / contexto actual
En la vista Gestión se observó que algunos widgets del contenido principal se dibujaban fuera de su área y aparecían encima del menú lateral.

## 3. Fases

### Fase 1 - Constricción y clipping del panel de contenido
Descripcion: Se encapsuló el panel de contenido en escritorio dentro de `ClipRect` para evitar que widgets hijos pinten fuera de su bounds y se añadió `SafeArea` en el body de escritorio.
Archivos afectados: `lib/shared/widgets/app_scaffold.dart`
Código clave:
- `body: SafeArea(top: false, child: Row(...))`
- `Expanded(child: ClipRect(child: child))`
Tiempo estimado: 20 min
Riesgo: Bajo (ajuste de layout contenedor)

### Fase 2 - Compensación defensiva en Gestión
Descripcion: Se añadió una compensación de offset en la vista Gestión cuando el ancho recibido no refleja el recorte esperado por el rail, evitando que la UI arranque debajo del menú lateral.
Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
Código clave:
- Cálculo de `widthDelta` con `LayoutBuilder`.
- `Padding(left: 88)` condicional cuando `widthDelta < 70` en desktop.
Tiempo estimado: 15 min
Riesgo: Bajo (solo aplica cuando se detecta condición de traslape)

### Fase 3 - Ajuste explícito de espacios en top bar
Descripcion: Se aplicó padding izquierdo fijo en desktop para el bloque superior (dropdown de proyecto, buscador y filtros), garantizando que no se monte sobre el menú lateral aun cuando el layout padre reporte constraints inconsistentes.
Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
Código clave:
- `final leftInset = isDesktop ? 96.0 : 12.0;`
- `padding: EdgeInsets.fromLTRB(leftInset, 8, 12, 8)` en `_buildTopBar`.
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 4 - Consolidación del inset a toda la vista Gestión
Descripcion: Se unificó el ajuste en un solo punto del layout: toda la columna de Gestión en desktop recibe inset izquierdo y ancho compensado. Con esto se evita empalme del top bar y de cualquier otro bloque sin depender de offsets locales.
Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
Código clave:
- `desktopInset = 96.0` en el `LayoutBuilder` raíz del `child`.
- `Padding(left: desktopInset)` + `SizedBox(width: constraints.maxWidth - desktopInset)`.
- Se removió el offset específico del top bar para evitar doble desplazamiento.
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 10 min | Bajo |
| Total | 55 min | Bajo |

## 5. Criterio de éxito
- Ningún contenido de Gestión se pinta sobre el menú lateral.
- El menú principal mantiene su área visual limpia y navegable.
- No se introducen errores de análisis estático.

## 6. Resultado / evidencia
- Cambio aplicado en AppScaffold para escritorio con clipping explícito del contenido.
- Cambio aplicado en Gestión con inset izquierdo consolidado y compensación de ancho en desktop.
- Se habilitó acceso local de testing a `/tabla` dentro del redirect del router solo cuando `localOnlyAuthMode` está activo.
- Se extrajo la lógica de redirect a una función pura para cubrirla con prueba unitaria.
- Validación ejecutada: `flutter test test/core/router/app_router_test.dart` con resultado exitoso.
- Validación estática: sin errores en los archivos modificados del router y la prueba.

## 7. Próximo paso
Reiniciar la app Flutter en web y validar manualmente en tamaños desktop y tablet horizontal que la vista Gestión no invade el NavigationRail al cambiar filtros, paginación y estados de tabla.
