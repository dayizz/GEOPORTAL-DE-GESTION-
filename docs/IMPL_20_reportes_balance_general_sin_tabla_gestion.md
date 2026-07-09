# IMPL_20_reportes_balance_general_sin_tabla_gestion

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Ajustar el PDF de reportes para eliminar la tabla de Gestion, renombrar el resumen principal y simplificar el bloque de balance.

## 2. Diagnostico / contexto actual
El PDF incluia una pagina extra con la tabla de Gestion y un resumen con textos y campos que ya no corresponden al formato solicitado.

## 3. Fases

### Fase 1 - Simplificar el resumen principal
Descripcion: Se reemplazo el titulo del resumen por "Balance general del proyecto" y se elimino la linea de superficie total.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `Balance general del proyecto`
- eliminacion de `Superficie total`
Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 2 - Normalizar el bloque de estatus
Descripcion: Se removio la etiqueta "Estatus COP" y se dejo solo "Estatus" dentro del balance general.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- `Estatus:`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Eliminar la tabla de Gestion del PDF
Descripcion: Se retiro la pagina de detalle con la tabla de Gestion y se dejo solo una pagina final de cierre.
Archivos afectados:
- lib/features/reportes/presentation/generar_reporte_screen.dart
Codigo clave:
- cierre con `ATENTAMENTE`
- sin pagina de tabla
Tiempo estimado: 20 min
Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 20 min | Medio |
| **Total** | **45 min** | **Medio** |

## 5. Criterio de exito
- El PDF ya no incluye la tabla de Gestion.
- El encabezado del resumen muestra "Balance general del proyecto".
- No se muestra "Superficie total".
- El bloque de estatus aparece solo como "Estatus".

## 6. Resultado / evidencia
- Se valido `lib/features/reportes/presentation/generar_reporte_screen.dart` con `flutter analyze`.
- Se confirmo que el bloque de tabla ya no existe en el generador.

## 7. Proximo paso
Revisar el PDF generado en el navegador para confirmar la composicion visual final y ajustar espaciados si fuera necesario.
