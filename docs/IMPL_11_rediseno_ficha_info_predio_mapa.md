# IMPL_11_rediseno_ficha_info_predio_mapa

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Rediseñar la ficha de informacion que aparece al hacer click sobre un poligono en el mapa para priorizar datos clave y ajustar los campos visibles segun requerimiento.

## 2. Diagnostico / contexto actual
La ficha previa mostraba propietario y clave en orden secundario y utilizaba chips de estado para COP y Poligono. No priorizaba la clave catastral como dato principal ni presentaba de forma directa estatus, estado/municipio y kilometrajes solicitados.

## 3. Fases

### Fase 1 - Redefinicion visual de cabecera
Descripcion: Se mantiene el recuadro de tipo de propiedad y se agrega estatus visible en cabecera.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- _buildPredioCard(...)
Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2 - Reorden de contenido principal
Descripcion: Se establece la clave catastral como dato principal (titulo), seguido por propietario y bloque de datos estructurados.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- CLAVE CATASTRAL como titulo principal
- infoRow(label, value)
Tiempo estimado: 25 min
Riesgo: Bajo

### Fase 3 - Campos solicitados y limpieza de marcadores
Descripcion: Se agregan KM inicio, KM fin, KM efectivo, estatus, estado y municipio. Se eliminan chips COP y Poligono.
Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- kmInicioText / kmFinText / kmEfectivoText
- _predioEstatus(predio)
- chips solo para Identificacion, Levantamiento, Negociacion
Tiempo estimado: 20 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 20 min | Bajo |
| **Total** | **65 min** | **Bajo** |

## 5. Criterio de exito
- La ficha conserva recuadro de tipo de propiedad.
- La clave catastral se muestra como dato principal.
- Se muestran propietario, estatus, estado, municipio, km inicio, km fin y km efectivo.
- Si un KM no existe, se presenta en blanco.
- No se muestran marcadores COP ni Poligono.

## 6. Resultado / evidencia
Resultado actual:
- Ficha redisenada e implementada en la pantalla de mapa.
- Analisis estatico del archivo ejecutado sin errores de compilacion.

Evidencia tecnica:
- Archivo modificado: lib/features/mapa/presentation/mapa_screen.dart
- Funcion intervenida: _buildPredioCard(Predio predio)
- Validacion: flutter analyze lib/features/mapa/presentation/mapa_screen.dart

## 7. Proximo paso
Validar visualmente en la UI:
1. Abrir Mapa.
2. Hacer click en un poligono.
3. Confirmar orden de campos y ausencia de chips COP/Poligono.
4. Confirmar datos KM en blanco cuando no existan.
