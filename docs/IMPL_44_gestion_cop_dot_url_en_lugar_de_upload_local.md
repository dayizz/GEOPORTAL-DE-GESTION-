# IMPL_44 - Gestion COP/DOT con URL en lugar de upload local

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Sustituir en Gestion (columna COP/DOT) el flujo de seleccion de archivo PDF local por un flujo de captura de URL para dirigir a la pagina del archivo.

## 2. Diagnostico / contexto actual
La columna COP/DOT estaba configurada para abrir archivo vinculado si existia URL o, en ausencia, subir un PDF local mediante file picker y storage.
El requerimiento nuevo pide ingresar una URL directamente.

## 3. Fases

### Fase 1 - Retiro de upload local
Descripcion: Se elimino el uso de file picker y el flujo de subida de bytes a storage.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Eliminacion de import `file_picker`
- Eliminacion de estado `_uploadingPdfIds`
- Reemplazo de logica en `_handleCopPdfTap(...)`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 2 - Captura de URL en dialogo
Descripcion: Se agrego un dialogo para capturar y validar URL (`http/https`) y guardar el enlace en el predio.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `_requestPdfUrl(...)`
- guardado en `pdfUrl` y `copFirmado`
Tiempo estimado:
- 20 min
Riesgo:
- Bajo

### Fase 3 - Ajuste visual y tooltip en COP/DOT
Descripcion: Se actualizo iconografia y textos de ayuda para reflejar el nuevo flujo de URL.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `_copPdfIndicatorCell(...)`
- icono `Icons.link`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Total | 50 min | Bajo |

## 5. Criterio de exito
- En COP/DOT ya no se solicita archivo local.
- Cuando no hay enlace, el usuario puede escribir una URL valida.
- Cuando ya existe enlace, el sistema abre la pagina del archivo.

## 6. Resultado / evidencia
- Implementacion aplicada en la pantalla de Gestion.
- Se mantiene persistencia del enlace en el registro del predio.

## 7. Proximo paso
Validar en UI que el enlace se guarde correctamente y abra en nueva pestana al tocar el icono de COP/DOT.
