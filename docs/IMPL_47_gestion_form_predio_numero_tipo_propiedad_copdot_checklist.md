# IMPL_47 - Gestion Form Predio: numero editable, tipo propiedad ampliado, COP/DOT solo URL, sin checklist COP firmado

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Aplicar ajustes solicitados en el formulario de predio dentro de Gestion:
- Numero en Identificacion LDDV como campo editable (sin dropdown)
- Ampliar opciones de Tipo de Propiedad
- Quitar opcion de subir PDF en COP/DOT y mantener gestion por URL desde tabla
- Quitar checkbox de COP firmado

## 2. Diagnostico / contexto actual
El formulario mantenia controles cerrados para numero y flujo mixto de COP/DOT (subida local + URL), ademas de un checklist de COP firmado que ya no corresponde al flujo actual.

## 3. Fases

### Fase 1 - Identificacion LDDV
Descripcion: Se reemplazo el dropdown de Numero por input numerico editable.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- `DropdownButtonFormField<String>` -> `TextFormField` en Numero
- Parsing de tramo actualizado para aceptar cualquier numero importado (`\\d+`)
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Tipo de Propiedad
Descripcion: Se agregaron opciones adicionales al selector.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Opciones agregadas: DESCONOCIDO, FEDERAL, GUBERNAMENTAL, ESTATAL, MUNICIPAL
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

### Fase 3 - COP/DOT solo URL desde Gestion
Descripcion: Se elimino la carga local de PDF en formulario y se dejo solo visualizacion/apertura cuando existe URL vinculada.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Eliminacion de `file_picker` y metodos de upload
- Mensaje informativo: URL administrada desde tabla Gestion
- Boton `Abrir PDF` solo si existe URL
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 4 - Remocion de checklist COP firmado
Descripcion: Se elimino el checkbox COP firmado de Avance DDV.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Eliminacion de `CheckboxListTile` de COP firmado
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Fase 4 | 5 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de exito
- Numero ya no usa dropdown y permite captura directa.
- Tipo de Propiedad incluye las 5 nuevas opciones.
- COP/DOT en formulario no permite subir PDF.
- Checklist COP firmado ya no aparece.

## 6. Resultado / evidencia
- Cambios aplicados en UI de formulario de predio en Gestion.
- Validacion estatica sin errores en el archivo modificado.

## 7. Proximo paso
Validar flujo completo en web: editar predio existente, confirmar persistencia del tramo con numero libre y apertura de URL COP/DOT cuando ya existe.
