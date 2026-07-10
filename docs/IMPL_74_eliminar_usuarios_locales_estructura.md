# IMPL_74 Eliminar usuarios locales de Estructura

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo
Eliminar los usuarios precargados localmente en la pantalla de Estructura para evitar datos simulados en la gestion de usuarios.

## 2. Diagnostico / contexto actual
La lista inicial de usuarios en `UsuariosNotifier` se inicializaba con registros hardcodeados. Esto provocaba que siempre aparecieran usuarios al abrir la seccion, aunque no existiera una fuente real de persistencia para ellos.

## 3. Fases
### Fase 1: Retiro de datos locales iniciales
- Descripcion: Reemplazar la lista hardcodeada por una lista vacia tipada.
- Archivos afectados: `lib/features/estructura/presentation/estructura_screen.dart`
- Codigo clave: `static final _usuariosIniciales = <Usuario>[];`
- Tiempo estimado: 10 min
- Riesgo: Bajo (solo afecta estado inicial en memoria)

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |

## 5. Criterio de exito
- La vista de usuarios inicia sin registros precargados.
- Ya no aparecen usuarios locales por defecto.
- No se introducen errores de analisis en el archivo modificado.

## 6. Resultado / evidencia
- Se removieron los 3 usuarios hardcodeados del estado inicial.
- `UsuariosNotifier` ahora arranca con lista vacia.
- Verificacion estatica: sin errores en el archivo modificado.

## 7. Proximo paso
Definir una fuente persistente para usuarios (Firestore/coleccion dedicada) y reemplazar el estado local temporal por lectura/escritura remota.
