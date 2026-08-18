# Control de versiones y correcciones de Gestión

**Estado:** Implementado en rama de trabajo
**Fecha:** 2026-08-18
**Rama:** `fix/gestion-control-versiones`

## Objetivo

Crear un punto de control reproducible para los cambios actuales del Geoportal y dejar la funcionalidad de Gestión lista para validación sin incluir dependencias locales generadas.

## Diagnóstico / contexto actual

El repositorio estaba en `main` con cambios funcionales pendientes en Gestión, mapa, reportes, importación y modelos. También aparecía un entorno virtual Python completo como archivos no rastreados. La pantalla de Gestión concentra cambios de filtros, estados, numeración, documentos y exportación.

## Fases

### Fase 1: Aislamiento de trabajo

- **Descripción:** Crear una rama independiente para las correcciones.
- **Archivos afectados:** Metadatos Git.
- **Código clave:** `git switch -c fix/gestion-control-versiones`.
- **Tiempo estimado:** 2 minutos.
- **Riesgo:** Bajo.

### Fase 2: Limpieza de archivos locales

- **Descripción:** Excluir el entorno virtual Python del control de versiones.
- **Archivos afectados:** `.gitignore`.
- **Código clave:** Regla `venv/`.
- **Tiempo estimado:** 1 minuto.
- **Riesgo:** Bajo; no elimina archivos locales.

### Fase 3: Validación funcional

- **Descripción:** Ejecutar análisis estático en Gestión, mapa y reportes, además de la prueba existente de importación.
- **Archivos afectados:** Sin cambios adicionales.
- **Código clave:** `flutter analyze lib/features/tabla lib/features/mapa lib/features/reportes` y `flutter test test/features/carga/utils/imported_file_cleanup_test.dart`.
- **Tiempo estimado:** 3 minutos.
- **Riesgo:** Bajo.

## Resumen de esfuerzo

| Actividad | Resultado | Riesgo |
|---|---|---|
| Rama de trabajo | Creada | Bajo |
| Exclusión de `venv/` | Validada con `git check-ignore` | Bajo |
| Análisis Flutter | Sin errores bloqueantes; quedan advertencias informativas | Medio |
| Prueba de importación | 6 pruebas aprobadas | Bajo |

## Criterio de éxito

- La rama de trabajo existe y parte del estado actual de `main`.
- `venv/` no aparece como cambio pendiente.
- Gestión compila según el análisis estático del SDK disponible.
- Las pruebas cercanas al flujo de importación pasan.
- Los cambios funcionales quedan agrupados en un commit recuperable.

## Resultado / evidencia

- Rama activa: `fix/gestion-control-versiones`.
- `git diff --check`: correcto.
- `flutter analyze`: sin errores; solo advertencias en mapa y reportes.
- Prueba de importación: `00:00 +6: All tests passed!`.
- `venv/` es ignorado por Git.

## Próximo paso

Revisar visualmente Gestión en web o escritorio con datos reales y, tras aprobarla, fusionar la rama mediante un pull request.