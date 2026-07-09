# IMPL_16_balance_tipo_liberacion_y_donas_verticales

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir cuantificacion de "Tipo de Liberacion" en Balance y ajustar visualizacion de seccion de tipo de propiedad para disposicion vertical con donas mas grandes.

## 2. Diagnostico / contexto actual
- La grafica de tipo de liberacion clasificaba con base en `copFirmado` y mezclaba "Sin liberacion" con "Sin tipo", produciendo conteos engañosos.
- La seccion de propiedad se percibia horizontal y con donas pequenas.

## 3. Fases

### Fase 1 - Correccion de logica de tipo de liberacion
Descripcion: Se implemento resolucion de tipo priorizando campo de Gestion (`tipoLiberacion`) y fallback controlado.
Archivos afectados: lib/features/reportes/presentation/balance_screen.dart
Codigo clave:
- `_resolveTipoLiberacion(Predio predio)`
- uso en agregacion `porTipoLiberacion`
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 2 - Separacion clara de "Sin tipo" y "Sin liberacion"
Descripcion: Se evito sumar automaticamente "sin COP" dentro de "Sin tipo".
Archivos afectados: lib/features/reportes/presentation/balance_screen.dart
Codigo clave:
- `return 'Sin liberacion'` para no liberados
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Ajuste visual de tipo de propiedad
Descripcion: Se reforzo estructura vertical y se ampliaron donas con mayor diametro, radios y tipografia.
Archivos afectados: lib/features/reportes/presentation/balance_screen.dart
Codigo clave:
- `Column` para tarjetas de propiedad
- `_buildDonaSeparada` ancho 112, grafica 88x88, radio 22
Tiempo estimado: 20 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Medio |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 20 min | Bajo |
| **Total** | **50 min** | **Medio-Bajo** |

## 5. Criterio de exito
- Tipo de liberacion muestra COP/AOP/DOT desde datos de Gestion cuando existen.
- No se concentra todo en "Sin tipo" incorrectamente.
- Tarjetas "Propiedad Privada" y "Propiedad social/Dominio pleno" se muestran en disposicion vertical.
- Donas de esas tarjetas son visualmente mas grandes.

## 6. Resultado / evidencia
- Cambios aplicados en `balance_screen.dart`.
- `flutter analyze lib/features/reportes/presentation/balance_screen.dart` sin errores.
- Hot restart y recarga con `v=20260702-2000`.

## 7. Proximo paso
Validacion funcional en UI de Balance con datos reales de Gestion para confirmar distribucion COP/AOP/DOT y nuevo tamano de donas.
