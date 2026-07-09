# IMPL_51 - Tipo de liberacion con dropdown (COP, DOT, AOP)

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Cambiar el campo `Tipo de liberacion` en `Editar Predio` para usar un dropdown con opciones fijas:
- COP
- DOT
- AOP

## 2. Diagnostico / contexto actual
El campo se capturaba como texto libre, lo cual permitia valores inconsistentes.

## 3. Fases

### Fase 1 - Reemplazo de control de UI
Descripcion: Se sustituyo `TextFormField` por `DropdownButtonFormField<String>`.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Lista de opciones `_tipoLiberacionOpciones = ['COP', 'DOT', 'AOP']`
- Integracion de `onChanged` para actualizar `_tipoLiberacionCtrl`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Total | 10 min | Bajo |

## 5. Criterio de exito
- Tipo de liberacion se selecciona solo desde dropdown con COP/DOT/AOP.
- El valor continua guardando en `tipo_liberacion`.

## 6. Resultado / evidencia
- Campo actualizado en formulario de edicion.
- Validacion estatica sin errores.

## 7. Proximo paso
Probar en UI la seleccion de cada opcion y confirmar persistencia en la tabla de Gestion.
