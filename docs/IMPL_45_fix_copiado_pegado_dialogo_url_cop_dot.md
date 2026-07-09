# IMPL_45 - Fix copiado/pegado en dialogo URL de COP/DOT

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Asegurar que en el dialogo de captura de URL (columna COP/DOT de Gestion) funcionen correctamente acciones de copiar/pegar/cortar y seleccion de texto.

## 2. Diagnostico / contexto actual
Se reporto que los atajos de teclado para copiar y pegar no se aplicaban de forma consistente en el campo de URL.

## 3. Fases

### Fase 1 - Refuerzo de interaccion del campo de texto
Descripcion: Se agrego `FocusNode`, seleccion interactiva y barra de menu contextual adaptativa para acciones de edicion sobre el campo URL.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `_requestPdfUrl(...)`
- `focusNode`
- `enableInteractiveSelection: true`
- `contextMenuBuilder: AdaptiveTextSelectionToolbar.editableText(...)`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- El campo de URL permite copiar/pegar/cortar desde teclado y menu contextual.
- La captura de URL mantiene validacion y guardado sin cambios funcionales.

## 6. Resultado / evidencia
- Ajuste aplicado en la pantalla de Gestion sin errores de compilacion.
- Hot restart ejecutado para reflejar cambios en runtime.

## 7. Proximo paso
Validar manualmente en el dialogo de URL de COP/DOT los atajos de copiado/pegado segun plataforma (Ctrl en Windows/Linux, Cmd en macOS).
