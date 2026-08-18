/**
 * Allowlist de campos que puede ver el público en el Geoportal de Consulta.
 * Deliberadamente NO se incluyen: propietario_nombre, propietario_id,
 * cop_firmado, pdf_url, oficio, situacion_social, direccion, colonia,
 * codigo_postal, ni ninguna columna arbitraria proveniente del archivo
 * GeoJSON/XLSX original (la importación las vuelca todas en `predios`).
 */
const ALLOWED_FIELDS = [
  'clave_catastral',
  'tramo',
  'tipo_propiedad',
  'estructura',
  'ejido',
  'estado',
  'municipio',
  'proyecto',
  'superficie',
  'km_inicio',
  'km_fin',
  'km_lineales',
  'km_efectivos',
  'geometry',
  'latitud',
  'longitud',
  'poligono_insertado',
  'identificacion',
  'levantamiento',
  'negociacion',
  'cop',
  'tipo_liberacion',
  'rango_estatus',
  'rango_estatus_fecha',
  'polygon_ref_id',
  'created_at',
  'updated_at',
];

function calcularPorcentajeAvance(data) {
  const pasos = ['identificacion', 'levantamiento', 'negociacion', 'cop', 'poligono_insertado'];
  const completados = pasos.filter((p) => data[p] === true).length;
  return completados / pasos.length;
}

/** Construye el documento saneado que se expone en `predios_publicos`. */
function sanitizarPredio(data) {
  const out = {};
  for (const field of ALLOWED_FIELDS) {
    if (data[field] !== undefined) {
      out[field] = data[field];
    }
  }
  out.porcentaje_avance = calcularPorcentajeAvance(data);
  return out;
}

module.exports = { ALLOWED_FIELDS, sanitizarPredio, calcularPorcentajeAvance };
