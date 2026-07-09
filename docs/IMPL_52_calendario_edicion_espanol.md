# IMPL_52 - Calendario de edicion en español

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Mostrar el calendario del campo Fecha en idioma español dentro de la vista Editar Predio.

## 2. Diagnostico / contexto actual
El selector de fecha se mostraba en ingles por falta de configuracion de localizacion global en `MaterialApp`.

## 3. Fases

### Fase 1 - Localizacion global de app
Descripcion: Se habilitaron locales y delegates de Flutter para Material/Cupertino/Widgets en español.
Archivos afectados:
- lib/app.dart
- pubspec.yaml
Codigo clave:
- `locale: Locale('es', 'MX')`
- `supportedLocales` con español
- `localizationsDelegates` globales
- Dependencia `flutter_localizations`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Localizacion explicita en date picker
Descripcion: Se forzo `locale: Locale('es', 'MX')` en `showDatePicker` del editor de predio.
Archivos afectados:
- lib/features/predios/presentation/predio_form_screen.dart
Codigo clave:
- Parametro `locale` en `_pickCopFecha()`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- El calendario en edicion muestra textos en español.
- Botones/meses/dias se presentan localizados en español.

## 6. Resultado / evidencia
- Configuracion de localizacion aplicada globalmente y en date picker.
- Validacion estatica sin errores en archivos tocados.

## 7. Proximo paso
Verificar en web que el selector de fecha muestre mes, dias y acciones en español en la pantalla Editar Predio.
