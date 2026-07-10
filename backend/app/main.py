import json
import re
from json import JSONDecodeError, JSONDecoder
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Geoportal Backend API", version="1.0.0")

# CORS config for Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
DATA_FILE = DATA_DIR / "predios.json"
MUNICIPIOS_FILE = DATA_DIR / "municipios.geojson"
PROJECT_CODES = ("TQI", "TSNL", "TAP", "TQM")


def _ensure_store() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]", encoding="utf-8")


def _read_predios() -> list[dict[str, Any]]:
    _ensure_store()
    raw = DATA_FILE.read_text(encoding="utf-8").strip() or "[]"
    try:
        data = json.loads(raw)
        if not isinstance(data, list):
            raise ValueError("El almacén de predios es inválido.")
        return [dict(item) for item in data if isinstance(item, dict)]
    except JSONDecodeError:
        # Recuperación tolerante: permite archivos con múltiples documentos JSON
        # concatenados o con basura al final. Se conserva lo parseable y se reescribe.
        decoder = JSONDecoder()
        index = 0
        recovered: list[dict[str, Any]] = []

        while index < len(raw):
            while index < len(raw) and raw[index].isspace():
                index += 1

            if index >= len(raw):
                break

            try:
                parsed, end_index = decoder.raw_decode(raw, index)
            except JSONDecodeError:
                break

            if isinstance(parsed, list):
                recovered.extend(dict(item) for item in parsed if isinstance(item, dict))
            elif isinstance(parsed, dict):
                recovered.append(dict(parsed))

            index = end_index

        if recovered:
            _write_predios(recovered)
            return recovered

        raise ValueError("El almacén de predios está dañado y no se pudo recuperar.")


def _read_municipios_geojson() -> list[dict[str, Any]]:
    if not MUNICIPIOS_FILE.exists():
        return []

    try:
        raw = MUNICIPIOS_FILE.read_text(encoding="utf-8").strip()
        if not raw:
            return []

        data = json.loads(raw)
        features = data.get("features") if isinstance(data, dict) else None
        if not isinstance(features, list):
            return []

        municipios: list[dict[str, Any]] = []
        for feature in features:
            if not isinstance(feature, dict):
                continue

            properties = feature.get("properties")
            props = properties if isinstance(properties, dict) else {}
            geometry = feature.get("geometry") if isinstance(feature.get("geometry"), dict) else {}

            nombre = ""
            for key in (
                "municipio",
                "MUNICIPIO",
                "nombre",
                "NOMBRE",
                "nom_municipio",
                "NOM_MUNICIPIO",
                "name",
                "NAME",
            ):
                value = props.get(key)
                if isinstance(value, str) and value.strip():
                    nombre = value.strip()
                    break

            if not nombre:
                feature_name = feature.get("id")
                if isinstance(feature_name, str) and feature_name.strip():
                    nombre = feature_name.strip()

            if not nombre:
                continue

            estado = None
            for key in ("estado", "ESTADO", "shapeGroup", "state", "STATE"):
                value = props.get(key)
                if isinstance(value, str) and value.strip():
                    estado = value.strip()
                    break

            municipios.append({
                "id": str(feature.get("id") or nombre).strip(),
                "nombre": nombre,
                "estado": estado,
                "geometry": geometry,
            })

        return municipios
    except (JSONDecodeError, ValueError):
        return []


def _write_predios(predios: list[dict[str, Any]]) -> None:
    _ensure_store()
    temp_file = DATA_FILE.with_suffix(".tmp")
    temp_file.write_text(
        json.dumps(predios, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    temp_file.replace(DATA_FILE)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "si", "sí", "yes"}
    return False


def _pick_text(payload: dict[str, Any], keys: tuple[str, ...] | list[str]) -> str | None:
    invalid = {"", "null", "none", "undefined", "nulo"}
    for key in keys:
        value = payload.get(key)
        if value is None:
            continue
        text = str(value).strip()
        if text and text.lower() not in invalid:
            return text

    normalized_aliases = {_normalize_key(key) for key in keys}
    for key, value in payload.items():
        if value is None:
            continue
        if _normalize_key(key) not in normalized_aliases:
            continue
        text = str(value).strip()
        if text and text.lower() not in invalid:
            return text

    return None


def _normalize_key(key: Any) -> str:
    text = str(key).strip().lower()
    replacements = str.maketrans(
        {
            "á": "a",
            "à": "a",
            "ä": "a",
            "â": "a",
            "é": "e",
            "è": "e",
            "ë": "e",
            "ê": "e",
            "í": "i",
            "ì": "i",
            "ï": "i",
            "î": "i",
            "ó": "o",
            "ò": "o",
            "ö": "o",
            "ô": "o",
            "ú": "u",
            "ù": "u",
            "ü": "u",
            "û": "u",
            "ñ": "n",
        }
    )
    text = text.translate(replacements)
    return re.sub(r"[^a-z0-9]", "", text)



def _pick_float(payload: dict[str, Any], keys: tuple[str, ...] | list[str]) -> float | None:
    invalid = {"", "null", "none", "undefined", "nulo"}

    for key in keys:
        value = payload.get(key)
        if value is None:
            continue
        if isinstance(value, (int, float)):
            return float(value)
        text = str(value).strip()
        if not text or text.lower() in invalid:
            continue

        km_match = re.fullmatch(r"(-?\d+)\s*\+\s*(\d+)", text)
        if km_match:
            base = float(km_match.group(1))
            meters = float(km_match.group(2))
            return base + (meters / 1000.0)

        normalized = text.replace(" ", "")
        if "," in normalized and "." not in normalized:
            normalized = normalized.replace(",", ".")
        else:
            normalized = normalized.replace(",", "")
        normalized = re.sub(r"[^0-9.\-]", "", normalized)
        try:
            return float(normalized)
        except ValueError:
            continue

    normalized_aliases = {_normalize_key(key) for key in keys}
    for key, value in payload.items():
        if value is None:
            continue
        if _normalize_key(key) not in normalized_aliases:
            continue
        if isinstance(value, (int, float)):
            return float(value)
        text = str(value).strip()
        if not text or text.lower() in invalid:
            continue

        km_match = re.fullmatch(r"(-?\d+)\s*\+\s*(\d+)", text)
        if km_match:
            base = float(km_match.group(1))
            meters = float(km_match.group(2))
            return base + (meters / 1000.0)

        normalized = text.replace(" ", "")
        if "," in normalized and "." not in normalized:
            normalized = normalized.replace(",", ".")
        else:
            normalized = normalized.replace(",", "")
        normalized = re.sub(r"[^0-9.\-]", "", normalized)
        try:
            return float(normalized)
        except ValueError:
            continue
    return None


def _normalize_tipo_propiedad(value: Any) -> str:
    upper = str(value or "").strip().upper()
    compact = re.sub(r"[^A-Z0-9]", "", upper)
    if "SOC" in compact:
        return "SOCIAL"
    if "DOMINIOPLENO" in compact or ("DOMINIO" in compact and "PLENO" in compact):
        return "DOMINIO PLENO"
    if "EJI" in compact:
        return "EJIDAL"
    if "MIX" in compact:
        return "MIXTO"
    if "FEDERAL" in compact:
        return "FEDERAL"
    if "GUBERNAMENTAL" in compact or "GUBERNAM" in compact or "GOBIERNO" in compact:
        return "GUBERNAMENTAL"
    if "PRIVAD" in compact or compact == "PRI":
        return "PRIVADA"
    return upper or "PRIVADA"


def _infer_project_from_text(value: str | None) -> str | None:
    text = str(value or "").strip().upper()
    if not text:
        return None

    for code in PROJECT_CODES:
        if re.search(rf"(^|[^A-Z0-9]){re.escape(code)}([^A-Z0-9]|$)", text):
            return code
        if code in text:
            return code

    return None


def _infer_project_from_clave(value: str | None) -> str | None:
    clave = str(value or "").strip().upper()
    if not clave:
        return None

    compact = re.sub(r"[^A-Z0-9]", "", clave)

    if compact.startswith(("TQI", "QI")):
        return "TQI"
    if compact.startswith(("TSNL", "SNL", "SL")):
        return "TSNL"
    if compact.startswith(("TAP", "AP")):
        return "TAP"
    if compact.startswith(("TQM", "QM")):
        return "TQM"

    return None


def _infer_estado_municipio_from_clave(value: str | None) -> tuple[str | None, str | None]:
    clave = str(value or "").strip().upper()
    if not clave:
        return None, None

    tokens = [token for token in re.split(r"[^A-Z0-9]+", clave) if token]
    code = tokens[1] if len(tokens) >= 2 else ""
    municipios_tsln = {
        "SLV": "Salinas Victoria",
        "VIL": "Villaldama",
        "BUS": "Bustamante",
        "LAM": "Lampazos de Naranjo",
        "ANA": "Anahuac",
        "SAB": "Sabinas Hidalgo",
    }

    estado = "Nuevo Leon" if clave.startswith(("SNL", "TSNL")) else None
    municipio = municipios_tsln.get(code)
    return estado, municipio


def _infer_project(predio: dict[str, Any]) -> str | None:
    explicit = _infer_project_from_text(str(predio.get("proyecto") or ""))
    if explicit is not None:
        return explicit

    content = " ".join(
        [
            str(predio.get("proyecto") or ""),
            str(predio.get("clave_catastral") or ""),
            str(predio.get("ejido") or ""),
            str(predio.get("poligono_dwg") or ""),
            str(predio.get("oficio") or ""),
            str(predio.get("pdf_url") or ""),
            str(predio.get("cop_firmado") or ""),
        ]
    ).upper()

    from_content = _infer_project_from_text(content)
    if from_content is not None:
        return from_content

    clave = str(predio.get("clave_catastral") or "").strip().upper()
    from_clave = _infer_project_from_clave(clave)
    if from_clave is not None:
        return from_clave

    return None


def _normalize_predio(payload: dict[str, Any], existing: dict[str, Any] | None = None) -> dict[str, Any]:
    now = _now_iso()
    predio = dict(existing or {})

    for key, value in payload.items():
        if value is not None:
            predio[key] = value

    predio["id"] = str(predio.get("id") or uuid4())
    predio["clave_catastral"] = str(
        predio.get("clave_catastral") or predio.get("id_sedatu") or ""
    ).strip()
    predio["tramo"] = predio.get("tramo") or "T1"
    tipo_propiedad = _pick_text(
        predio,
        (
            "tipo_propiedad",
            "TIPO_PROPIEDAD",
            "tipopropiedad",
            "tipo propiedad",
            "tipo_de_propiedad",
            "tipo",
            "regimen",
            "REGIMEN",
            "tenencia",
            "TIPO_TENENCIA",
            "clase_propiedad",
            "CLASE_PROPIEDAD",
            "clasificacion_propiedad",
            "CLASIFICACION_PROPIEDAD",
        ),
    )
    if tipo_propiedad is not None:
        predio["tipo_propiedad"] = _normalize_tipo_propiedad(tipo_propiedad)
    else:
        predio["tipo_propiedad"] = predio.get("tipo_propiedad") or "PRIVADA"

    estado = _pick_text(
        predio,
        (
            "estado",
            "ESTADO",
            "entidad",
            "ENTIDAD",
            "entidad_federativa",
            "ENTIDAD_FEDERATIVA",
            "nombre_estado",
            "NOMBRE_ESTADO",
            "nombre del estado",
            "NOMBRE DEL ESTADO",
            "nom_estado",
            "NOM_ESTADO",
            "edo",
            "EDO",
            "state",
            "STATE",
        ),
    )
    if estado is not None:
        predio["estado"] = estado

    municipio = _pick_text(
        predio,
        (
            "municipio",
            "MUNICIPIO",
            "municipality",
            "MUNICIPALITY",
            "nombre_municipio",
            "NOMBRE_MUNICIPIO",
            "nombre del municipio",
            "NOMBRE DEL MUNICIPIO",
            "nom_municipio",
            "NOM_MUNICIPIO",
            "mpio",
            "MPIO",
            "muni",
            "MUNI",
            "mun",
            "MUN",
            "localidad",
            "LOCALIDAD",
            "ciudad",
            "CIUDAD",
        ),
    )
    if municipio is not None:
        predio["municipio"] = municipio

    inferred_estado, inferred_municipio = _infer_estado_municipio_from_clave(
        str(predio.get("clave_catastral") or "")
    )
    if predio.get("estado") in (None, "") and inferred_estado is not None:
        predio["estado"] = inferred_estado
    if predio.get("municipio") in (None, "") and inferred_municipio is not None:
        predio["municipio"] = inferred_municipio

    km_inicio = _pick_float(
        predio,
        (
            "km_inicio",
            "KM_INICIO",
            "km inicio",
            "KM INICIO",
            "km_ini",
            "KM_INI",
            "km_i",
            "KM_I",
            "cadenamiento_inicial",
            "CADENAMIENTO_INICIAL",
            "cad_ini",
            "CAD_INI",
            "km_inicial",
            "KM_INICIAL",
        ),
    )
    if km_inicio is not None:
        predio["km_inicio"] = km_inicio

    km_fin = _pick_float(
        predio,
        (
            "km_fin",
            "KM_FIN",
            "km fin",
            "KM FIN",
            "km_f",
            "KM_F",
            "cadenamiento_final",
            "CADENAMIENTO_FINAL",
            "cad_fin",
            "CAD_FIN",
            "cadenamiento_f",
            "CADENAMIENTO_F",
            "cadenamiento_1",
            "km_final",
            "KM_FINAL",
        ),
    )
    if km_fin is not None:
        predio["km_fin"] = km_fin

    km_efectivos = _pick_float(
        predio,
        (
            "km_efectivos",
            "KM_EFECTIVOS",
            "km efectivos",
            "KM EFECTIVOS",
            "km_efectivo",
            "KM_EFECTIVO",
            "km_e",
            "KM_E",
            "longitud_efectiva",
            "LONGITUD_EFECTIVA",
            "longitud efectiva",
            "LONGITUD EFECTIVA",
            "kme",
            "KME",
        ),
    )
    if km_efectivos is not None:
        predio["km_efectivos"] = km_efectivos

    pdf_url = str(predio.get("pdf_url") or predio.get("cop_firmado") or "").strip()
    predio["pdf_url"] = pdf_url or None
    cop_fecha = predio.get("cop_fecha")
    predio["cop_fecha"] = str(cop_fecha).strip() if cop_fecha else None
    if pdf_url and not str(predio.get("cop_firmado") or "").strip():
        predio["cop_firmado"] = pdf_url
    predio["cop"] = _as_bool(predio.get("cop"))
    predio["identificacion"] = _as_bool(predio.get("identificacion"))
    predio["levantamiento"] = _as_bool(predio.get("levantamiento"))
    predio["negociacion"] = _as_bool(predio.get("negociacion"))
    predio["poligono_insertado"] = _as_bool(predio.get("poligono_insertado"))
    inferred_project = _infer_project(predio)
    if inferred_project is not None:
        predio["proyecto"] = inferred_project
    predio["created_at"] = (
        existing.get("created_at")
        if existing is not None
        else predio.get("created_at") or now
    )
    predio["updated_at"] = now
    return predio


def _find_predio_or_404(predio_id: str) -> tuple[list[dict[str, Any]], int, dict[str, Any]]:
    predios = _read_predios()
    for index, predio in enumerate(predios):
        if str(predio.get("id")) == predio_id:
            return predios, index, predio
    raise HTTPException(status_code=404, detail="Predio no encontrado")


def _matches_project(predio: dict[str, Any], proyecto: str) -> bool:
    target = proyecto.strip().upper()
    effective_project = _infer_project(predio)
    return effective_project == target


def _matches_clave(predio: dict[str, Any], clave_catastral: str) -> bool:
    return str(predio.get("clave_catastral") or "").strip().upper() == clave_catastral.strip().upper()


@app.get("/")
def root():
    return {"message": "Geoportal Backend API running"}


@app.get("/predios")
def list_predios(
    proyecto: str | None = Query(default=None),
    clave_catastral: str | None = Query(default=None),
):
    predios = _read_predios()

    if proyecto:
        predios = [p for p in predios if _matches_project(p, proyecto)]

    if clave_catastral:
        predios = [p for p in predios if _matches_clave(p, clave_catastral)]

    predios.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    return predios


@app.get("/predios/estadisticas")
def get_estadisticas():
    predios = _read_predios()
    conteo: dict[str, int] = {}
    superficie_total = 0.0

    for predio in predios:
        uso = str(predio.get("tipo_propiedad") or "Sin tipo")
        conteo[uso] = (conteo.get(uso) or 0) + 1

        superficie = predio.get("superficie")
        if isinstance(superficie, (int, float)):
            superficie_total += float(superficie)

    return {
        "total": len(predios),
        "por_uso_suelo": conteo,
        "superficie_total": superficie_total,
    }


@app.get("/predios/by-clave/{clave_catastral}")
def get_predio_by_clave(clave_catastral: str):
    predios = _read_predios()
    for predio in predios:
        if _matches_clave(predio, clave_catastral):
            return predio
    raise HTTPException(status_code=404, detail="Predio no encontrado")


@app.get("/municipios")
def list_municipios():
    return _read_municipios_geojson()


@app.get("/api/v1/municipios")
def list_municipios_v1():
    return list_municipios()


@app.get("/api/v1/predios")
def list_predios_v1(
    proyecto: str | None = Query(default=None),
    clave_catastral: str | None = Query(default=None),
):
    return list_predios(proyecto=proyecto, clave_catastral=clave_catastral)


@app.get("/predios/{predio_id}")
def get_predio(predio_id: str):
    _, _, predio = _find_predio_or_404(predio_id)
    return predio

@app.post("/predios")
def create_predio(predio: dict):
    predios = _read_predios()
    normalized = _normalize_predio(predio)

    replaced = False
    for index, existing in enumerate(predios):
        if str(existing.get("id")) == normalized["id"]:
            predios[index] = _normalize_predio(normalized, existing)
            normalized = predios[index]
            replaced = True
            break

    if not replaced:
        predios.append(normalized)

    _write_predios(predios)
    return normalized

@app.put("/predios/{predio_id}")
def update_predio(predio_id: str, predio: dict):
    predios, index, existing = _find_predio_or_404(predio_id)
    payload = dict(predio)
    payload["id"] = predio_id
    normalized = _normalize_predio(payload, existing)
    predios[index] = normalized
    _write_predios(predios)
    return normalized

@app.delete("/predios/{predio_id}")
def delete_predio(predio_id: str):
    predios, index, _ = _find_predio_or_404(predio_id)
    predios.pop(index)
    _write_predios(predios)
    return {"deleted": True, "id": predio_id}
