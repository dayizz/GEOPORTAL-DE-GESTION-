# IMPL_49 - Gestion: lapiz directo a Editar Predio

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Eliminar la vista intermedia "Detalle de Predio - Gestion" al editar desde Gestion, de forma que el icono de lapiz en la tabla abra directamente "Editar Predio".

## 2. Diagnostico / contexto actual
El flujo actual desde Gestion era:
- Tabla Gestion -> lapiz -> Detalle de Predio - Gestion -> segundo lapiz -> Editar Predio

Este paso intermedio generaba un clic extra innecesario.

## 3. Fases

### Fase 1 - Redireccion directa desde la tabla
Descripcion: Se actualizo la accion del icono de lapiz para navegar directamente a la ruta de edicion.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `context.push('/tabla/predio/${p.id}')` -> `context.push('/predios/${p.id}/editar')`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

### Fase 2 - Retiro de ruta intermedia
Descripcion: Se elimino la ruta `'/tabla/predio/:id'` del router para quitar la vista intermedia del flujo de Gestion.
Archivos afectados:
- lib/core/router/app_router.dart
Codigo clave:
- Eliminacion de import de `GestionPredioDetailScreen`
- Eliminacion de subruta `predio/:id` bajo `/tabla`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- Al hacer clic en el lapiz desde Gestion se abre directamente "Editar Predio".
- La ruta intermedia de detalle de gestion ya no forma parte del flujo.

## 6. Resultado / evidencia
- Navegacion actualizada.
- Router simplificado.
- Validacion estatica sin errores en archivos modificados.

## 7. Proximo paso
Validar en interfaz que el lapiz en cada fila de Gestion abre directamente la pantalla de edicion del predio correcto.
