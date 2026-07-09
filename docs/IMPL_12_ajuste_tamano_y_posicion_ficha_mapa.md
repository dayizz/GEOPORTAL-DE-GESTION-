# IMPL_12_ajuste_tamano_y_posicion_ficha_mapa

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Reducir el tamaño de la ficha del predio seleccionado y ubicarla en la parte derecha del mapa.

## 2. Diagnostico / contexto actual
La ficha se mostraba en la parte inferior con ancho amplio (left/right), ocupando demasiado espacio visual.

## 3. Fases

### Fase 1 - Reubicacion de la ficha
Descripcion: Se movio el `Positioned` de la ficha al borde derecho del mapa.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `Positioned(bottom: 24, right: 16, ...)`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Reduccion de ancho
Descripcion: Se establecio un ancho mas compacto y responsivo para la ficha.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `cardWidth = screenWidth < 420 ? screenWidth - 32 : 340.0`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Compactacion interna
Descripcion: Se redujeron paddings y espacios internos para una visualizacion mas ligera.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `padding: EdgeInsets.all(12)`
- ajustes de `SizedBox` y tipografia de clave
Tiempo estimado: 15 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 15 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de exito
- La ficha aparece en el lado derecho del mapa.
- La ficha ocupa menos espacio horizontal.
- La ficha conserva los datos solicitados previamente.

## 6. Resultado / evidencia
- Cambio implementado y validado con `flutter analyze` en el archivo objetivo.
- No se introdujeron errores nuevos de compilacion en la pantalla.

## 7. Proximo paso
Verificacion visual en entorno web:
1. Abrir mapa.
2. Seleccionar un poligono.
3. Confirmar posicion a la derecha y tamano reducido de la ficha.
