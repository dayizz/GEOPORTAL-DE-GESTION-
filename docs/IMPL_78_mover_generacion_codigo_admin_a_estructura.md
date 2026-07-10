# IMPL_78 Mover generacion de codigo admin a Estructura

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Reubicar la generacion de codigos de invitacion desde la vista Perfil hacia la vista Estructura, y mantener la visibilidad exclusiva para administradores.

## 2. Diagnostico / contexto actual

La accion de generar codigo estaba en Perfil, pero el flujo operativo requerido es administrarlo desde Estructura. Se necesita evitar duplicidad y asegurar que solo el administrador vea el control.

## 3. Fases

### Fase 1 - Retiro de UI en Perfil

- Descripcion:
  - Se elimino el bloque de "Aprobacion de Usuarios" en Perfil.
  - Se removio la funcion de generacion/copiado de codigo de esa pantalla.
- Archivos afectados:
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - Eliminacion de `_generarCodigoAprobacion(...)` y seccion asociada.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Alta de UI admin en Estructura

- Descripcion:
  - Se agrego tarjeta "Aprobacion de Usuarios" en la pestana Cuentas de Usuario de Estructura.
  - Se reutilizo `authRepositoryProvider.generateApprovalCode()` y dialogo para copiar codigo.
  - Visibilidad condicionada a `isAdminApproverUser(...)`.
- Archivos afectados:
  - lib/features/estructura/presentation/estructura_screen.dart
- Codigo clave:
  - `_buildAdminApprovalCard(...)`
  - `_generarCodigoAprobacion(...)`
  - `canGenerateCode = isAdminApproverUser(authUser)`
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Retiro en Perfil | 10 min | Bajo |
| Fase 2 - Alta en Estructura | 20 min | Medio |
| Total | 30 min | Medio |

## 5. Criterio de exito

- Perfil ya no muestra accion de generar codigo.
- Estructura muestra accion de generar codigo solo para administrador.
- El codigo generado mantiene flujo de copiado y uso unico.

## 6. Resultado / evidencia

- Generacion de codigo removida de Perfil.
- Generacion de codigo disponible en Estructura (Cuentas de Usuario) con control admin.

## 7. Proximo paso

Construir y desplegar hosting para reflejar cambios en produccion:

```bash
flutter build web --release
firebase deploy --project geoportal-de-gestion --only hosting
```