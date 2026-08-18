import '../../../core/utils/import_normalization.dart' as norm;

/// Normaliza las claves de un objeto `properties` de GeoJSON
/// para que coincidan exactamente con las columnas del esquema de datos.
///
/// Uso:
/// ```dart
/// final normalized = GeoJsonMapper.normalizeProperties(feature['properties']);
/// ```
class GeoJsonMapper {
  GeoJsonMapper._();

  /// Mapa de alias: columna_canonica → [alias1, alias2, ...]
  static const _keyAliases = <String, List<String>>{
    'clave_catastral': [
      'clave_catastral', 'CLAVE_CATASTRAL',
      'id_catastral',    'ID_CATASTRAL',
      'id_sedatu',       'ID_SEDATU',
      'clave',           'CLAVE',
      'folio',           'FOLIO',
      'id_predio',       'ID_PREDIO',
      'cvegeo',          'CVEGEO',
      'objectid',        'OBJECTID',
      'fid',             'FID',
      'gid',             'GID',
      'id',              'ID',
    ],
    'proyecto': [
      'proyecto', 'PROYECTO',
      'nombre_proyecto', 'NOMBRE_PROYECTO',
      'tramo_proyecto',  'obra', 'OBRA',
    ],
    'tramo': [
      'tramo', 'TRAMO',
      'tramo_vial', 'TRAMO_VIAL',
      'seccion', 'SECCION',
      'frente', 'FRENTE',
      'segmento', 'SEGMENTO',
      't_f_s', 'T_F_S',
      'tipofs', 'TIPO_FS',
    ],
    'frente': [
      'frente', 'FRENTE',
      'frente_', 'FRENTE_',
    ],
    'segmento': [
      'segmento', 'SEGMENTO',
      'num_segmento', 'NUM_SEGMENTO',
    ],
    'tipo_propiedad': [
      'tipo_propiedad', 'TIPO_PROPIEDAD',
      'tipopropiedad',
      'TIPO DE PROPIEDAD', 'tipo de propiedad',
      'tipo_de_propiedad', 'TIPO_DE_PROPIEDAD',
      'tipo', 'TIPO',
      'regimen', 'REGIMEN',
      'tenencia', 'TENENCIA',
    ],
    'estructura': [
      'estructura', 'ESTRUCTURA',
      'tipo_estructura', 'TIPO_ESTRUCTURA',
      'clase_estructura', 'CLASE_ESTRUCTURA',
      'estruc', 'ESTRUC',
    ],
    'tipo_liberacion': [
      'tipo_liberacion', 'TIPO_LIBERACION',
      'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
      'liberacion', 'LIBERACION',
      'cop_dot', 'COP_DOT', 'cop_dot_aop', 'COP_DOT_AOP',
    ],
    'ejido': [
      'ejido', 'EJIDO',
      'nom_ejido', 'NOM_EJIDO',
      'nombre_ejido', 'comunidad', 'localidad',
    ],
    'propietario_nombre': [
      'propietario', 'PROPIETARIO',
      'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'NOM_PROPIETARIO',
      'titular', 'TITULAR',
      'nombre',
    ],
    'superficie': [
      'superficie', 'SUPERFICIE',
      'area', 'AREA', 'Area', 'AREA_M2', 'area_m2',
      'shape_area', 'SHAPE_AREA', 'Shape_Area',
      'area_ha', 'AREA_HA',
      'superficie_m2', 'SUPERFICIE_M2',
      'm2', 'M2',
    ],
    'uso_suelo': [
      'uso_suelo', 'USO_SUELO',
      'uso', 'USO',
      'land_use', 'LAND_USE',
      'clasificacion', 'CLASIFICACION',
    ],
    'zona': [
      'zona', 'ZONA',
      'sector', 'SECTOR',
      'region', 'REGION',
    ],
    'valor_catastral': [
      'valor_catastral', 'VALOR_CATASTRAL',
      'valor', 'VALOR',
      'avaluo', 'AVALUO',
      'valor_terreno', 'VALOR_TERRENO',
    ],
    'descripcion': [
      'descripcion', 'DESCRIPCION',
      'description', 'DESCRIPTION',
      'observaciones', 'OBSERVACIONES',
    ],
    'direccion': [
      'direccion', 'DIRECCION',
      'domicilio', 'DOMICILIO',
      'calle', 'CALLE',
      'address', 'ADDRESS',
    ],
    'colonia': [
      'colonia', 'COLONIA',
      'asentamiento', 'ASENTAMIENTO',
      'barrio', 'BARRIO',
    ],
    'municipio': [
      'municipio', 'MUNICIPIO',
      'mun', 'MUN',
      'mpio', 'MPIO',
      'muni', 'MUNI',
      'municipality', 'MUNICIPALITY',
      'localidad', 'LOCALIDAD',
      'ciudad', 'CIUDAD',
      'nom_municipio', 'NOM_MUNICIPIO',
      'nombre_municipio', 'NOMBRE_MUNICIPIO',
      'nombre del municipio', 'NOMBRE DEL MUNICIPIO',
      'nom_mun', 'NOM_MUN',
      'municipio_nombre', 'MUNICIPIO_NOMBRE',
      'cve_mun', 'CVE_MUN',
      'nom_loc', 'NOM_LOC',
      'localidad_nombre', 'LOCALIDAD_NOMBRE',
    ],
    'estado': [
      'estado', 'ESTADO',
      'entidad', 'ENTIDAD',
      'state', 'STATE',
      'nombre_entidad', 'NOMBRE_ENTIDAD',
      'entidad_federativa', 'ENTIDAD_FEDERATIVA',
      'edo', 'EDO',
      'nom_estado', 'NOM_ESTADO',
      'nombre_estado', 'NOMBRE_ESTADO',
      'nombre del estado', 'NOMBRE DEL ESTADO',
      'nom_ent', 'NOM_ENT',
      'cve_ent', 'CVE_ENT',
      'entidad_nombre', 'ENTIDAD_NOMBRE',
      'nom_edo', 'NOM_EDO',
      'nombre_ent', 'NOMBRE_ENT',
      'estado_nombre', 'ESTADO_NOMBRE',
    ],
    // Status de liberación (COP). NOTA: 'estatus' NO es alias de 'cop' -esa
    // palabra se reserva para 'rango_estatus' (Liberado/Negociacion/Posible
    // DOT/...)-, para no chocar cuando un archivo trae ambas columnas.
    'cop': [
      'cop', 'COP',
      'status', 'STATUS',
      'liberado', 'LIBERADO',
      'liberada', 'LIBERADA',
      'firmado', 'FIRMADO',
      'cop_firmado', 'COP_FIRMADO',
      'anuencia', 'ANUENCIA',
    ],
    // "Estatus" / "Rango de estatus": Liberado, Negociacion, Posible DOT,
    // Instruccion UVSR, Con ingreso, No liberado, L nueva.
    'rango_estatus': [
      'rango_estatus', 'RANGO_ESTATUS',
      'rango de estatus', 'RANGO DE ESTATUS',
      'rango_de_estatus', 'RANGO_DE_ESTATUS',
      'estatus', 'ESTATUS',
      'estatus_predio', 'ESTATUS_PREDIO',
    ],
    // Campos booleanos de gestión
    'identificacion': [
      'identificacion', 'IDENTIFICACION',
      'identificación', 'IDENTIFICACIÓN',
      'identificado', 'IDENTIFICADO',
      'id_status', 'ID_STATUS',
      'identificacion_', 'IDENTIFICACION_',
    ],
    'levantamiento': [
      'levantamiento', 'LEVANTAMIENTO',
      'levantado', 'LEVANTADO',
      'levantamiento_', 'LEVANTAMIENTO_',
      'lev_status', 'LEV_STATUS',
    ],
    'negociacion': [
      'negociacion', 'NEGOCIACION',
      'negociación', 'NEGOCIACIÓN',
      'negociado', 'NEGOCIADO',
      'negociacion_', 'NEGOCIACION_',
      'neg_status', 'NEG_STATUS',
    ],
    'codigo_postal': [
      'codigo_postal', 'CODIGO_POSTAL',
      'cp', 'CP', 'postal_code', 'POSTAL_CODE',
    ],
    'imagen_url': [
      'imagen_url', 'IMAGEN_URL',
      'foto_url', 'FOTO_URL',
      'image_url', 'IMAGE_URL',
    ],
    'km_inicio': [
      'km_inicio', 'KM_INICIO',
      'km iniicio', 'KM INIICIO',
      'cadenamiento_inicial', 'cad_ini', 'km_i',
      'km_ini', 'KM_INI', 'km_inicio', 'KM_INICIO',
      'cadenamiento_i', 'CADENAMIENTO_I', 'km0', 'KM0',
    ],
    'km_fin': [
      'km_fin', 'KM_FIN',
      'KM FIN', 'km fin',
      'cadenamiento_final', 'cad_fin', 'km_f',
      'cadenamiento_f', 'CADENAMIENTO_F',
      'km1', 'KM1', 'cadenamiento_1',
    ],
    'km_lineales': [
      'km_lineales', 'KM_LINEALES',
      'longitud_km', 'longitud', 'km', 'KM',
      'longitud_km', 'LONGITUD_KM', 'km_lineal', 'KM_LINEAL',
    ],
    'km_efectivos': [
      'km_efectivos', 'KM_EFECTIVOS',
      'KM EFECTIVOS', 'km efectivos',
      'km_efectivo', 'KM_EFECTIVO',
      'km_e', 'KM_E', 'kme',
    ],
    'latitud':  ['latitud', 'lat', 'LAT', 'latitude'],
    'longitud': ['longitud', 'lon', 'lng', 'LON', 'longitude'],
    'rfc':  ['rfc', 'RFC'],
    'curp': ['curp', 'CURP'],
    'telefono': ['telefono', 'TELEFONO', 'tel', 'TEL', 'phone'],
    'correo':   ['correo', 'email', 'EMAIL', 'correo_electronico'],
    'razon_social': ['razon_social', 'RAZON_SOCIAL', 'empresa', 'EMPRESA', 'denominacion'],
    'cop_fecha': [
      'cop_fecha', 'COP_FECHA',
      'fecha_liberacion', 'FECHA_LIBERACION',
      'fecha_de_liberacion', 'FECHA_DE_LIBERACION',
      'fecha liberacion', 'FECHA LIBERACION',
      'fecha de liberacion', 'FECHA DE LIBERACION',
    ],
    'fecha_limite_pago': [
      'fecha_limite_pago', 'FECHA_LIMITE_PAGO',
      'fecha_limite_de_pago', 'FECHA_LIMITE_DE_PAGO',
      'fecha limite de pago', 'FECHA LIMITE DE PAGO',
      'fecha_limite', 'FECHA_LIMITE',
      'fecha limite', 'FECHA LIMITE',
      'limite_pago', 'LIMITE_PAGO',
      'fecha_pago', 'FECHA_PAGO',
      'fecha de pago', 'FECHA DE PAGO',
    ],
  };

  /// Proyectos conocidos para detección automática durante la importación.
  /// Se mantiene mutable: `carga_archivo_screen.dart` lo sincroniza con los
  /// proyectos vigentes en Estructura (Firestore) antes de cada importación,
  /// para que un proyecto recién creado (o eliminado) ahí se reconozca aquí
  /// también. El valor inicial es el fallback si aún no se sincronizó.
  static List<String> proyectosConocidos = ['TQI', 'TSNL', 'TAP', 'TMQ'];

  static String _normalizeKey(String input) {
    var s = input.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String? _inferProyectoDesdeTexto(String? value) {
    if (value == null) return null;
    final upper = _normalizeSpaces(value).toUpperCase();
    if (upper.isEmpty) return null;

    for (final code in proyectosConocidos) {
      final regex = RegExp('(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
      if (regex.hasMatch(upper) || upper.contains(code)) {
        return code;
      }
    }

    return null;
  }

  static String? inferProyectoDesdeClave(String? clave) {
    if (clave == null) return null;
    final upper = clave.trim().toUpperCase();
    if (upper.isEmpty) return null;

    final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) {
      return 'TSNL';
    }
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    // 'TQM' se reconoce como alias heredado (typo histórico); el código
    // canónico correcto es 'TMQ' (Tren México-Querétaro).
    if (compact.startsWith('TMQ') || compact.startsWith('TQM') || compact.startsWith('QM')) {
      return 'TMQ';
    }

    return null;
  }

  /// Normaliza las claves del mapa [props] al esquema canónico de la app.
  ///
  /// Las claves originales que no tienen alias conocido se preservan tal cual.
  /// Las claves canónicas tienen precedencia sobre las originales.
  static Map<String, dynamic> normalizeProperties(Map<String, dynamic> props) {
    final result = Map<String, dynamic>.from(props);

    for (final entry in _keyAliases.entries) {
      final canonicalKey = entry.key;
      dynamic selected = result[canonicalKey];

      if (selected == null || selected.toString().trim().isEmpty || selected.toString() == 'null') {
        for (final alias in entry.value) {
          final value = props[alias];
          if (value != null) {
            final str = value.toString().trim();
            if (str.isNotEmpty && str != 'null') {
              selected = value;
              break;
            }
          }
        }
      }

      if (selected != null) {
        result[canonicalKey] = _normalizeCanonicalValue(canonicalKey, selected);
      }
    }

    return result;
  }

  static dynamic _normalizeCanonicalValue(String key, dynamic value) {
    // Si ya es boolean, devolverlo directo
    if (value is bool) return value;
    
    // Si es numérico (1, 0), convertir a boolean para campos booleanos
    if (value is num) {
      if (_booleanKeys.contains(key)) {
        return value != 0;
      }
      return value;
    }
    
    if (value is! String) return value;
    final text = _normalizeSpaces(value);

    switch (key) {
      // Códigos: recorte + sin acentos/guiones sueltos + MAYÚSCULAS.
      case 'clave_catastral':
      case 'rfc':
      case 'curp':
      case 'tramo':
        return norm.normalizeCode(text) ?? text.toUpperCase();
      case 'correo':
        return text.toLowerCase();
      case 'proyecto':
        return _normalizeProyecto(text);
      case 'tipo_propiedad':
        return norm.normalizeTipoPropiedad(text);
      case 'tipo_liberacion':
        return norm.normalizeTipoLiberacion(text);
      case 'estructura':
        return norm.normalizeEstructura(text) ?? text;
      // "Ejido": texto libre, salvo variantes de "no aplica" (no todos los
      // predios pertenecen a un ejido) que se guardan como "N/A".
      case 'ejido':
        return norm.normalizeEjido(text) ?? text;
      // "Estatus"/"Rango de estatus" contra el catálogo de Gestión.
      case 'rango_estatus':
        return norm.normalizeRangoEstatus(text);
      // "Fecha de liberación" (COP/DOT): acepta ISO, dd/mm/aaaa y
      // dd-mm-aaaa, siempre se guarda en ISO 8601.
      case 'cop_fecha':
      case 'fecha_limite_pago':
        return norm.normalizeFechaLiberacion(text);
      // Texto libre para mostrar: recorte + sin acentos + Capitalización.
      case 'propietario_nombre':
      case 'razon_social':
      case 'estado':
      case 'municipio':
      case 'colonia':
      case 'direccion':
      case 'descripcion':
        return norm.normalizeTitleCase(text) ?? text;
      // Para campos booleanos, convertir strings a boolean
      case 'identificacion':
      case 'levantamiento':
      case 'negociacion':
      case 'cop':
        return norm.normalizeBoolean(text);
      // "km inicio"/"km fin": aceptan formato PK ("12+359") o decimal
      // ("12.359") -misma distancia-, siempre se guardan como el mismo
      // número (12.359) para que Gestión los muestre en formato PK.
      case 'km_inicio':
      case 'km_fin':
        return norm.normalizeKmValue(text);
      // Para el resto de campos numéricos, convertir strings a double
      case 'superficie':
      case 'km_lineales':
      case 'km_efectivos':
      case 'valor_catastral':
      case 'latitud':
      case 'longitud':
        return _toDouble(text);
      default:
        return text;
    }
  }

  /// Convierte strings a double para campos numéricos
  static double? _toDouble(String value) {
    if (value.isEmpty) return null;
    final cleaned = value.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  /// Keys que deben convertirse a boolean
  static const _booleanKeys = {
    'identificacion',
    'levantamiento',
    'negociacion',
    'cop',
    'poligono_insertado',
  };

  static String _normalizeSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeProyecto(String value) {
    final inferred = _inferProyectoDesdeTexto(value);
    if (inferred != null) return inferred;
    return value.toUpperCase();
  }

  /// Intenta detectar el proyecto a partir de las properties normalizadas.
  ///
  /// Busca en los campos más relevantes y en todos los valores como fallback.
  static String? detectarProyecto(Map<String, dynamic> props) {
    // 1. Campo directo / alias con nombre relacionado a proyecto
    final candidatos = <String?>[
      props['proyecto']?.toString(),
      props['PROYECTO']?.toString(),
      props['nombre_proyecto']?.toString(),
      props['NOMBRE_PROYECTO']?.toString(),
      props['tramo_proyecto']?.toString(),
      props['TRAMO_PROYECTO']?.toString(),
      props['obra']?.toString(),
      props['OBRA']?.toString(),
    ];

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      final keyIsProjectLike = key.contains('proyecto') ||
          key.contains('obra') ||
          key.contains('tramoproyecto');
      if (!keyIsProjectLike) continue;
      candidatos.add(entry.value?.toString());
    }

    for (final candidate in candidatos) {
      final inferred = _inferProyectoDesdeTexto(candidate);
      if (inferred != null) return inferred;
    }

    // 2. Prefijo de clave catastral
    final clave = props['clave_catastral']?.toString() ??
        props['CLAVE_CATASTRAL']?.toString() ??
        props['id_sedatu']?.toString() ??
        props['ID_SEDATU']?.toString() ??
        props['clave']?.toString() ??
        props['CLAVE']?.toString();
    final fromClave = inferProyectoDesdeClave(clave);
    if (fromClave != null) return fromClave;

    // 3. Buscar en todos los valores del mapa
    for (final value in props.values) {
      if (value == null) continue;
      final inferred = _inferProyectoDesdeTexto(value.toString());
      if (inferred != null) return inferred;
    }

    return null;
  }

  /// Detecta el proyecto desde una lista de features enriquecidos.
  ///
  /// Usa el campo `_proyecto` inyectado por el motor de sincronización,
  /// o busca en las properties originales como fallback.
  ///
  /// Si detecta más de un proyecto distinto dentro del mismo lote,
  /// devuelve `null` para no forzar un filtro incorrecto en Gestión.
  static String? detectarProyectoDesdeFeatures(
    List<Map<String, dynamic>> features,
  ) {
    final proyectosDetectados = <String>{};

    for (final feature in features) {
      final rawProps = feature['properties'];
      if (rawProps is! Map) continue;
      final props = Map<String, dynamic>.from(rawProps);

      // Campo inyectado por SincronizacionService
      final inyectado = props['_proyecto']?.toString().trim().toUpperCase();
      if (inyectado != null && proyectosConocidos.contains(inyectado)) {
        proyectosDetectados.add(inyectado);
        if (proyectosDetectados.length > 1) return null;
        continue;
      }

      final detectado = detectarProyecto(props);
      if (detectado != null) {
        proyectosDetectados.add(detectado);
        if (proyectosDetectados.length > 1) return null;
      }
    }

    if (proyectosDetectados.length == 1) {
      return proyectosDetectados.first;
    }

    return null;
  }
}
