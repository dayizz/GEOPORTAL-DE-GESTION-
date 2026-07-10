# IMPL_70 - Conexion nube por dart-define

- Estado: Implementado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Conectar el proyecto a servicios en nube (Supabase y backend HTTP) sin hardcodear credenciales/URLs en el código fuente, usando variables de compilación de Flutter (`--dart-define`).

## 2. Diagnóstico / contexto actual

La configuración existente tenía:
- `SupabaseConfig` con placeholders (`TU_PROJECT_ID`, `TU_ANON_KEY`).
- `ApiClient` y `BackendService` apuntando a `localhost`.

Esto impedía una conexión cloud directa en despliegue sin editar archivos fuente.

## 3. Fases

### Fase 1 - Supabase por variables de entorno de compilación

- Descripción:
  - Se agregó lectura de `SUPABASE_URL` y `SUPABASE_ANON_KEY` vía `String.fromEnvironment`.
  - Se mantiene fallback local para desarrollo si no se pasan variables.
  - Se reforzó validación `isConfigured` para exigir URL HTTPS válida.
- Archivos afectados:
  - lib/core/supabase/supabase_config.dart
- Código clave:
  - `String.fromEnvironment('SUPABASE_URL')`
  - `String.fromEnvironment('SUPABASE_ANON_KEY')`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Backend HTTP por variable cloud

- Descripción:
  - Se parametrizó URL base del backend en cliente API y servicio compartido.
  - Se usa `BACKEND_BASE_URL` con fallback local (`localhost`).
- Archivos afectados:
  - lib/core/api/api_client.dart
  - lib/shared/services/backend_service.dart
- Código clave:
  - `String.fromEnvironment('BACKEND_BASE_URL')`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3 - Guía de ejecución cloud

- Descripción:
  - Se documentaron comandos `flutter run` y `flutter build web` con `--dart-define`.
- Archivos afectados:
  - README.md
- Código clave:
  - Variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BACKEND_BASE_URL`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Supabase por dart-define | 20 min | Bajo |
| Fase 2 - Backend por dart-define | 15 min | Bajo |
| Fase 3 - Documentación de uso | 10 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de éxito

- El proyecto puede ejecutarse apuntando a nube sin modificar código fuente.
- Supabase toma URL/anon key desde `--dart-define`.
- Backend toma URL base desde `--dart-define`.
- Existen instrucciones de uso en README.

## 6. Resultado / evidencia

- Configuración cloud aplicada en:
  - `lib/core/supabase/supabase_config.dart`
  - `lib/core/api/api_client.dart`
  - `lib/shared/services/backend_service.dart`
- README actualizado con comandos cloud.

## 7. Próximo paso

Ejecutar la app con valores reales:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  --dart-define=SUPABASE_URL=https://<tu-proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-real> \
  --dart-define=BACKEND_BASE_URL=https://<tu-backend>
```

Luego validar login, carga, listado y operaciones CRUD contra nube.
