# Herramientas individuales de Norte, Escala y Simbología

**Estado:** Implementado en rama de trabajo
**Fecha:** 2026-08-20
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Separar las herramientas Norte, Escala gráfica y Simbología en controles individuales dentro del editor de Composiciones.

## Diagnóstico / contexto actual

Las tres funciones ya eran tipos de elemento independientes en el modelo, pero la barra lateral las agrupaba en un único botón desplegable. Esto obligaba a abrir un menú compartido para acceder a cualquiera de ellas.

## Fases

### Fase 1: Separación de controles

- **Descripción:** Crear un botón independiente para Norte y otro para Escala gráfica.
- **Archivos afectados:** `lib/features/composiciones/presentation/composicion_editor_screen.dart`.
- **Código clave:** `_herramientaNorteBoton` y `_herramientaEscalaBoton`.
- **Tiempo estimado:** 3 minutos.
- **Riesgo:** Bajo.

### Fase 2: Menú exclusivo de simbología

- **Descripción:** Mantener las variantes Estatus, Rango de estatus y Tipo de propiedad dentro de un menú propio de Simbología.
- **Archivos afectados:** `lib/features/composiciones/presentation/composicion_editor_screen.dart`.
- **Código clave:** `_herramientaSimbologiaBoton`.
- **Tiempo estimado:** 2 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Actividad | Resultado | Riesgo |
|---|---|---|
| Norte | Acción directa independiente | Bajo |
| Escala gráfica | Acción directa con asociación al primer mapa | Bajo |
| Simbología | Menú individual con tres variantes | Bajo |
| Validación | Sin errores de análisis | Bajo |

## Criterio de éxito

- Norte, Escala y Simbología aparecen como controles separados.
- Cada control crea el tipo de elemento correspondiente.
- Las tres variantes de Simbología continúan disponibles.
- El editor de Composiciones no presenta errores de compilación.

## Resultado / evidencia

- `flutter analyze lib/features/composiciones`: sin errores; queda un aviso informativo preexistente.
- El botón agrupado “Norte / escala / simbología” fue eliminado.
- La asociación automática de Escala con el primer mapa de la hoja se conserva.

## Próximo paso

Revisar visualmente la barra lateral en la página local y probar la creación de los tres tipos de elemento.