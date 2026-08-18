import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/import_normalization.dart' as norm;
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
      'nom_ent', 'NOM_ENT',
      'nombre_ent', 'NOMBRE_ENT',
      'nom_edo', 'NOM_EDO',
      'entidad_nombre', 'ENTIDAD_NOMBRE',
      'estado_nombre', 'ESTADO_NOMBRE',
      'cve_ent', 'CVE_ENT',
    ]);
    String? municipio = _pickFlexible(props, [
      'municipio', 'MUNICIPIO', 'mun', 'MUN',
      'localidad', 'LOCALIDAD', 'ciudad', 'CIUDAD',
      'municipality', 'MUNICIPALITY',
      'nombre_municipio', 'NOMBRE_MUNICIPIO',
      'nombre del municipio', 'NOMBRE DEL MUNICIPIO',
      'nom_municipio', 'NOM_MUNICIPIO',
      'mpio', 'MPIO', 'muni', 'MUNI',
      'nom_mun', 'NOM_MUN',
      'cve_mun', 'CVE_MUN',
      'municipio_nombre', 'MUNICIPIO_NOMBRE',
      'nom_loc', 'NOM_LOC',
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

    // NOTA: aquí NO se infiere estado/municipio a partir del prefijo de la
    // clave catastral -esa auto-detección solo acertaba para TSNL con un
    // puñado de códigos de municipio y dejaba el resto de predios sin
    // completar, generando inconsistencia-. Solo se inyecta lo que
    // realmente venga en el archivo importado.
    return {'estado': estado, 'municipio': municipio};
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

    return norm.normalizeCode(_pickFlexible(props, [
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
    ]));
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

  bool _containsNestedArray(dynamic value) {
    if (value is List) {
      for (final item in value) {
        if (item is List) return true;
        if (_containsNestedArray(item)) return true;
      }
    } else if (value is Map) {
      for (final item in value.values) {
        if (_containsNestedArray(item)) return true;
      }
    }
    return false;
  }

  dynamic _sanitizeForFirestore(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }

    if (value is List) {
      // Firestore no soporta arrays anidados.
      if (_containsNestedArray(value)) {
        return jsonEncode(value);
      }
      return value.map(_sanitizeForFirestore).toList(growable: false);
    }

    if (value is Map) {
      // Si hay arrays anidados dentro del mapa, serializar completo a JSON.
      if (_containsNestedArray(value)) {
        return jsonEncode(value);
      }
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] = _sanitizeForFirestore(entry.value);
      }
      return out;
    }

    return value.toString();
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
      // '_pickFlexible' normaliza claves y alias (sin acentos/mayúsculas/
      // separadores) antes de comparar, para reconocer encabezados como
      // "T/F/S", "Tramo", "Segmento" o "Frente" sin importar el símbolo
      // exacto que use el archivo de origen.
      'tramo': norm.normalizeCode(_pickFlexible(props, [
        'tramo', 'TRAMO', 'tramo_vial', 'seccion',
        'frente', 'FRENTE', 'segmento', 'SEGMENTO',
        't_f_s', 'T_F_S', 'tfs', 'tipofs', 'TIPO_FS',
      ])) ?? 'S/T',
      'tipo_propiedad': _resolveTipoPropiedad(props),
      'estructura': norm.normalizeEstructura(_pickFlexible(props, [
        'estructura', 'ESTRUCTURA',
        'tipo_estructura', 'TIPO_ESTRUCTURA',
        'clase_estructura', 'CLASE_ESTRUCTURA',
        'estruc', 'ESTRUC',
      ])),
      // No todos los predios pertenecen a un ejido: "N/A"/"NO APLICA" se
      // reconocen y guardan como el marcador "N/A" en vez de perderse o
      // mancharse con capitalización de título.
      'ejido': norm.normalizeEjido(_pick(props, [
        'ejido', 'nom_ejido', 'nombre_ejido', 'NOM_EJIDO', 'EJIDO',
        'comunidad', 'localidad',
      ])),
      'proyecto': _resolveProyecto(props),
      'uso_suelo': norm.normalizeTitleCase(_pick(props, [
        'uso_suelo', 'USO_SUELO', 'uso', 'USO', 'land_use', 'LAND_USE',
      ])) ?? 'Otro',
      'zona': norm.normalizeTitleCase(_pick(props, ['zona', 'ZONA', 'sector', 'SECTOR', 'region', 'REGION'])),
      'valor_catastral': valorCatastral,
      'descripcion': norm.normalizeTitleCase(_pick(props, [
        'descripcion', 'DESCRIPCION', 'description', 'DESCRIPTION',
      ])),
      // Texto narrativo libre (observaciones): solo se recorta, no se
      // fuerza a Capitalización De Cada Palabra -leerían mal notas largas-.
      'situacion_social': _pickFlexible(props, [
        'situacion_social', 'SITUACION_SOCIAL',
        'observaciones', 'OBSERVACIONES',
        'observacion', 'OBSERVACION',
        'obs', 'OBS',
      ])?.trim(),
      'direccion': norm.normalizeTitleCase(_pick(props, ['direccion', 'DIRECCION', 'domicilio', 'DOMICILIO', 'calle', 'CALLE'])),
      'colonia': norm.normalizeTitleCase(_pick(props, ['colonia', 'COLONIA', 'barrio', 'BARRIO'])),
      'municipio': norm.normalizeTitleCase(estadoMunicipio['municipio']),
      'estado': norm.normalizeTitleCase(estadoMunicipio['estado']),
      'codigo_postal': _pick(props, ['codigo_postal', 'CODIGO_POSTAL', 'cp', 'CP']),
      'imagen_url': _pick(props, ['imagen_url', 'IMAGEN_URL', 'foto_url', 'FOTO_URL', 'image_url', 'IMAGE_URL']),

      // ── Propietario (nombre directo) ─────────────────────────────────────
      'propietario_nombre': norm.normalizeTitleCase(_pick(props, [
        'propietario', 'propietario_nombre', 'nombre_propietario',
        'nom_propietario', 'PROPIETARIO', 'titular', 'TITULAR',
        'dueno', 'dueño', 'nombre',
      ]) ?? _pickPropietarioFlexible(props)),

      // ── Dimensiones / Geometría ──────────────────────────────────────────
      'superficie': superficie,
      // Aceptan formato PK ("12+359") o decimal ("12.359") -misma distancia,
      // 12 km + 359 m-; siempre quedan guardados como el mismo número para
      // que Gestión los muestre consistentemente en formato PK.
      'km_inicio': norm.normalizeKmValue(_pickFlexible(props, [
        'km_inicio', 'KM_INICIO', 'km inicio', 'KM INICIO', 'km iniicio',
        'cadenamiento_inicial', 'CADENAMIENTO_INICIAL', 'cad_ini', 'CAD_INI',
        'km_i', 'KM_I', 'km_ini', 'KM_INI', 'km0', 'KM0',
        'cadenamiento_i', 'CADENAMIENTO_I', 'km_inicial', 'KM_INICIAL',
      ])),
      'km_fin': norm.normalizeKmValue(_pickFlexible(props, [
        'km_fin', 'KM_FIN', 'km fin', 'KM FIN',
        'cadenamiento_final', 'CADENAMIENTO_FINAL', 'cad_fin', 'CAD_FIN',
        'km_f', 'KM_F', 'km1', 'KM1', 'cadenamiento_f', 'CADENAMIENTO_F',
        'cadenamiento_1', 'km_final', 'KM_FINAL',
      ])),
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
      'geometry': geometry == null ? null : jsonEncode(geometry),
      'poligono_insertado': geometry != null,

      // ── Gestión (estado inicial) ─────────────────────────────────────────
      // Convierte valores booleanos o strings a boolean. Se usa
      // '_pickFlexible' (en vez de leer 'props[key]' directo) para
      // reconocer estas columnas sin importar acentos/mayúsculas/guiones en
      // el encabezado del archivo importado.
      'cop': _toBool(_pickFlexible(props, [
        'cop', 'COP', 'status', 'STATUS', 'liberado', 'LIBERADO',
        'liberada', 'LIBERADA', 'firmado', 'FIRMADO',
        'cop_firmado', 'COP_FIRMADO', 'anuencia', 'ANUENCIA',
      ])),
      'identificacion': _toBool(_pickFlexible(props, [
        'identificacion', 'IDENTIFICACION', 'identificado', 'IDENTIFICADO',
        'id_status', 'ID_STATUS', 'id_realizada', 'ID_REALIZADA',
      ])),
      'levantamiento': _toBool(_pickFlexible(props, [
        'levantamiento', 'LEVANTAMIENTO', 'levantado', 'LEVANTADO',
        'lev', 'LEV', 'lev_status', 'LEV_STATUS',
      ])),
      'negociacion': _toBool(_pickFlexible(props, [
        'negociacion', 'NEGOCIACION', 'negociado', 'NEGOCIADO',
        'neg', 'NEG', 'neg_status', 'NEG_STATUS',
      ])),

      // ── Tipo de Liberación ───────────────────────────────────────────────
      // Reconoce variantes con puntos/espacios/prefijos ("D.O.T.", "Posible
      // DOT") y las mapea al catálogo COP/DOT/AOP/EXPROPIACION; "No"/nulo
      // se registra como "Sin Tipo" en vez de perderse o guardarse crudo.
      'tipo_liberacion': () {
        final crudo = _pickFlexible(props, [
          'tipo_liberacion', 'TIPO_LIBERACION',
          'tipo liberacion', 'TIPO LIBERACION',
          'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
          'tipo de liberacion', 'TIPO DE LIBERACION',
          'liberacion', 'LIBERACION',
          'tipo_liber', 'TIPO_LIBER',
          'liberacion_tipo', 'LIBERACION_TIPO',
          'tipo_release', 'TIPO_RELEASE',
          'expropiacion', 'EXPROPIACION',
        ]);
        if (crudo == null) return null;
        return norm.normalizeTipoLiberacion(crudo);
      }(),

      // "Estatus"/"Rango de estatus" contra el catálogo de Gestión
      // (Liberado, Negociacion, Posible DOT, Instruccion UVSR, Con ingreso,
      // No liberado, L nueva).
      'rango_estatus': () {
        final crudo = _pickFlexible(props, [
          'rango_estatus', 'RANGO_ESTATUS',
          'rango de estatus', 'RANGO DE ESTATUS',
          'rango_de_estatus', 'RANGO_DE_ESTATUS',
          'estatus', 'ESTATUS',
          'estatus_predio', 'ESTATUS_PREDIO',
        ]);
        if (crudo == null) return null;
        return norm.normalizeRangoEstatus(crudo);
      }(),

      // "Fecha de liberación" (COP/DOT): puede venir del archivo importado
      // en vez de capturarse manualmente. Acepta ISO, dd/mm/aaaa y
      // dd-mm-aaaa.
      'cop_fecha': () {
        final crudo = _pickFlexible(props, [
          'cop_fecha', 'COP_FECHA',
          'fecha_liberacion', 'FECHA_LIBERACION',
          'fecha_de_liberacion', 'FECHA_DE_LIBERACION',
          'fecha liberacion', 'FECHA LIBERACION',
          'fecha de liberacion', 'FECHA DE LIBERACION',
        ]);
        if (crudo == null) return null;
        return norm.normalizeFechaLiberacion(crudo);
      }(),

      // "Fecha límite de pago": puede venir del archivo importado en vez
      // de capturarse manualmente. Acepta ISO, dd/mm/aaaa y dd-mm-aaaa.
      'fecha_limite_pago': () {
        final crudo = _pickFlexible(props, [
          'fecha_limite_pago', 'FECHA_LIMITE_PAGO',
          'fecha_limite_de_pago', 'FECHA_LIMITE_DE_PAGO',
          'fecha limite de pago', 'FECHA LIMITE DE PAGO',
          'fecha_limite', 'FECHA_LIMITE',
          'fecha limite', 'FECHA LIMITE',
          'limite_pago', 'LIMITE_PAGO',
          'fecha_pago', 'FECHA_PAGO',
          'fecha de pago', 'FECHA DE PAGO',
        ]);
        if (crudo == null) return null;
        return norm.normalizeFechaLiberacion(crudo);
      }(),
    };

    // Eliminar claves con valor null para no pisar datos existentes
    data.removeWhere((k, v) => v == null);
    
    // Incluir TODAS las propiedades originales del GeoJSON que no estén ya en data
    if (propsOriginal != null) {
      for (final entry in propsOriginal.entries) {
        final key = entry.key;
        if (!data.containsKey(key) && entry.value != null) {
          final sanitizedValue = _sanitizeForFirestore(entry.value);
          final valueStr = sanitizedValue.toString().trim();
          if (valueStr.isNotEmpty && valueStr.toLowerCase() != 'null') {
            data[key] = sanitizedValue;
          }
        }
      }
    }
    return data;
  }

  /// Extrae datos del propietario desde las properties del feature.
  Map<String, dynamic> _buildPropietarioData(Map<String, dynamic> props) {
    final nombreCompletoCrudo = _pick(props, [
      'propietario', 'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'PROPIETARIO', 'titular', 'nombre',
    ]) ?? '';
    final nombreCompleto = norm.normalizeTitleCase(nombreCompletoCrudo) ?? '';

    final parts = nombreCompleto.trim().split(' ');
    final nombre = parts.isNotEmpty ? parts.first : '';
    final apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final razonSocial = norm.normalizeTitleCase(_pick(props, [
      'razon_social', 'RAZON_SOCIAL', 'empresa', 'denominacion', 'EMPRESA',
    ]));

    final nombreCompletoUpper = nombreCompletoCrudo.toUpperCase();
    final tipoPersona = (razonSocial != null ||
            nombreCompletoUpper.contains('S.A.') ||
            nombreCompletoUpper.contains('S.DE R.L.') ||
            nombreCompletoUpper.contains('SAPI') ||
            nombreCompletoUpper.contains('SAS'))
        ? 'moral'
        : 'fisica';

    final rfc = norm.normalizeCode(_pick(props, ['rfc', 'RFC']));
    final curp = norm.normalizeCode(_pick(props, ['curp', 'CURP']));
    final telefono = _pick(props, ['telefono', 'tel', 'TEL', 'phone', 'TELEFONO'])?.trim();
    final correo = _pick(props, ['correo', 'email', 'EMAIL', 'correo_electronico'])?.trim().toLowerCase();

    final data = <String, dynamic>{
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (razonSocial case final rs?) 'razon_social': rs,
      if (rfc != null) 'rfc': rfc,
      if (curp != null) 'curp': curp,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (correo != null && correo.isNotEmpty) 'correo': correo,
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

  /// Convierte valores a boolean para campos de gestión (checklist:
  /// identificación/levantamiento/negociación/COP). Delegado a la
  /// normalización compartida en `core/utils/import_normalization.dart`.
  bool _toBool(dynamic v) => norm.normalizeBoolean(v);

  /// Normaliza el valor de tipo_propiedad a los valores válidos del sistema.
  /// Delegado a la normalización compartida.
  String? _normalizeTipoPropiedad(String? value) => norm.normalizeTipoPropiedad(value);

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
    var encontrados = 0;
    var creados = 0;
    var errores = 0;
    var procesados = 0;

    onProgress?.call(0, features.length);

    final lanes = _buildLanes(features, concurrency);
    // Cuenta cuántas veces se ha visto cada clave DENTRO de este mismo
    // archivo: es la única señal confiable de relación 1:N real (ver
    // comentario en `PrediosRepository.upsertPredioPorClave`). Dos features
    // con la misma clave siempre caen en el mismo carril (mismo hash), así
    // que este mapa compartido nunca se toca desde dos carriles a la vez
    // para la misma clave.
    final vecesVistaPorClave = <String, int>{};
    await Future.wait(
      lanes.map(
        (lane) => _processLane(
          lane,
          vecesVistaPorClave: vecesVistaPorClave,
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
    required Map<String, int> vecesVistaPorClave,
    required void Function(_FeatureSyncOutcome outcome) onOutcome,
  }) async {
    for (final item in lane) {
      final outcome = await _processFeature(item.key, item.value, vecesVistaPorClave);
      onOutcome(outcome);
    }
  }

  Future<_FeatureSyncOutcome> _processFeature(
    int featureIndex,
    Map<String, dynamic> feature,
    Map<String, int> vecesVistaPorClave,
  ) async {
    final featureNumber = featureIndex + 1;

    final rawPropsInicial = feature['properties'];
    final propsInicial =
        rawPropsInicial is Map ? Map<String, dynamic>.from(rawPropsInicial) : <String, dynamic>{};
    if (_extractId(GeoJsonMapper.normalizeProperties(propsInicial)) == null) {
      // Sin clave catastral resoluble (ni por el campo canónico ni por
      // ningún alias conocido -folio, id_sedatu, cvegeo, id, fid, etc.-):
      // antes se generaba un identificador inventado (`IMP-<timestamp>`)
      // que parecía una clave real y terminaba produciendo registros
      // fantasma -duplicados, o predios que ya no se podían encontrar ni
      // borrar por su clave real-. Ahora el feature se omite y se cuenta
      // como error, sin crear ningún predio. `carga_archivo_screen.dart`
      // ya valida esto ANTES de llegar aquí y bloquea la importación
      // completa del archivo; esto es una salvaguarda adicional.
      return _FeatureSyncOutcome(
        featureIndex: featureIndex,
        result: FeatureSyncResult(feature: feature, existia: false),
        encontrados: 0,
        creados: 0,
        errores: 1,
        mensajesError: ['Feature $featureNumber: sin clave catastral, omitido.'],
      );
    }

    try {
      final rawProps = feature['properties'];
      final propsOriginal = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};
      final props = GeoJsonMapper.normalizeProperties(propsOriginal);
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : null;
      // La clave ya se validó como resoluble arriba.
      final claveNormalizada = _extractId(props)!.trim();

      final predioData = _buildNuevoPredioData(
        claveNormalizada,
        props,
        geometry,
        propsOriginal: propsOriginal,
      );

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

      // Si ya existe EXACTAMENTE un registro con esta clave y este mismo
      // archivo no la había traído antes, se fusiona en ese registro en vez
      // de crear uno nuevo -join vectorial+tabular, heredando datos
      // mutuamente-. Si este archivo YA trajo la misma clave antes
      // (`esRepetidoEnArchivo`), es una afectación repetida real y se crea
      // un registro nuevo vinculado al mismo polígono (ver
      // `PrediosRepository.upsertPredioPorClave`).
      final vecesVista = (vecesVistaPorClave[claveNormalizada] ?? 0) + 1;
      vecesVistaPorClave[claveNormalizada] = vecesVista;
      final esRepetidoEnArchivo = vecesVista > 1;

      final resultado = await _withRetry(
        () => _prediosRepo.upsertPredioPorClave(
          predioData,
          forzarNuevoRegistro: esRepetidoEnArchivo,
        ),
        operationName: 'upsertPredioPorClave',
      );

      final nuevoMap = resultado.predio.toMap()
        ..['id'] = resultado.predio.id
        ..['created_at'] = resultado.predio.createdAt.toIso8601String();

      final enrichedProps = _injectData(props, nuevoMap);
      enrichedProps['_predioNuevo'] = true;
      if (resultado.fusionado) enrichedProps['_predioFusionado'] = true;

      return _FeatureSyncOutcome(
        featureIndex: featureIndex,
        result: FeatureSyncResult(
          feature: {
            ...feature,
            'properties': enrichedProps,
          },
          existia: resultado.fusionado,
          predioId: resultado.predio.id,
        ),
        encontrados: resultado.fusionado ? 1 : 0,
        creados: resultado.fusionado ? 0 : 1,
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
        // La clave ya se validó como resoluble al inicio de _processFeature.
        final clave = _extractId(props)!;

        // Extraer y normalizar el tipo de propiedad del archivo GeoJSON
        final tipoPropiedad = _resolveTipoPropiedad(props);

        final minData = <String, dynamic>{
          'clave_catastral': clave,
          'tramo': 'S/T',
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
