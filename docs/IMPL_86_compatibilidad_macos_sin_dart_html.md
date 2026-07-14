# IMPL_86 - Compatibilidad macOS sin dart:html

- Estado: Implementado (codigo)
- Fecha: 2026-07-13
- Rama: main

## 1. Objetivo
Permitir compilacion de escritorio macOS eliminando dependencias directas a `dart:html` en pantallas compartidas.

## 2. Diagnostico / contexto actual
La compilacion macOS fallaba porque existian imports directos de `dart:html` en modulos usados por rutas desktop:
- mapa
- tabla
- reportes

`dart:html` solo existe en web.

## 3. Fases

### Fase 1 - Abstraccion de descarga web
- Descripcion: crear helper con import condicional web/stub.
- Archivos afectados:
  - `lib/core/utils/browser_download.dart`
  - `lib/core/utils/browser_download_web.dart`
  - `lib/core/utils/browser_download_stub.dart`
- Codigo clave:
  - `downloadBytesForBrowser(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Refactor de pantallas
- Descripcion: reemplazar uso directo de html por helper multiplataforma.
- Archivos afectados:
  - `lib/features/mapa/presentation/mapa_screen.dart`
  - `lib/features/reportes/presentation/generar_reporte_screen.dart`
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave:
  - uso de `kIsWeb`
  - descarga web por helper
  - clipboard por `Clipboard.getData` (sin `html.window`)
- Tiempo estimado: 30 min
- Riesgo: Medio-bajo

### Fase 3 - Validacion
- Descripcion: verificar errores de analizador y build macOS.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 15 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Esfuerzo |
|---|---:|
| Fase 1 | 20 min |
| Fase 2 | 30 min |
| Fase 3 | 15 min |
| Total | 65 min |

## 5. Criterio de exito
- No hay imports directos de `dart:html` en codigo compartido desktop.
- El proyecto compila para macOS sin errores de plataforma Dart.

## 6. Resultado / evidencia
- Errores `dart:html is not available on this platform` eliminados.
- Persistio bloqueo de entorno local en etapa de codesign (`resource fork... detritus not allowed`), ajeno al codigo Dart.

## 7. Proximo paso
- Corregir permisos/atributos extendidos del entorno macOS y reintentar build release firmado.
