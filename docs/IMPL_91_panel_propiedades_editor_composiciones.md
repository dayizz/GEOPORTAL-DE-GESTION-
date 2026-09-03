# Panel de propiedades en editor de composiciones

**Estado:** Implementado
**Fecha:** 2026-09-01
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Renombrar el panel lateral derecho como “Propiedades” y centralizar toda la edición de los elementos agregados en esa ventana, evitando la edición en línea sobre el lienzo para texto y mapa.

## Diagnóstico / contexto actual

El editor de composiciones tenía un panel lateral derecho sin título explícito y varios ajustes de texto/mapa se realizaban dentro del propio elemento del lienzo (edición inline), lo que fragmentaba la experiencia de edición y hacía que el usuario no supiera dónde estaban los controles reales.

## Fases

### Fase 1: Título y estructura del panel derecho

- **Descripción:** Definir el encabezado del panel como “Propiedades” y mantenerlo siempre visible en el lateral derecho.
- **Archivos afectados:** `lib/features/composiciones/presentation/composicion_editor_screen.dart`
- **Código clave:** `_buildPanelLateralDerecho()`
- **Tiempo estimado:** 10 minutos.
- **Riesgo:** Bajo.

### Fase 2: Mover edición de texto al panel

- **Descripción:** Añadir el contenido y los estilos del texto dentro del panel de propiedades, con entrada directa desde el sidebar.
- **Archivos afectados:** `lib/features/composiciones/presentation/widgets/panel_propiedades_texto.dart`, `lib/features/composiciones/presentation/composicion_editor_screen.dart`
- **Código clave:** `PanelPropiedadesTexto` y la callback `onTextoContenidoChanged`
- **Tiempo estimado:** 15 minutos.
- **Riesgo:** Medio.

### Fase 3: Mover edición de mapa al panel

- **Descripción:** Exponer latitud, longitud y zoom en el panel lateral y dejar que el lienzo solo sirva para selección y arrastre visual.
- **Archivos afectados:** `lib/features/composiciones/presentation/widgets/panel_propiedades_mapa.dart`, `lib/features/composiciones/presentation/composicion_editor_screen.dart`
- **Código clave:** `PanelPropiedadesMapa` con `onLatChanged`, `onLngChanged`, `onZoomChanged`
- **Tiempo estimado:** 15 minutos.
- **Riesgo:** Medio.

### Fase 4: Eliminar edición inline en el lienzo

- **Descripción:** Desactivar el doble-tap para entrar en edición sobre el elemento y evitar que la edición de texto o mapa se haga dentro del elemento visual.
- **Archivos afectados:** `lib/features/composiciones/presentation/widgets/elemento_box.dart`
- **Código clave:** eliminación del `onDoubleTap` de edición y la lógica de `TextField` inline
- **Tiempo estimado:** 10 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Actividad | Resultado | Riesgo |
|---|---|---|
| Panel derecho | Cabecera “Propiedades” | Bajo |
| Texto | Se edita desde la ventana lateral | Medio |
| Mapa | Coordenadas y zoom desde la ventana lateral | Medio |
| Lienzo | Sin edición intensa inline | Bajo |
| Validación | Análisis sin errores | Bajo |

## Criterio de éxito

- El panel derecho se visualiza como “Propiedades”.
- La edición del texto agregado se hace en ese panel.
- La configuración del mapa agregado se hace en ese panel.
- La edición inline sobre el lienzo queda eliminada para los elementos que antes lo usaban.
- El módulo de composiciones compila sin issues.

## Resultado / evidencia

- `flutter analyze lib/features/composiciones` → `No issues found!`
- La vista de propiedades cambia su encabezado en el editor.
- El texto y el mapa tienen controles directos en la ventana derecha.

## Próximo paso

Revisar visualmente la experiencia en la página local y ajustar margings, ancho o agrupación de campos si se quiere una apariencia aún más compacta.
