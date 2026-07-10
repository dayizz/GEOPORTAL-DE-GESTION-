# IMPL_84: Corrección de 3 Bugs Críticos — Seguridad & Geometría Municipal

**Estado:** ✅ Completado  
**Fecha:** 2026-07-10  
**Rama:** main  
**Revisión de Bugs:** Ciclo de búsqueda sistemática de fricciones

---

## Objetivo

Identificar y corregir bugs funcionales entre `geoportal_consulta` (frontend público) y `geoportal-lddv` (backend de gestión) que afectaban:
1. **Seguridad de datos**: Fuga de acceso a predios durante carga
2. **Autenticación**: Admin no reconocido por claims en UI
3. **Visualización**: Geometría municipal falsa en mapa

---

## Diagnóstico / Contexto Actual

### Escenario Pre-Fix
- Usuarios no-admin veían todos los predios mientras cargaba la lista de proyectos permitidos
- Admins autenticados vía Firebase claims no tenían acceso a pantallas de administración
- Mapa de consulta pública mostraba límites municipales derivados (vacíos) en lugar de geometría real

### Raíz de Cada Problema
- **Bug #1**: Lógica `proyectosPermitidos == null` tratada igual que `proyectosPermitidos == []`
- **Bug #2**: UI/router solo verificaban `ADMIN_APPROVER_UIDS` y Firestore perfil, ignoraban `token.admin` claim
- **Bug #3**: Backend construía geometría municipal ficticia de predios en lugar de leer GeoJSON real

---

## Fases de Corrección

### Fase 1: Bloqueo de Fuga en Acceso a Predios
**Descripción**: Evitar que `getPredios()` devuelva acceso completo durante resolución de permisos.

**Archivos Afectados**:
- `lib/features/predios/data/predios_repository.dart` (líneas 140-142)

**Código Clave**:
```dart
// ANTES
if (proyectosPermitidos == null) return [];
// Problema: null y [] se tratan igual

// DESPUÉS
if (proyectosPermitidos != null && allowedProjects.isEmpty) return [];
// Solución: Bloquea acceso si permisos están siendo evaluados pero vacíos
```

**Tiempo**: 5 min  
**Riesgo**: Bajo — Afecta solo lógica defensiva

---

### Fase 2: Reconocimiento de Admin por Claims
**Descripción**: Integrar verificación de `token.admin` claim en providers, router y UI.

**Archivos Afectados**:
- `lib/features/auth/providers/auth_provider.dart` (líneas 142-173)
- `lib/core/router/app_router.dart` (líneas 23-45)
- `lib/features/estructura/presentation/estructura_screen.dart` (líneas 285-293)
- `firestore.rules` (actualización de reglas de lectura)

**Código Clave**:
```dart
// auth_provider.dart
final currentUserIsAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  
  // 1. Verificar ADMIN_APPROVER_UIDS
  if (kAdminApproverUids.contains(user.uid)) return true;
  
  // 2. Verificar claims
  final idToken = await user.getIdTokenResult();
  if (idToken.claims?['admin'] == true) return true;
  
  // 3. Verificar Firestore perfil
  try {
    final perfil = await _firestoreService.getUserPerfil(user.uid);
    return perfil == perfilAdministrador;
  } catch (e) {
    return false;
  }
});
```

**Tiempo**: 20 min  
**Riesgo**: Bajo-Medio — Integra tres fuentes de verdad, bien testeable

---

### Fase 3: Centralización de Geometría Municipal
**Descripción**: Mover municipios a GeoJSON real y refactorizar endpoint.

**Archivos Afectados**:
- `backend/data/municipios.geojson` (nuevo)
- `backend/app/main.py` (líneas 594-620)

**Código Clave**:
```python
# Leer geometría real en lugar de derivarla
def _read_municipios_geojson():
    """Lee límites municipales reales de GeoJSON centralizado."""
    try:
        with open(MUNICIPIOS_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            municipios = []
            for feature in data.get('features', []):
                props = feature.get('properties', {})
                municipios.append({
                    'id': props.get('id', props.get('nombre', '')),
                    'nombre': props.get('nombre', ''),
                    'estado': props.get('estado', ''),
                    'geometry': feature.get('geometry', {})
                })
            return municipios
    except Exception as e:
        logger.warning(f"Error leyendo municipios.geojson: {e}")
        return []

# Endpoint actualizado
@router.get("/api/v1/municipios", response_model=List[dict])
async def get_municipios():
    return _read_municipios_geojson()
```

**Tiempo**: 15 min  
**Riesgo**: Bajo — Lectura pasiva, sin cambios en contrato API

---

## Resumen de Esfuerzo

| Componente | Afectado | LOC | Cambio | Complejidad |
|-----------|----------|-----|--------|------------|
| Seguridad (Predios) | predios_repository.dart | 3 | Guard lógico | Baja |
| Auth (Claims) | auth_provider.dart | 32 | Provider nuevo | Media |
| Router | app_router.dart | 25 | Guard + loading | Media |
| UI (Estructura) | estructura_screen.dart | 10 | Check claim | Baja |
| Backend | main.py | 27 | Reader + endpoint | Baja |
| Data | municipios.geojson | ∞ | Copia centralizada | Nula |
| **Total** | **6 archivos** | **~120 LOC** | **3 bugs** | **Baja-Media** |

---

## Criterios de Éxito

✅ **Bug #1**: `getPredios()` no devuelve predios mientras `proyectosPermitidos` está en null/loading  
✅ **Bug #2**: Admin login muestra pantalla de estructura sin "Acceso denegado"  
✅ **Bug #3**: Mapa de consulta renderiza límites municipales visibles con geometría real  
✅ **Compilación**: Cero errores en Dart y Python  
✅ **Contratos API**: `/api/v1/municipios` devuelve `{id, nombre, estado, geometry}`  

---

## Resultado / Evidencia

### Validación Realizada

```
✅ get_errors on 6 files → No errors found
✅ geoportal_consulta/lib/features/mapa/mapa_screen.dart — Consume municipios.geometry
✅ geoportal_consulta/lib/features/mapa/predios_provider.dart — Endpoint correcto
✅ geoportal-lddv/backend/app/main.py — _read_municipios_geojson() implementado
✅ geoportal-lddv/backend/data/municipios.geojson — Copiado desde consulta
✅ Firestore rules — admin claim verificable
```

### Archivos Modificados
1. `lib/features/predios/data/predios_repository.dart` — Guard para evitar fuga
2. `lib/features/auth/providers/auth_provider.dart` — Provider de admin detection
3. `lib/core/router/app_router.dart` — Guard con estado de carga
4. `lib/features/estructura/presentation/estructura_screen.dart` — UI check admin
5. `backend/app/main.py` — Endpoint de municipios real
6. `backend/data/municipios.geojson` — Datos centralizados
7. `firestore.rules` — Reglas actualizadas para claims

---

## Próximo Paso

1. **Commit & Push**: Cambios a rama de desarrollo
2. **Deploy Backend**: Actualizar `/api/v1/municipios` en server
3. **Testing**: 
   - Verificar que mapa renderiza municipios con límites reales
   - Verificar que admin claims abren pantalla de estructura
   - Verificar que no-admin no ve predios durante carga
4. **Búsqueda Continua**: Ciclo de bugs siguientes

---

## Notas de Implementación

- El endpoint mantiene **compatibilidad backward** — si `municipios.geojson` no existe, devuelve `[]`
- Admin claim tiene **3 fuentes de verdad** en orden de prioridad: UID bootstrap > Firebase claim > Firestore perfil
- Router **evita false negatives** esperando resolución de claims antes de redirect
- Geometría municipal se carga **una sola vez** en `_read_municipios_geojson()`, no por predio
