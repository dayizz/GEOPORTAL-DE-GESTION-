# IMPL_71 - Migracion backend 100 Firebase

- Estado: Implementado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Migrar el proyecto para operar con backend 100% Firebase, eliminando el uso operativo de Supabase/FastAPI en autenticacion y persistencia de datos principales.

## 2. Diagnostico / contexto actual

El proyecto estaba en modo mixto:
- Autenticacion con Supabase/local-only.
- Predios con mezcla de Supabase/FastAPI.
- Repositorios de propietarios y archivos orientados a Supabase.

Se requeria backend unico en Firebase.

## 3. Fases

### Fase 1 - Base Firebase y arranque

- Descripcion:
  - Se agregaron dependencias Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`).
  - Se creo configuracion central en `core/firebase/firebase_config.dart` via `--dart-define`.
  - `main.dart` ahora inicializa Firebase y exige configuracion valida.
- Archivos afectados:
  - pubspec.yaml
  - lib/core/firebase/firebase_config.dart
  - lib/main.dart
- Codigo clave:
  - `Firebase.initializeApp(options: FirebaseConfig.options)`
- Tiempo estimado: 30 min
- Riesgo: Medio

### Fase 2 - Autenticacion y enrutamiento

- Descripcion:
  - Migracion de `auth_provider` de Supabase a FirebaseAuth.
  - `localOnlyAuthMode` se fija en `false` para operacion cloud real.
  - Router valida sesion con `FirebaseAuth.instance.currentUser`.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
  - lib/core/router/app_router.dart
- Codigo clave:
  - `signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `authStateChanges()`
- Tiempo estimado: 30 min
- Riesgo: Medio

### Fase 3 - Repositorios de datos en Firestore

- Descripcion:
  - `PrediosRepository` migrado a Cloud Firestore.
  - `PropietariosRepository` migrado a Cloud Firestore.
  - `ArchivosGeoJsonRepository` migrado a Cloud Firestore.
  - Ajustes de provider/UI para usar `FirebaseConfig`.
- Archivos afectados:
  - lib/features/predios/data/predios_repository.dart
  - lib/features/propietarios/data/propietarios_repository.dart
  - lib/features/carga/data/archivos_geojson_repository.dart
  - lib/features/propietarios/providers/propietarios_provider.dart
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Codigo clave:
  - Colecciones: `predios`, `propietarios`, `archivos_geojson`
- Tiempo estimado: 80 min
- Riesgo: Medio-Alto

### Fase 4 - Documentacion

- Descripcion:
  - README actualizado para Firebase-only.
- Archivos afectados:
  - README.md
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Base Firebase | 30 min | Medio |
| Fase 2 - Auth/Router | 30 min | Medio |
| Fase 3 - Repositorios Firestore | 80 min | Medio-Alto |
| Fase 4 - Documentacion | 10 min | Bajo |
| Total | 150 min | Medio |

## 5. Criterio de exito

- No se usa Supabase en flujo operativo principal.
- Autenticacion y datos (predios/propietarios/archivos) operan contra Firebase.
- App no inicia sin `dart-define` Firebase minimo requerido.
- Compilacion sin errores en archivos modificados.

## 6. Resultado / evidencia

- Migracion aplicada en auth, router y repositorios clave.
- Dependencias Supabase removidas de `pubspec.lock` tras `flutter pub get`.
- Verificacion de errores en archivos modificados: sin errores.

## 7. Proximo paso

Configurar las variables reales en ejecucion/build y validar reglas de Firebase:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  --dart-define=FIREBASE_API_KEY=<api_key> \
  --dart-define=FIREBASE_APP_ID=<app_id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender_id> \
  --dart-define=FIREBASE_PROJECT_ID=<project_id> \
  --dart-define=FIREBASE_AUTH_DOMAIN=<auth_domain> \
  --dart-define=FIREBASE_STORAGE_BUCKET=<storage_bucket> \
  --dart-define=FIREBASE_MEASUREMENT_ID=<measurement_id>
```
