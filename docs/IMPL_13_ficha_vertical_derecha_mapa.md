# IMPL_13_ficha_vertical_derecha_mapa

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Forzar la ficha de predio seleccionado a formato vertical en el costado derecho del mapa.

## 2. Diagnostico / contexto actual
Aunque la ficha se habia movido al lado derecho, todavia podia percibirse como tarjeta inferior en algunos escenarios. Se requirio una disposicion lateral explicita.

## 3. Fases

### Fase 1 - Panel lateral derecho
Descripcion: Se definio posicion fija lateral mediante `top`, `bottom` y `right` para evitar anclaje inferior.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `Positioned(top: 110, bottom: 24, right: 16, ...)`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Columna vertical con scroll
Descripcion: Se envolvio la tarjeta en `SingleChildScrollView` para mantener formato vertical usable con contenido completo.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `SingleChildScrollView(child: _buildPredioCard(...))`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 3 - Ancho lateral compacto
Descripcion: Se redujo el ancho base del panel derecho para reforzar el aspecto de ficha vertical.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `cardWidth = screenWidth < 420 ? screenWidth - 32 : 300.0`
Tiempo estimado: 5 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| **Total** | **25 min** | **Bajo** |

## 5. Criterio de exito
- La ficha se visualiza como panel vertical del lado derecho.
- No se coloca en la franja inferior del mapa.
- El contenido completo es accesible mediante scroll interno.

## 6. Resultado / evidencia
- Ajuste implementado en layout del mapa.
- Analisis estatico sin nuevos errores de compilacion en el archivo objetivo.

## 7. Proximo paso
Validar visualmente en mapa con seleccion de poligono para confirmar posicion vertical lateral derecha.
