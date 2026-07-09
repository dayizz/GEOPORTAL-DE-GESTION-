# IMPL_46 - Gestion Editar Predio: remover georeferencia, oficio y km lineales

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Ajustar el formulario de "Editar predio" en Gestion para:
- eliminar la seccion Georeferencia (Latitud y Longitud),
- eliminar el campo Oficio en la seccion Documentos,
- eliminar el campo KM lineales.

## 2. Diagnostico / contexto actual
El formulario de edicion mostraba campos no requeridos para el flujo actual de Gestion.
Adicionalmente, al retirarlos se debia evitar sobreescribir datos ya existentes en BD/local.

## 3. Fases

### Fase 1 - Remover campos en UI
Descripcion: Se eliminaron del formulario los controles visuales de Georeferencia, Oficio y KM lineales.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Eliminacion de seccion `Georeferencia`
- Eliminacion de `TextFormField` de `Oficio`
- Eliminacion de `TextFormField` de `km Lineales`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 2 - Ajuste de controladores y carga inicial
Descripcion: Se eliminaron controladores asociados y sus asignaciones en carga/dispose.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Eliminacion de `_kmLinealesCtrl`, `_oficioCtrl`, `_latCtrl`, `_lngCtrl`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 3 - Evitar sobreescritura de datos retirados
Descripcion: Se retiraron esos campos del payload de guardado para no modificar valores historicos existentes.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Eliminacion de asignaciones `kmLineales`, `oficio`, `latitud`, `longitud` en `copyWith` y `data`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de exito
- El formulario de "Editar predio" ya no muestra Georeferencia, Oficio ni KM lineales.
- Guardar cambios no altera esos campos en registros existentes.

## 6. Resultado / evidencia
- Cambios aplicados en la pantalla de formulario de predio.
- Validacion estatica del archivo sin errores.

## 7. Proximo paso
Validar en UI editando un predio existente para confirmar que los campos removidos no aparecen y que el guardado opera correctamente.
