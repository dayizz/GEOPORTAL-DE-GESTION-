# IMPL_29 Ajuste Espaciado Reporte PDF

- Estado: Completado
- Fecha: 2026-07-03
- Rama: main

## 1. Objetivo
Ajustar el espaciado vertical en la plantilla PDF del reporte para mejorar legibilidad y cumplir requerimientos de formato del documento oficial.

## 2. Diagnostico / contexto actual
El layout PDF tenia separaciones reducidas entre:
- Bloque numerico de predios y bloque de graficas.
- Bloque de graficas y firma final ("ATENTAMENTE" e iniciales de elaboro/reviso).

Adicionalmente, el interlineado del bloque de metricas debia dejarse explicitamente en valor 3 para consistencia visual.

## 3. Fases

### Fase 1: Ajuste de espaciado entre bloque numerico y bloque de graficas
- Descripcion: Se bajo un renglon el inicio visual del bloque de graficas en la segunda pagina.
- Archivos afectados: `lib/features/reportes/presentation/generar_reporte_screen.dart`
- Codigo clave: Insercion de `pw.SizedBox(height: 12)` antes del titulo "Avance por tipo de propiedad".
- Tiempo estimado: 10 min
- Riesgo: Bajo (solo layout).

### Fase 2: Ajuste de espaciado para bloque de firma
- Descripcion: Se bajo dos renglones el bloque de firma ("ATENTAMENTE" e iniciales).
- Archivos afectados: `lib/features/reportes/presentation/generar_reporte_screen.dart`
- Codigo clave: Cambio de `pw.SizedBox(height: 2)` a `pw.SizedBox(height: 24)` previo a "ATENTAMENTE".
- Tiempo estimado: 10 min
- Riesgo: Bajo (solo layout).

### Fase 3: Estandarizacion de interlineado en metricas
- Descripcion: Se dejo explicito el interlineado 3 en el bloque de lineas:
  - Total de predios
  - Liberados
  - No liberados
  - KM efectivos liberados
  - Superficie liberada
- Archivos afectados: `lib/features/reportes/presentation/generar_reporte_screen.dart`
- Codigo clave: `lineSpacing: 3.0` en `pw.TextStyle` del bloque de metricas.
- Tiempo estimado: 5 min
- Riesgo: Bajo.

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| **Total** | **25 min** | **Bajo** |

## 5. Criterio de exito
- El bloque de graficas inicia visualmente un renglon mas abajo.
- "ATENTAMENTE" e iniciales se muestran dos renglones mas abajo.
- El bloque de metricas mantiene interlineado de 3 de forma explicita y consistente.

## 6. Resultado / evidencia
Cambios aplicados en:
- `lib/features/reportes/presentation/generar_reporte_screen.dart`

Ajustes realizados:
- Se agrego separador vertical de 12 pt al inicio de la pagina de graficas.
- Se incremento separador previo al bloque de firma a 24 pt.
- Se establecio `lineSpacing: 3.0` para el bloque de metricas.

## 7. Proximo paso
Generar una previsualizacion PDF desde la pantalla de reportes y validar visualmente el espaciado solicitado en entorno web y escritorio.