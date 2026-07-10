import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../predios/data/predios_repository.dart';
import '../../propietarios/data/propietarios_repository.dart';
import '../utils/geojson_mapper.dart';

/// Resultado del procesamiento de un único feature GeoJSON.
class FeatureSyncResult {
  /// Feature con properties enriquecidas (datos del sistema inyectados).
  final Map<String, dynamic> feature;

  /// Si es `true`, el predio ya existía en la BD y los datos fueron inyectados.
  final bool existia;

  /// ID del predio en la BD (nuevo o existente).
  final String? predioId;

  const FeatureSyncResult({
    required this.feature,
    required this.existia,
    this.predioId,
  });
}

/// Resultado global de la sincronización de un archivo GeoJSON.
class SincronizacionResultado {
  final List<FeatureSyncResult> resultados;
  final int encontrados;
  final int creados;
  final int errores;
  /// Mensajes de error para diagnóstico (máx. 5).
  final List<String> mensajesError;

  const SincronizacionResultado({
    required this.resultados,
    required this.encontrados,
    required this.creados,
    required this.errores,
    this.mensajesError = const [],
  });

  List<Map<String, dynamic>> get features =>
      resultados.map((r) => r.feature).toList();
}

class _FeatureSyncOutcome {
  final int featureIndex;
  final FeatureSyncResult result;
  final int encontrados;
  final int creados;
  final int errores;
  final List<String> mensajesError;

  const _FeatureSyncOutcome({
    required this.featureIndex,
    required this.result,
    required this.encontrados,
    required this.creados,
    required this.errores,
    this.mensajesError = const [],
  });
}

/// Motor de sincronización GeoJSON ↔ Base de datos.
///
/// Para cada feature:
/// 1. Extrae el identificador único del campo `clave_catastral` (o aliases).
/// 2. Consulta la tabla `predios`.
/// 3. Si existe → inyecta datos de gestión y propietario en `properties`.
/// 4. Si no existe → crea el registro en `predios` (y opcionalmente en `propietarios`).
class SincronizacionService {
  final PrediosRepository _prediosRepo;
  final PropietariosRepository _propietariosRepo;
  static const int _defaultSyncConcurrency = 50;
  static const int _maxSyncConcurrency = 100;
  static const int _maxRetryAttempts = 2;
  static const int _baseRetryDelayMs = 100;

  SincronizacionService(this._prediosRepo, this._propietariosRepo);

  /// Claves que se buscan en `properties` para identificar el predio.
  /// Incluye variantes en mayúsculas y minúsculas.
  static const _idKeys = [
    'clave_catastral', 'CLAVE_CATASTRAL',
    'id_catastral',    'ID_CATASTRAL',
    'clave',           'CLAVE',
    'folio',           'FOLIO',
    'id_sedatu',       'ID_SEDATU',
    'id_predio',       'ID_PREDIO',
    'cvegeo',          'CVEGEO',
    'id',              'ID',
    'fid',             'FID',
    'gid',             'GID',
    'objectid',        'OBJECTID',
  ];

  /// Extrae la clave catastral de las properties del feature.
  String? _extractId(Map<String, dynamic> props) {
    for (final key in _idKeys) {
      final value = props[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

  /// Combina properties del feature con datos del sistema.
  Map<String, dynamic> _injectData(
    Map<String, dynamic> props,
    Map<String, dynamic> predioMap,
  ) {
    final enriched = Map<String, dynamic>.from(props);
    final syncAt = DateTime.now().toIso8601String();

    // Datos de gestión
    enriched['_predioId'] = predioMap['id'];
    enriched['predio_id'] = predioMap['id'];
    enriched['_claveCatastral'] = predioMap['clave_catastral'];
    enriched['clave_catastral_db'] = predioMap['clave_catastral'];
    enriched['_tramo'] = predioMap['tramo'];
    enriched['_tipoPropiedad'] = predioMap['tipo_propiedad'];
    enriched['_cop'] = predioMap['cop'];
    enriched['_superficie'] = predioMap['superficie'];
    enriched['_identificacion'] = predioMap['identificacion'];
    enriched['_levantamiento'] = predioMap['levantamiento'];
    enriched['_negociacion'] = predioMap['negociacion'];
    enriched['_poligonoInsertado'] = predioMap['poligono_insertado'];
    enriched['_ejido'] = predioMap['ejido'];
    enriched['_kmInicio'] = predioMap['km_inicio'];
    enriched['_kmFin'] = predioMap['km_fin'];
    enriched['_kmLineales'] = predioMap['km_lineales'];
    enriched['_kmEfectivos'] = predioMap['km_efectivos'];
    enriched['_proyecto'] = predioMap['proyecto'];
    enriched['_sincronizado'] = true;
    enriched['_syncStatus'] = 'linked';
    enriched['_syncSource'] = 'geojson_import';
    enriched['_syncAt'] = syncAt;

    // Datos del propietario (si están en el join)
    final propietarioRaw = predioMap['propietarios'];
    if (propietarioRaw is Map) {
      final propMap = Map<String, dynamic>.from(propietarioRaw);
      enriched['_propietarioNombre'] = [
        propMap['nombre'],
        propMap['apellidos'],
      ].where((v) => v != null && v.toString().isNotEmpty).join(' ');
      enriched['_propietarioRfc'] = propMap['rfc'];
    } else {
      enriched['_propietarioNombre'] = predioMap['propietario_nombre'];
    }

    return enriched;
  }

  /// Busca el primer valor no nulo/vacío de una lista de claves en [props].
  /// Solo ignora valores realmente vacíos o nulos.
  static final _invalidValues = {
    'null', 'nulo', 'undefined', 'none', '',
  };
  
  String? _pick(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      final v = props[k]?.toString().trim();
      if (v != null && v.isNotEmpty && !_invalidValues.contains(v.toLowerCase())) {
        return v;
      }
    }
    return null;
  }

  String? _pickFlexible(Map<String, dynamic> props, List<String> keys) {
    final exact = _pick(props, keys);
    if (exact != null) return exact;

    final normalizedAliases = keys.map(_normalizeKey).toSet();
    for (final entry in props.entries) {
      final normalizedEntryKey = _normalizeKey(entry.key);
      if (!normalizedAliases.contains(normalizedEntryKey)) continue;
      final v = entry.value?.toString().trim();
      if (v != null && v.isNotEmpty && !_invalidValues.contains(v.toLowerCase())) {
        return v;
      }
    }

    return null;
  }

  double? _pickDoubleFlexible(Map<String, dynamic> props, List<String> keys) {
    final raw = _pickFlexible(props, keys);
    return _toDouble(raw);
  }

  Map<String, String?> _resolveEstadoMunicipio(Map<String, dynamic> props) {
    String? estado = _pickFlexible(props, [
      'estado', 'ESTADO', 'entidad', 'ENTIDAD',
      'state', 'STATE', 'nombre_entidad', 'NOMBRE_ENTIDAD',
      'entidad_federativa', 'ENTIDAD_FEDERATIVA',
      'nombre_estado', 'NOMBRE_ESTADO',
      'nombre del estado', 'NOMBRE DEL ESTADO',
      'nom_estado', 'NOM_ESTADO',
      'edo', 'EDO',
    ]);
    String? municipio = _pickFlexible(props, [
      'municipio', 'MUNICIPIO', 'mun', 'MUN',
      'localidad', 'LOCALIDAD', 'ciudad', 'CIUDAD',
      'municipality', 'MUNICIPALITY',
      'nombre_municipio', 'NOMBRE_MUNICIPIO',
      'nombre del municipio', 'NOMBRE DEL MUNICIPIO',
      'nom_municipio', 'NOM_MUNICIPIO',
      'mpio', 'MPIO', 'muni', 'MUNI',
    ]);

    if (estado != null && municipio != null) {
      return {'estado': estado, 'municipio': municipio};
    }

    final combinado = _pickFlexible(props, [
      'estado_municipio',
      'estado municipio',
      'estado/municipio',
      'municipio/estado',
      'estado_mpio',
      'edo_mun',
      'mun_edo',
      'edo/mun',
      'entidad_municipio',
      'estado y municipio',
      'edo-mun',
      'estado-municipio',
    ]);

    if (combinado != null) {
      final parts = combinado
          .split(RegExp(r'\s*(?:/|,|\||;|-|–|—)\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      if (parts.length >= 2) {
        final firstLooksEstado = _looksLikeEstadoName(parts[0]);
        final secondLooksEstado = _looksLikeEstadoName(parts[1]);

        if (estado == null && municipio == null) {
          if (firstLooksEstado && !secondLooksEstado) {
            estado = parts[0];
            municipio = parts[1];
          } else if (!firstLooksEstado && secondLooksEstado) {
            estado = parts[1];
            municipio = parts[0];
          } else {
            estado = parts[0];
            municipio = parts[1];
          }
        } else {
          if (estado == null) {
            estado = firstLooksEstado ? parts[0] : (secondLooksEstado ? parts[1] : parts[0]);
          }
          if (municipio == null) {
            municipio = firstLooksEstado ? parts[1] : (secondLooksEstado ? parts[0] : parts[1]);
          }
        }
      }
    }

    final inferidoDesdeClave = _inferEstadoMunicipioDesdeClave(_extractId(props));
    estado ??= inferidoDesdeClave['estado'];
    municipio ??= inferidoDesdeClave['municipio'];

    return {'estado': estado, 'municipio': municipio};
  }

  Map<String, String?> _inferEstadoMunicipioDesdeClave(String? clave) {
    if (clave == null) return {'estado': null, 'municipio': null};

    final upper = clave.trim().toUpperCase();
    if (upper.isEmpty) return {'estado': null, 'municipio': null};

    final tokens = upper
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return {'estado': null, 'municipio': null};

    final code = tokens.length >= 2 ? tokens[1] : '';
    const municipiosTsnl = {
      'SLV': 'Salinas Victoria',
      'VIL': 'Villaldama',
      'BUS': 'Bustamante',
      'LAM': 'Lampazos de Naranjo',
      'ANA': 'Anahuac',
      'SAB': 'Sabinas Hidalgo',
    };

    final isTsnl = upper.startsWith('SNL') || upper.startsWith('TSNL');
    final municipio = municipiosTsnl[code];

    return {
      'estado': isTsnl ? 'Nuevo Leon' : null,
      'municipio': municipio,
    };
  }

  bool _looksLikeEstadoName(String value) {
    final compact = _normalizeKey(value);
    const estados = {
      'aguascalientes',
      'bajacalifornia',
      'bajacaliforniasur',
      'campeche',
      'chiapas',
      'chihuahua',
      'ciudaddemexico',
      'coahuila',
      'coahuiladezaragoza',
      'colima',
      'durango',
      'estadodemexico',
      'guanajuato',
      'guerrero',
      'hidalgo',
      'jalisco',
      'michoacan',
      'michoacandeocampo',
      'morelos',
      'nayarit',
      'nuevoleon',
      'oaxaca',
      'puebla',
      'queretaro',
      'quintanaroo',
      'sanluispotosi',
      'sinaloa',
      'sonora',
      'tabasco',
      'tamaulipas',
      'tlaxcala',
      'veracruz',
      'veracruzdeignaciodelallave',
      'yucatan',
      'zacatecas',
    };
    return estados.contains(compact);
  }

  String? _resolveProyecto(Map<String, dynamic> props) {
    final detectado = GeoJsonMapper.detectarProyecto(props);
    if (detectado != null) return detectado;

    final fromClave = GeoJsonMapper.inferProyectoDesdeClave(_extractId(props));
    if (fromClave != null) return fromClave;

    return _pickFlexible(props, [
      'proyecto',
      'PROYECTO',
      'nombre_proyecto',
      'NOMBRE_PROYECTO',
      'tramo_proyecto',
      'TRAMO_PROYECTO',
      'codigo_proyecto',
      'CODIGO_PROYECTO',
      'obra',
      'OBRA',
    ]);
  }

  String? _resolveTipoPropiedad(Map<String, dynamic> props) {
    final directo = _pickFlexible(props, [
      'tipo_propiedad', 'TIPO_PROPIEDAD',
      'tipopropiedad',
      'TIPO DE PROPIEDAD', 'tipo de propiedad',
      'tipo propiedad', 'TIPO PROPIEDAD',
      'tipo_de_propiedad', 'TIPO_DE_PROPIEDAD',
      'regimen', 'REGIMEN',
      'tenencia', 'TENENCIA',
      'tipo_tenencia', 'TIPO_TENENCIA',
      'clase_propiedad', 'CLASE_PROPIEDAD',
      'clasificacion_propiedad', 'CLASIFICACION_PROPIEDAD',
      'tipo', 'TIPO',
    ]);
    if (directo != null) return _normalizeTipoPropiedad(directo);

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      final keyLooksLikeTipo = key.contains('tipoprop') ||
          key.contains('propiedad') ||
          key.contains('regimen') ||
          key.contains('tenencia');
      if (!keyLooksLikeTipo) continue;
      final v = entry.value?.toString().trim();
      if (v == null || v.isEmpty || _invalidValues.contains(v.toLowerCase())) continue;
      return _normalizeTipoPropiedad(v);
    }

    return _normalizeTipoPropiedad(null);
  }

  String? _pickPropietarioFlexible(Map<String, dynamic> props) {
    final directo = _pick(props, [
      'propietario_nombre', 'PROPIETARIO_NOMBRE',
      'propietario', 'PROPIETARIO',
      'nombre_propietario', 'nom_propietario', 'NOM_PROPIETARIO',
      'titular', 'TITULAR',
      'razon_social', 'RAZON_SOCIAL',
      'dueno', 'dueño', 'owner',
    ]);
    if (directo != null) return directo;

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      final keyLooksLikeOwner = key.contains('propiet') ||
          key.contains('titular') ||
          key.contains('dueno') ||
          key.contains('owner') ||
          key.contains('benefici') ||
          key.contains('razonsocial') ||
          key.contains('nombreprop') ||
          key.contains('nomprop');
      if (!keyLooksLikeOwner) continue;
      final v = entry.value?.toString().trim();
      if (v == null || v.isEmpty || v == 'null') continue;
      final looksLikeId = RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(v);
      if (looksLikeId) continue;
      return v;
    }

    final nombre = _pick(props, ['nombre', 'NOMBRE']);
    if (nombre != null && !RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(nombre)) {
      return nombre;
    }

    return null;
  }

  String _normalizeKey(String input) {
    var s = input.toLowerCase();
    const replacements = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        final shouldRetry = attempt < _maxRetryAttempts && _isRetryableError(e);
        if (!shouldRetry) rethrow;
        await Future.delayed(_retryDelay(attempt));
      }
    }

    throw Exception('$operationName fallo tras $_maxRetryAttempts intentos: $lastError');
  }

  bool _isRetryableError(Object error) {
    final msg = error.toString().toLowerCase();
    const retryableHints = [
      'timeout', 'timed out', 'socket', 'network', 'connection',
      'failed to fetch', 'fetch failed', 'could not connect', 'connection refused',
      '429', '500', '502', '503', '504', 'sheets get fallo', 'sheets post fallo',
    ];
    return retryableHints.any(msg.contains);
  }

  Duration _retryDelay(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final ms = _baseRetryDelayMs * multiplier;
    return Duration(milliseconds: ms);
  }

  /// Extrae todos los datos disponibles de las properties para crear/actualizar
  /// un predio en la BD, mapeando los alias más comunes de archivos GeoJSON.
  Map<String, dynamic> _buildNuevoPredioData(
    String claveCatastral,
    Map<String, dynamic> props,
    Map<String, dynamic>? geometry, {
    Map<String, dynamic>? propsOriginal,
  }) {
    final estadoMunicipio = _resolveEstadoMunicipio(props);

    // Extraer superficie con más aliases
    final superficie = _pickDoubleFlexible(props, [
      'superficie', 'SUPERFICIE',
      'area', 'AREA', 'Area',
      'shape_area', 'SHAPE_AREA',
      'area_ha', 'AREA_HA',
      'area_m2', 'AREA_M2',
      'superficie_m2', 'SUPERFICIE_M2',
      'm2', 'M2',
    ]);

    // Extraer km_inicio con más aliases
    final kmInicio = _pickDoubleFlexible(props, [
      'km_inicio', 'KM_INICIO',
      'km inicio', 'KM INICIO',
      'km iniicio', 'KM INIICIO',
      'cadenamiento_inicial', 'CADENAMIENTO_INICIAL',
      'cad_ini', 'CAD_INI',
      'km_i', 'KM_I',
      'km_ini', 'KM_INI',
      'km0', 'KM0',
      'cadenamiento_i', 'CADENAMIENTO_I',
      'km_inicial', 'KM_INICIAL',
    ]);

    // Extraer km_fin con más aliases
    final kmFin = _pickDoubleFlexible(props, [
      'km_fin', 'KM_FIN',
      'km fin', 'KM FIN',
      'cadenamiento_final', 'CADENAMIENTO_FINAL',
      'cad_fin', 'CAD_FIN',
      'km_f', 'KM_F',
      'km1', 'KM1',
      'cadenamiento_f', 'CADENAMIENTO_F',
      'cadenamiento_1',
      'km_final', 'KM_FINAL',
    ]);

    final kmLineales = _pickDoubleFlexible(props, [
      'km_lineales', 'KM_LINEALES',
      'km lineales', 'KM LINEALES',
      'longitud_km', 'LONGITUD_KM',
      'longitud', 'LONGITUD',
      'km', 'KM',
    ]);

    // Extraer km_efectivos con más aliases
    final kmEfectivos = _pickDoubleFlexible(props, [
      'km_efectivos', 'KM_EFECTIVOS',
      'km efectivos', 'KM EFECTIVOS',
      'km_efectivo', 'KM_EFECTIVO',
      'km_e', 'KM_E',
      'longitud_efectiva', 'LONGITUD_EFECTIVA',
      'longitud efectiva', 'LONGITUD EFECTIVA',
      'kme', 'KME',
    ]);

    final valorCatastral = _toDouble(
      props['valor_catastral'] ?? props['VALOR_CATASTRAL'] ??
      props['valor'] ?? props['VALOR'] ?? props['avaluo'] ?? props['AVALUO'],
    ) ;

    final data = <String, dynamic>{
      // ── Identificación ──────────────────────────────────────────────────
      'clave_catastral': claveCatastral,

      // ── Clasificación ───────────────────────────────────────────────────
      'tramo': _pick(props, [
        'tramo', 'TRAMO', 'tramo_vial', 'seccion',
        'frente', 'FRENTE', 'segmento', 'SEGMENTO',
        't_f_s', 'T_F_S', 'tipofs', 'TIPO_FS',
      ]) ?? '',
      'tipo_propiedad': _resolveTipoPropiedad(props),
      'estructura': _pickFlexible(props, [
        'estructura', 'ESTRUCTURA',
        'tipo_estructura', 'TIPO_ESTRUCTURA',
        'clase_estructura', 'CLASE_ESTRUCTURA',
        'estruc', 'ESTRUC',
      ]),
      'ejido': _pick(props, [
        'ejido', 'nom_ejido', 'nombre_ejido', 'NOM_EJIDO', 'EJIDO',
        'comunidad', 'localidad',
      ]),
      'proyecto': _resolveProyecto(props),
      'uso_suelo': _pick(props, [
        'uso_suelo', 'USO_SUELO', 'uso', 'USO', 'land_use', 'LAND_USE',
      ]) ?? 'Otro',
      'zona': _pick(props, ['zona', 'ZONA', 'sector', 'SECTOR', 'region', 'REGION']),
      'valor_catastral': valorCatastral,
      'descripcion': _pick(props, [
        'descripcion', 'DESCRIPCION', 'description', 'DESCRIPTION',
      ]),
      'situacion_social': _pickFlexible(props, [
        'situacion_social', 'SITUACION_SOCIAL',
        'observaciones', 'OBSERVACIONES',
        'observacion', 'OBSERVACION',
        'obs', 'OBS',
      ]),
      'direccion': _pick(props, ['direccion', 'DIRECCION', 'domicilio', 'DOMICILIO', 'calle', 'CALLE']),
      'colonia': _pick(props, ['colonia', 'COLONIA', 'barrio', 'BARRIO']),
      'municipio': estadoMunicipio['municipio'],
      'estado': estadoMunicipio['estado'],
      'codigo_postal': _pick(props, ['codigo_postal', 'CODIGO_POSTAL', 'cp', 'CP']),
      'imagen_url': _pick(props, ['imagen_url', 'IMAGEN_URL', 'foto_url', 'FOTO_URL', 'image_url', 'IMAGE_URL']),

      // ── Propietario (nombre directo) ─────────────────────────────────────
      'propietario_nombre': _pick(props, [
        'propietario', 'propietario_nombre', 'nombre_propietario',
        'nom_propietario', 'PROPIETARIO', 'titular', 'TITULAR',
        'dueno', 'dueño', 'nombre',
      ]) ?? _pickPropietarioFlexible(props),

      // ── Dimensiones / Geometría ──────────────────────────────────────────
      'superficie': superficie,
      'km_inicio': kmInicio,
      'km_fin': kmFin,
      'km_lineales': kmLineales,
      'km_efectivos': kmEfectivos,

      // ── Coordenadas ──────────────────────────────────────────────────────
      'latitud': _toDouble(
        props['latitud'] ?? props['lat'] ?? props['LAT'] ?? props['latitude'],
      ),
      'longitud': _toDouble(
        props['longitud'] ?? props['lon'] ?? props['lng'] ?? props['LON'] ??
        props['longitude'],
      ),

      // ── Geometría ────────────────────────────────────────────────────────
      'geometry': geometry,
      'poligono_insertado': geometry != null,

      // ── Gestión (estado inicial) ─────────────────────────────────────────
      // Convierte valores booleanos o strings a boolean
      'cop': _toBool(props['cop']),
      'identificacion': _toBool(props['identificacion']),
      'levantamiento': _toBool(props['levantamiento']),
      'negociacion': _toBool(props['negociacion']),

      // ── Tipo de Liberación ───────────────────────────────────────────────
      'tipo_liberacion': _pickFlexible(props, [
        'tipo_liberacion', 'TIPO_LIBERACION',
        'tipo liberacion', 'TIPO LIBERACION',
        'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
        'tipo de liberacion', 'TIPO DE LIBERACION',
        'liberacion', 'LIBERACION',
        'tipo_liber', 'TIPO_LIBER',
        'liberacion_tipo', 'LIBERACION_TIPO',
        'tipo_release', 'TIPO_RELEASE',
      ]),
    };

    // Eliminar claves con valor null para no pisar datos existentes
    data.removeWhere((k, v) => v == null);
    
    // Incluir TODAS las propiedades originales del GeoJSON que no estén ya en data
    if (propsOriginal != null) {
      for (final entry in propsOriginal.entries) {
        final key = entry.key;
        if (!data.containsKey(key) && entry.value != null) {
          final valueStr = entry.value.toString().trim();
          if (valueStr.isNotEmpty && valueStr.toLowerCase() != 'null') {
            data[key] = entry.value;
          }
        }
      }
    }
    return data;
  }

  /// Extrae datos del propietario desde las properties del feature.
  Map<String, dynamic> _buildPropietarioData(Map<String, dynamic> props) {
    final nombreCompleto = _pick(props, [
      'propietario', 'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'PROPIETARIO', 'titular', 'nombre',
    ]) ?? '';

    final parts = nombreCompleto.trim().split(' ');
    final nombre = parts.isNotEmpty ? parts.first : '';
    final apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final razonSocial = _pick(props, [
      'razon_social', 'RAZON_SOCIAL', 'empresa', 'denominacion', 'EMPRESA',
    ]);

    final tipoPersona = (razonSocial != null ||
            nombreCompleto.contains('S.A.') ||
            nombreCompleto.contains('S.DE R.L.') ||
            nombreCompleto.contains('SAPI') ||
            nombreCompleto.contains('SAS'))
        ? 'moral'
        : 'fisica';

    final data = <String, dynamic>{
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (razonSocial case final rs?) 'razon_social': rs,
      if (_pick(props, ['rfc', 'RFC']) != null)
        'rfc': _pick(props, ['rfc', 'RFC']),
      if (_pick(props, ['curp', 'CURP']) != null)
        'curp': _pick(props, ['curp', 'CURP']),
      if (_pick(props, ['telefono', 'tel', 'TEL', 'phone', 'TELEFONO']) != null)
        'telefono': _pick(props, ['telefono', 'tel', 'TEL', 'phone', 'TELEFONO']),
      if (_pick(props, ['correo', 'email', 'EMAIL', 'correo_electronico']) != null)
        'correo': _pick(props, ['correo', 'email', 'EMAIL', 'correo_electronico']),
    };

    return data;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;

      // Soporta cadenamiento tipo 12+345 => 12.345
      final kmMatch = RegExp(r'(-?\d+)\s*\+\s*(\d+)').firstMatch(trimmed);
      if (kmMatch != null) {
        final base = double.tryParse(kmMatch.group(1)!);
        final meters = double.tryParse(kmMatch.group(2)!);
        if (base != null && meters != null) {
          return base + (meters / 1000.0);
        }
      }

      var normalized = trimmed.replaceAll(' ', '');
      if (normalized.contains(',') && !normalized.contains('.')) {
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
      normalized = normalized.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(normalized);
    }
    return null;
  }

  /// Convierte valores a boolean para campos de gestión
  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final upper = v.toUpperCase().trim();
      if (upper == 'SI' || upper == 'YES' || upper == 'S' || upper == 'Y' || 
          upper == 'TRUE' || upper == '1' || upper == 'X' ||
          upper == 'COMPLETADO' || upper == 'COMPLETE' || 
          upper == 'LIBERADO' || upper == 'LIBERADA' ||
          upper == 'IDENTIFICADO' || upper == 'LEVANTADO' || upper == 'NEGOCIADO') {
        return true;
      }
      if (upper == 'NO' || upper == 'FALSE' || upper == '0' || upper == '-' || upper.isEmpty) {
        return false;
      }
    }
    return false;
  }

  /// Normaliza el valor de tipo_propiedad a los valores válidos del sistema
  String? _normalizeTipoPropiedad(String? value) {
    if (value == null) return 'PRIVADA';
    final upper = value.toUpperCase().trim();
    final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.contains('SOC')) return 'SOCIAL';
    if (compact.contains('DOMINIOPLENO') || (compact.contains('DOMINIO') && compact.contains('PLENO'))) return 'DOMINIO PLENO';
    if (upper.contains('EJI')) return 'EJIDAL';
    if (upper.contains('MIX')) return 'MIXTO';
    if (upper.contains('FEDERAL')) return 'FEDERAL';
    if (upper.contains('GUBERNAMENTAL') || upper.contains('GUBERNAM') || upper.contains('GOBIERNO')) return 'GUBERNAMENTAL';
    if (compact.contains('PRIVAD') || compact == 'PRI') return 'PRIVADA';
    return upper.isEmpty ? 'PRIVADA' : upper;
  }

  /// Construye los campos de Gestión para ACTUALIZAR un predio existente.
  Map<String, dynamic> _buildGestionUpdateData(
    Map<String, dynamic> props,
    Map<String, dynamic>? geometry,
    Map<String, dynamic> existente,
  ) {
    final updates = <String, dynamic>{};
    final estadoMunicipio = _resolveEstadoMunicipio(props);

    void trySet(String dbKey, dynamic newValue, {bool overwrite = false}) {
      if (newValue == null) return;
      if (newValue is String && newValue.trim().isEmpty) return;
      final cur = existente[dbKey];

      if (overwrite) {
        if (cur != newValue) {
          updates[dbKey] = newValue;
        }
        return;
      }

      if (cur == null || (cur is String && cur.trim().isEmpty)) {
        updates[dbKey] = newValue;
      }
    }

    trySet('tramo',      _pick(props, ['tramo', 'TRAMO', 'tramo_vial', 'seccion', 'SECCION']));
    trySet('tipo_propiedad', _resolveTipoPropiedad(props), overwrite: true);
    trySet('estructura', _pickFlexible(props, [
      'estructura', 'ESTRUCTURA',
      'tipo_estructura', 'TIPO_ESTRUCTURA',
      'clase_estructura', 'CLASE_ESTRUCTURA',
      'estruc', 'ESTRUC',
    ]), overwrite: true);
    trySet('ejido',      _pick(props, ['ejido', 'EJIDO', 'nom_ejido', 'NOM_EJIDO', 'comunidad', 'localidad']));
    trySet('proyecto',   _resolveProyecto(props));
    trySet('propietario_nombre', _pick(props, [
      'propietario', 'PROPIETARIO', 'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'NOM_PROPIETARIO', 'titular', 'TITULAR', 'dueno', 'nombre',
    ]) ?? _pickPropietarioFlexible(props));
    trySet('superficie',    _toDouble(props['superficie']    ?? props['SUPERFICIE']    ?? props['area'] ?? props['AREA'] ?? props['shape_area'] ?? props['SHAPE_AREA'] ?? props['superficie_m2'] ?? props['m2'] ?? props['Area']));
    trySet('uso_suelo',     _pick(props, ['uso_suelo', 'USO_SUELO', 'uso', 'USO', 'land_use', 'LAND_USE']) ?? 'Otro');
    trySet('zona',          _pick(props, ['zona', 'ZONA', 'sector', 'SECTOR', 'region', 'REGION']));
    trySet('valor_catastral', _toDouble(props['valor_catastral'] ?? props['VALOR_CATASTRAL'] ?? props['valor'] ?? props['VALOR'] ?? props['avaluo'] ?? props['AVALUO']));
    trySet('descripcion',   _pick(props, ['descripcion', 'DESCRIPCION', 'description', 'DESCRIPTION']));
    trySet('situacion_social', _pickFlexible(props, [
      'situacion_social', 'SITUACION_SOCIAL',
      'observaciones', 'OBSERVACIONES',
      'observacion', 'OBSERVACION',
      'obs', 'OBS',
    ]), overwrite: true);
    trySet('direccion',     _pick(props, ['direccion', 'DIRECCION', 'domicilio', 'DOMICILIO', 'calle', 'CALLE']));
    trySet('colonia',       _pick(props, ['colonia', 'COLONIA', 'barrio', 'BARRIO']));
    trySet('municipio',     estadoMunicipio['municipio'], overwrite: true);
    trySet('estado',        estadoMunicipio['estado'], overwrite: true);
    trySet('codigo_postal', _pick(props, ['codigo_postal', 'CODIGO_POSTAL', 'cp', 'CP']));
    trySet('km_inicio',     _pickDoubleFlexible(props, [
      'km_inicio', 'KM_INICIO', 'km inicio', 'KM INICIO',
      'km iniicio', 'KM INIICIO',
      'cadenamiento_inicial', 'CADENAMIENTO_INICIAL', 'cad_ini', 'CAD_INI',
      'km_i', 'KM_I', 'km_ini', 'KM_INI', 'km0', 'KM0',
      'cadenamiento_i', 'CADENAMIENTO_I', 'km_inicial', 'KM_INICIAL',
    ]), overwrite: true);
    trySet('km_fin',        _pickDoubleFlexible(props, [
      'km_fin', 'KM_FIN', 'km fin', 'KM FIN',
      'cadenamiento_final', 'CADENAMIENTO_FINAL', 'cad_fin', 'CAD_FIN',
      'km_f', 'KM_F', 'km1', 'KM1', 'cadenamiento_f', 'CADENAMIENTO_F',
      'cadenamiento_1', 'km_final', 'KM_FINAL',
    ]), overwrite: true);
    trySet('km_lineales',   _pickDoubleFlexible(props, [
      'km_lineales', 'KM_LINEALES', 'km lineales', 'KM LINEALES',
      'longitud_km', 'LONGITUD_KM', 'longitud', 'LONGITUD', 'km', 'KM',
    ]), overwrite: true);
    trySet('km_efectivos',  _pickDoubleFlexible(props, [
      'km_efectivos', 'KM_EFECTIVOS', 'km efectivos', 'KM EFECTIVOS',
      'km_efectivo', 'KM_EFECTIVO', 'km_e', 'KM_E',
      'longitud_efectiva', 'LONGITUD_EFECTIVA', 'longitud efectiva', 'LONGITUD EFECTIVA',
      'kme', 'KME',
    ]), overwrite: true);

    // Campos booleanos de gestión
    trySet('identificacion', _toBool(_pickFlexible(props, [
      'identificacion', 'IDENTIFICACION',
      'identificación', 'IDENTIFICACIÓN',
      'identificado', 'IDENTIFICADO',
    ])), overwrite: true);
    trySet('levantamiento', _toBool(_pickFlexible(props, [
      'levantamiento', 'LEVANTAMIENTO',
      'levantado', 'LEVANTADO',
    ])), overwrite: true);
    trySet('negociacion', _toBool(_pickFlexible(props, [
      'negociacion', 'NEGOCIACION',
      'negociación', 'NEGOCIACIÓN',
      'negociado', 'NEGOCIADO',
    ])), overwrite: true);
    trySet('cop', _toBool(_pickFlexible(props, [
      'cop', 'COP',
      'estatus', 'ESTATUS',
      'status', 'STATUS',
      'liberado', 'LIBERADO',
      'liberada', 'LIBERADA',
      'anuencia', 'ANUENCIA',
    ])), overwrite: true);

    // Tipo de liberación
    trySet('tipo_liberacion', _pickFlexible(props, [
      'tipo_liberacion', 'TIPO_LIBERACION',
      'tipo liberacion', 'TIPO LIBERACION',
      'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
      'tipo de liberacion', 'TIPO DE LIBERACION',
      'liberacion', 'LIBERACION',
      'tipo_liber', 'TIPO_LIBER',
      'liberacion_tipo', 'LIBERACION_TIPO',
      'tipo_release', 'TIPO_RELEASE',
    ]), overwrite: true);

    if (geometry != null && existente['geometry'] == null) {
      updates['geometry']           = geometry;
      updates['poligono_insertado'] = true;
    }
    return updates;
  }

  /// Procesa todos los features del archivo GeoJSON de forma asíncrona.
  Future<SincronizacionResultado> sincronizar(
    List<Map<String, dynamic>> features, {
    int concurrency = _defaultSyncConcurrency,
    void Function(int procesados, int total)? onProgress,
  }) async {
    if (features.isEmpty) {
      return const SincronizacionResultado(
        resultados: [],
        encontrados: 0,
        creados: 0,
        errores: 0,
      );
    }

    final resultadosByIndex = <int, FeatureSyncResult>{};
    final mensajesError = <String>[];
    final predioByClaveCache = <String, Map<String, dynamic>?>{};
    var encontrados = 0;
    var creados = 0;
    var errores = 0;
    var procesados = 0;

    onProgress?.call(0, features.length);

    final lanes = _buildLanes(features, concurrency);
    await Future.wait(
      lanes.map(
        (lane) => _processLane(
          lane,
          predioByClaveCache: predioByClaveCache,
          onOutcome: (outcome) {
            resultadosByIndex[outcome.featureIndex] = outcome.result;
            encontrados += outcome.encontrados;
            creados += outcome.creados;
            errores += outcome.errores;
            procesados += 1;
            onProgress?.call(procesados, features.length);

            for (final msg in outcome.mensajesError) {
              if (mensajesError.length >= 5) break;
              mensajesError.add(msg);
            }
          },
        ),
      ),
    );

    onProgress?.call(features.length, features.length);

    final resultados = <FeatureSyncResult>[];
    for (var i = 0; i < features.length; i++) {
      final item = resultadosByIndex[i];
      if (item != null) {
        resultados.add(item);
      }
    }

    return SincronizacionResultado(
      resultados: resultados,
      encontrados: encontrados,
      creados: creados,
      errores: errores,
      mensajesError: mensajesError,
    );
  }

  List<List<MapEntry<int, Map<String, dynamic>>>> _buildLanes(
    List<Map<String, dynamic>> features,
    int requestedConcurrency,
  ) {
    final safeConcurrency = requestedConcurrency.clamp(1, _maxSyncConcurrency);
    final laneCount = safeConcurrency > features.length
        ? features.length
        : safeConcurrency;

    final lanes = List.generate(
      laneCount,
      (_) => <MapEntry<int, Map<String, dynamic>>>[],
    );

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final lane = _laneForFeature(feature, i, laneCount);
      lanes[lane].add(MapEntry(i, feature));
    }

    return lanes;
  }

  int _laneForFeature(
    Map<String, dynamic> feature,
    int fallbackIndex,
    int laneCount,
  ) {
    final rawProps = feature['properties'];
    final propsOriginal = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
    final props = GeoJsonMapper.normalizeProperties(propsOriginal);
    final clave = _extractId(props)?.trim();

    if (clave != null && clave.isNotEmpty) {
      return clave.hashCode.abs() % laneCount;
    }

    return fallbackIndex % laneCount;
  }

  Future<void> _processLane(
    List<MapEntry<int, Map<String, dynamic>>> lane, {
    required Map<String, Map<String, dynamic>?> predioByClaveCache,
    required void Function(_FeatureSyncOutcome outcome) onOutcome,
  }) async {
    for (final item in lane) {
      final outcome = await _processFeature(
        item.key,
        item.value,
        predioByClaveCache: predioByClaveCache,
      );
      onOutcome(outcome);
    }
  }

  Future<_FeatureSyncOutcome> _processFeature(
    int featureIndex,
    Map<String, dynamic> feature, {
    required Map<String, Map<String, dynamic>?> predioByClaveCache,
  }) async {
    final featureNumber = featureIndex + 1;

    try {
      final rawProps = feature['properties'];
      final propsOriginal = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};
      final props = GeoJsonMapper.normalizeProperties(propsOriginal);
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : null;
      final clave = _extractId(props);

      // Siempre intentar procesar el feature, sin importar si tiene clave o no
      String? claveNormalizada;
      Map<String, dynamic>? existente;

      if (clave != null && clave.trim().isNotEmpty) {
        final claveLookup = clave.trim();
        claveNormalizada = claveLookup;
        
        if (predioByClaveCache.containsKey(claveLookup)) {
          existente = predioByClaveCache[claveLookup];
        } else {
          try {
            existente = await _withRetry(
              () => _prediosRepo.buscarPorClaveCatastral(claveLookup),
              operationName: 'buscarPorClaveCatastral',
            );
          } catch (_) {
            // Si falla la búsqueda, continuar como si no existiera
            existente = null;
          }
          predioByClaveCache[claveLookup] = existente;
        }

        // Si existe, actualizar
        if (existente != null) {
          var existenteActual = existente;
          final updateData = _buildGestionUpdateData(
            props,
            geometry,
            existenteActual,
          );

          if (updateData.isNotEmpty) {
            try {
              final updated = await _withRetry(
                () => _prediosRepo.updatePredio(
                  existenteActual['id'] as String,
                  updateData,
                ),
                operationName: 'updatePredio',
              );
              final propietariosRaw = existenteActual['propietarios'];
              existenteActual = updated.toMap()
                ..['id'] = updated.id
                ..['propietarios'] = propietariosRaw;
              predioByClaveCache[claveNormalizada] = existenteActual;
            } catch (_) {
              // Si falla el update, continuar con los datos existentes.
            }
          }

          final enrichedProps = _injectData(props, existenteActual);
          return _FeatureSyncOutcome(
            featureIndex: featureIndex,
            result: FeatureSyncResult(
              feature: {
                ...feature,
                'properties': enrichedProps,
              },
              existia: true,
              predioId: existenteActual['id'] as String?,
            ),
            encontrados: 1,
            creados: 0,
            errores: 0,
          );
        }
      }

      // Si no hay clave o no existe, crear nuevo registro
      final nuevaClave = claveNormalizada ?? 'IMP-${DateTime.now().microsecondsSinceEpoch}-$featureNumber';
      final predioData = _buildNuevoPredioData(nuevaClave, props, geometry, propsOriginal: propsOriginal);

      final nombreProp = predioData['propietario_nombre'] as String?;
      if (nombreProp != null && nombreProp.isNotEmpty) {
        try {
          final propData = _buildPropietarioData(props);
          final propietario = await _withRetry(
            () => _propietariosRepo.findOrCreateFromData(propData),
            operationName: 'findOrCreatePropietario',
          );
          predioData['propietario_id'] = propietario.id;
        } catch (_) {
          // No bloquear la creación del predio si el propietario falla.
        }
      }

      final nuevoPredio = await _withRetry(
        () => _prediosRepo.createPredio(predioData),
        operationName: 'createPredio',
      );

      final nuevoMap = nuevoPredio.toMap()
        ..['id'] = nuevoPredio.id
        ..['created_at'] = nuevoPredio.createdAt.toIso8601String();
      predioByClaveCache[nuevaClave.trim()] = nuevoMap;

      final enrichedProps = _injectData(props, nuevoMap);
      enrichedProps['_predioNuevo'] = true;

      return _FeatureSyncOutcome(
        featureIndex: featureIndex,
        result: FeatureSyncResult(
          feature: {
            ...feature,
            'properties': enrichedProps,
          },
          existia: false,
          predioId: nuevoPredio.id,
        ),
        encontrados: 0,
        creados: 1,
        errores: 0,
      );
    } catch (e) {
      final featureError = 'Feature $featureNumber: ${e.toString()}';

      try {
        final rawProps = feature['properties'];
        final propsOriginal = rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};
        final props = GeoJsonMapper.normalizeProperties(propsOriginal);
        final geometry = feature['geometry'] is Map
            ? Map<String, dynamic>.from(feature['geometry'] as Map)
            : null;
        final clave = _extractId(props) ??
            'IMP-${DateTime.now().microsecondsSinceEpoch}-$featureNumber';

        // Extraer y normalizar el tipo de propiedad del archivo GeoJSON
        final tipoPropiedad = _resolveTipoPropiedad(props);

        final minData = <String, dynamic>{
          'clave_catastral': clave,
          'tramo': '',
          'tipo_propiedad': tipoPropiedad,
          if (_resolveProyecto(props) case final proyecto?) 'proyecto': proyecto,
          if (geometry != null) 'geometry': geometry,
          if (geometry != null) 'poligono_insertado': true,
          'cop': false,
          'identificacion': false,
          'levantamiento': false,
          'negociacion': false,
        };

        final nuevoPredio = await _withRetry(
          () => _prediosRepo.createPredio(minData),
          operationName: 'createPredioMinimo',
        );

        final nuevoMap = nuevoPredio.toMap()
          ..['id'] = nuevoPredio.id
          ..['created_at'] = nuevoPredio.createdAt.toIso8601String();
        predioByClaveCache[clave.trim()] = nuevoMap;

        final enrichedProps = _injectData(props, nuevoMap);
        enrichedProps['_predioNuevo'] = true;

        return _FeatureSyncOutcome(
          featureIndex: featureIndex,
          result: FeatureSyncResult(
            feature: {
              ...feature,
              'properties': enrichedProps,
            },
            existia: false,
            predioId: nuevoPredio.id,
          ),
          encontrados: 0,
          creados: 1,
          errores: 0,
          mensajesError: [featureError],
        );
      } catch (e2) {
        final minError = 'Feature $featureNumber (min): ${e2.toString()}';
        final rawProps = feature['properties'];
        final propsConError = rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};
        propsConError['_syncStatus'] = 'error';
        propsConError['_syncSource'] = 'geojson_import';
        propsConError['_syncAt'] = DateTime.now().toIso8601String();
        propsConError['_syncError'] = e2.toString();

        return _FeatureSyncOutcome(
          featureIndex: featureIndex,
          result: FeatureSyncResult(
            feature: {
              ...feature,
              'properties': propsConError,
            },
            existia: false,
          ),
          encontrados: 0,
          creados: 0,
          errores: 1,
          mensajesError: [featureError, minError],
        );
      }
    }
  }
}

final sincronizacionServiceProvider = Provider<SincronizacionService>((ref) {
  return SincronizacionService(
    ref.read(prediosRepositoryProvider),
    ref.read(propietariosRepositoryProvider),
  );
});
