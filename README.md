# Geoportal LDDV

Aplicación web Flutter para la gestión y visualización de predios catastrales del proyecto LDDV (Línea de Ducto De Vapor).

## Características

- **Mapa interactivo**: visualización de predios GeoJSON sobre capas OpenStreetMap
- **Carga de archivos**: importación de GeoJSON y XLSX con previsualización
- **Gestión de predios**: CRUD completo con campos catastrales, etapas y COP
- **Gestión de propietarios**: vinculación propietario-predio
- **Tabla de datos**: filtrado, paginación y exportación
- **Reportes**: estadísticas y gráficas por proyecto, etapa y estatus
- **Persistencia local**: los archivos importados se conservan en localStorage (SharedPreferences/web)

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter Web |
| Estado | Riverpod (`StateNotifierProvider`) |
| Navegación | go_router |
| Mapas | flutter_map + OpenStreetMap |
| Persistencia | shared_preferences (localStorage en web) |
| Backend | Firebase (Auth + Firestore) |
| Base de datos | Cloud Firestore |

## Estructura del proyecto

```
lib/
├── main.dart               # Punto de entrada, inicialización Firebase
├── app.dart                # MaterialApp + ThemeData
├── core/
│   ├── constants/          # AppColors, AppStrings
│   ├── firebase/           # FirebaseConfig (dart-define)
│   ├── router/             # app_router.dart (rutas go_router)
│   ├── theme/              # AppTheme
│   └── ...
├── features/
│   ├── auth/               # Login, providers de autenticación y demo
│   ├── carga/              # Importación de archivos GeoJSON/XLSX
│   │   ├── data/           # LocalArchivosRepository (localStorage)
│   │   ├── providers/      # carga_provider (lista de archivos importados)
│   │   ├── services/       # Parser GeoJSON background, XLSX, sincronización
│   │   └── utils/          # GeoJSON mapper
│   ├── mapa/               # Pantalla de mapa, mapa_provider
│   ├── predios/            # Modelo Predio, CRUD, lista, formulario, detalle
│   ├── propietarios/       # Modelo Propietario, CRUD, lista, detalle
│   ├── reportes/           # Pantalla de reportes y estadísticas
│   └── tabla/              # Tabla de gestión, detalle de gestión
└── shared/
   ├── services/           # Servicios auxiliares
    └── widgets/            # AppScaffold (navbar/sidebar compartido)
```

## Configuración inicial

1. Clona el repositorio:
   ```bash
   git clone https://github.com/dayizz/GEOPORTAL-2.git
   cd GEOPORTAL-2
   ```

2. Instala dependencias:
   ```bash
   flutter pub get
   ```

3. Configura Firebase por `--dart-define` (obligatorio):
   ```bash
   --dart-define=FIREBASE_API_KEY=... \
   --dart-define=FIREBASE_APP_ID=... \
   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
   --dart-define=FIREBASE_PROJECT_ID=... \
   --dart-define=FIREBASE_AUTH_DOMAIN=... \
   --dart-define=FIREBASE_STORAGE_BUCKET=... \
   --dart-define=FIREBASE_MEASUREMENT_ID=...
   ```

4. Ejecuta web contra Firebase:
   ```bash
   flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
     --dart-define=FIREBASE_API_KEY=... \
     --dart-define=FIREBASE_APP_ID=... \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_PROJECT_ID=... \
     --dart-define=FIREBASE_AUTH_DOMAIN=... \
     --dart-define=FIREBASE_STORAGE_BUCKET=... \
     --dart-define=FIREBASE_MEASUREMENT_ID=...
   ```

5. Construye para web:
   ```bash
   flutter build web \
     --dart-define=FIREBASE_API_KEY=... \
     --dart-define=FIREBASE_APP_ID=... \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_PROJECT_ID=... \
     --dart-define=FIREBASE_AUTH_DOMAIN=... \
     --dart-define=FIREBASE_STORAGE_BUCKET=... \
     --dart-define=FIREBASE_MEASUREMENT_ID=...
   ```

6. Sirve localmente:
   ```bash
   python3 -m http.server 8083 --directory build/web
   ```
   Abre `http://localhost:8083` en el navegador.

## Backend

El backend de la app es 100% Firebase (Authentication + Cloud Firestore).

## Ramas

| Rama | Descripción |
|---|---|
| `main` | Rama principal |
| `v1` | Primera versión estable: localStorage, reportes rediseñados, limpieza de código |
