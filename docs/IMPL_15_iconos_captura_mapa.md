# IMPL_15_iconos_captura_mapa

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Ajustar controles de captura en mapa para que:
- Captura de predio quede solo como icono (sin texto).
- El icono de captura de pantalla se ubique inmediatamente a la derecha.

## 2. Diagnostico / contexto actual
El control de captura de predio se mostraba como boton con icono + texto y el de captura de pantalla estaba en otra fila inferior.

## 3. Fases

### Fase 1 - Reordenar controles superiores
Descripcion: Se unificaron ambos controles en un `Row` dentro del mismo `Positioned`.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- Positioned(top: 16, left: 16, child: Row(...))
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Captura de predio icon-only
Descripcion: Se elimino texto "Captura de predio" y flecha, dejando boton cuadrado con solo icono.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- _buildCapturaToggleButton()
Tiempo estimado: 12 min
Riesgo: Bajo

### Fase 3 - Homologar estilo del icono de pantalla
Descripcion: Se compacto el boton de captura de pantalla para que quede visualmente consistente y alineado a la derecha del icono de predio.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- _buildCapturaPantallaButton()
Tiempo estimado: 8 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 12 min | Bajo |
| Fase 3 | 8 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## 5. Criterio de exito
- El control de captura de predio aparece solo como icono.
- El icono de captura de pantalla aparece a la derecha del icono de captura de predio.
- No se introducen errores de compilacion por los cambios.

## 6. Resultado / evidencia
- Cambios aplicados en la pantalla de mapa.
- `flutter analyze` sin errores nuevos (solo warnings preexistentes del archivo).
- Hot restart aplicado para reflejar cambios.

## 7. Proximo paso
Validar visualmente en mapa que ambos iconos se muestran en la misma fila superior y en el orden solicitado.
