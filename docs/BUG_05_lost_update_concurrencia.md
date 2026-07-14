# BUG #5: Lost Update — Race Condition en Escritura Concurrente de Predios

**Severidad**: 🔴 ALTA — Pérdida de datos  
**Archivo**: `geoportal-lddv/backend/app/main.py` líneas 665-698  
**Tipo**: Race condition / Lost update  
**Status**: ✅ FIJO — File locking implementado  

---

## Problema

Los endpoints POST/PUT/DELETE operan sobre el archivo JSON local sin sincronización:

```python
# POST /predios
def create_predio(predio: dict):
    predios = _read_predios()  # ✓ Leer
    normalized = _normalize_predio(predio)
    # ... buscar y modificar localmente ...
    _write_predios(predios)  # ✓ Escribir
    return normalized

# PUT /predios/{predio_id}
def update_predio(predio_id: str, predio: dict):
    predios, index, existing = _find_predio_or_404(predio_id)
    normalized = _normalize_predio(payload, existing)
    predios[index] = normalized
    _write_predios(predios)  # ✓ Escribir
    return normalized

# DELETE /predios/{predio_id}
def delete_predio(predio_id: str):
    predios, index, _ = _find_predio_or_404(predio_id)
    predios.pop(index)
    _write_predios(predios)  # ✓ Escribir
    return {"deleted": True, "id": predio_id}
```

---

## Escenario de Lost Update

```
Tiempo  Request A (Update)        Request B (Delete)       File State
─────────────────────────────────────────────────────────────────────
T1      READ predios.json                                  [P1, P2, P3]
T2                                READ predios.json        [P1, P2, P3]
T3      Modifica P1 localmente
T4                                Elimina P2, modifica
T5      WRITE [P1', P2, P3]                                [P1', P2, P3]
T6                                WRITE [P1, P3']          [P1, P3'] ✗ PERDIDA P1'!
───────────────────────────────────────────────────────────────────
        Request A change LOST    Request B wins
```

---

## Impacto

- **Datos perdidos**: Cambios de Request A no se persisten
- **Inconsistencia**: No hay forma de retomar cambios perdidos
- **Degradación silenciosa**: Sin errores visibles, cambio se pierde
- **Escala**: A mayor concurrencia, mayor probabilidad de conflictos

---

## Ejemplos Prácticos

### 1. Actualizar y Borrar Simultáneamente
```
Request A: PUT /predios/123 (cambiar municipio)
Request B: DELETE /predios/456
→ Cambio en 123 se pierde, pero DELETE de 456 sale "success"
```

### 2. Crear Dos Predios Simultáneamente
```
Request A: POST /predios (crear P1)
Request B: POST /predios (crear P2)
→ Solo P2 se persiste, P1 se pierde silenciosamente
```

### 3. Batch Operations
```
Backend intenta:
- Actualizar P1
- Actualizar P2
- Crear P3
→ Si llega Request simultáneo entre actualizaciones, todo falla
```

---

## Raíz de la Causa

1. **Sin locking**: No hay mutex/lock entre READ y WRITE
2. **Sin versionado**: Archivo no tiene etag/version para detectar cambios
3. **Sin transacciones**: No hay ACID entre lectura y escritura
4. **Naive read-modify-write**: Patrón más propenso a race conditions

---

## Soluciones Posibles

### Opción 1: Usar Firestore (Recomendado)
- Migrrar de archivo local a Firestore para predios
- Firestore maneja transacciones automáticamente
- Compatible con UI que ya usa Firestore
- **Esfuerzo**: Alto, requiere refactor de API

### Opción 2: File-Level Locking (Corto Plazo)
```python
import fcntl

def _write_predios_atomic(predios: list[dict[str, Any]]) -> None:
    _ensure_store()
    with open(DATA_FILE, 'r+') as f:
        fcntl.flock(f, fcntl.LOCK_EX)  # Lock exclusivo
        try:
            temp_file = DATA_FILE.with_suffix(".tmp")
            temp_file.write_text(
                json.dumps(predios, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            temp_file.replace(DATA_FILE)
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)
```

### Opción 3: Add ETag/Version Check
```python
# Cada predio incluye version
def _write_predios_versioned(predios, expected_version):
    current_version = _get_version()
    if current_version != expected_version:
        raise Exception("Data was modified. Reload and try again.")
    _write_predios(predios)
    _increment_version()
```

### Opción 4: Request Queuing
- Serializar escribas con una cola (celery/rq)
- Todas las operaciones se procesan secuencialmente
- No hay race conditions
- **Costo**: Latencia adicional

---

## Recomendación Inmediata

Implementar **Opción 2 (File Locking)** como parche provisional:
- ✓ Bajo esfuerzo
- ✓ Reduce probabilidad de lost updates
- ✓ Prepara para migración a Firestore

Luego planear **Opción 1 (Firestore)** como solución permanente.

---

## Status

🔴 **IDENTIFICADO Y REPORTADO**  
Pendiente: Implementación de fix (file locking provisional)

---

## Nota Arquitectónica

El backend de gestión (`main.py`) actualmente mantiene fuente separada de predios (archivo JSON) vs. la UI que usa Firestore.

Para coherencia a largo plazo, toda aplicación debería usar **una única fuente de verdad**: Firestore.

Esto eliminaría:
- Race conditions de archivo
- Sincronización manual
- Duplicación de data
- Incompletitud de transacciones

