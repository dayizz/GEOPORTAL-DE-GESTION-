import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/import_normalization.dart' as norm;
import '../data/importacion_repository.dart';
import '../utils/geojson_mapper.dart';

final xlsxImportServiceProvider = Provider<XlsxImportService>((ref) {
  return XlsxImportService(ref.read(importacionRepositoryProvider));
});

enum XlsxTargetTable {
  predios,
  propietarios,
}

class XlsxSheetImport {
  final String hoja;
  final XlsxTargetTable tabla;
  final List<Map<String, dynamic>> rows;
  /// Encabezados originales (sin normalizar) detectados en la fila de
  /// encabezado de esta hoja; solo para diagnóstico -ver
  /// `filasPrediosSinClave`, que los usa para explicarle al usuario por
  /// qué ninguna fila resolvió clave catastral cuando ninguna columna de
  /// la hoja coincide con los alias conocidos-.
  final List<String> encabezadosOriginales;

  const XlsxSheetImport({
    required this.hoja,
    required this.tabla,
    required this.rows,
    this.encabezadosOriginales = const [],
  });
}

class XlsxParseResult {
  final List<XlsxSheetImport> hojas;
  final List<Map<String, dynamic>> preview;
  final int totalRows;

  const XlsxParseResult({
    required this.hojas,
    required this.preview,
    required this.totalRows,
  });
}

/// Resultado de validar que todas las filas de predios traigan clave
/// catastral. `encabezadosPorHojaSinNinguna` solo trae entradas para
/// hojas donde NINGUNA fila resolvió clave -señal de que la columna
/// correspondiente no se reconoció por su encabezado (no es una hoja con
/// datos genuinamente incompletos), útil para diagnosticar qué encabezado
/// usar en el archivo.
class ClaveFaltanteInfo {
  final List<String> registros;
  final Map<String, List<String>> encabezadosPorHojaSinNinguna;

  const ClaveFaltanteInfo({
    required this.registros,
    required this.encabezadosPorHojaSinNinguna,
  });

  bool get isEmpty => registros.isEmpty;
  bool get isNotEmpty => registros.isNotEmpty;
}

/// Filas de hojas de tipo `predios` (las de `propietarios` no requieren
/// clave catastral propia) sin `clave_catastral` resoluble, identificadas
/// como "Hoja X, fila N" para mostrarle al usuario. Se usa para bloquear
/// la importación ANTES de escribir nada -antes, una fila sin clave se
/// rechazaba una por una durante la escritura (`_importarFila`), lo que
/// dejaba el resto del archivo a medio importar en vez de forzar al
/// usuario a corregir el archivo completo primero-.
ClaveFaltanteInfo filasPrediosSinClave(XlsxParseResult parseResult) {
  final faltantes = <String>[];
  final encabezadosSinNinguna = <String, List<String>>{};
  for (final hoja in parseResult.hojas) {
    if (hoja.tabla != XlsxTargetTable.predios) continue;
    var sinClaveEnHoja = 0;
    for (var i = 0; i < hoja.rows.length; i++) {
      final clave = hoja.rows[i]['clave_catastral']?.toString().trim() ?? '';
      if (clave.isEmpty) {
        faltantes.add('Hoja "${hoja.hoja}", registro ${i + 1}');
        sinClaveEnHoja++;
      }
    }
    // Ninguna fila de la hoja trae clave: casi seguro que el encabezado de
    // esa columna no coincide con ningún alias conocido, no que el
    // archivo genuinamente venga sin esos datos.
    if (sinClaveEnHoja > 0 && sinClaveEnHoja == hoja.rows.length) {
      encabezadosSinNinguna[hoja.hoja] = hoja.encabezadosOriginales;
    }
  }
  return ClaveFaltanteInfo(registros: faltantes, encabezadosPorHojaSinNinguna: encabezadosSinNinguna);
}

class XlsxImportResult {
  final int procesados;
  final int creados;
  final int actualizados;
  final int errores;
  final List<String> mensajes;

  const XlsxImportResult({
    required this.procesados,
    required this.creados,
    required this.actualizados,
    required this.errores,
    this.mensajes = const [],
  });
}

class _HeaderDetection {
  final int headerRowIndex;
  final List<String> headers;
  final List<String> headersOriginales;
  final XlsxTargetTable tabla;
  final int score;

  const _HeaderDetection({
    required this.headerRowIndex,
    required this.headers,
    this.headersOriginales = const [],
    required this.tabla,
    required this.score,
  });
}

class XlsxImportService {
  static const int _batchSize = 40;
  final ImportacionRepository? _importacionRepository;

  XlsxImportService([this._importacionRepository]);

  Future<XlsxParseResult> parseInBackground(Uint8List bytes) async {
    final payload = await compute(_parseXlsxPayload, bytes);
    final rawHojas = payload['hojas'] as List? ?? const [];
    final rawPreview = payload['preview'] as List? ?? const [];

    final hojas = rawHojas.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final rawRows = map['rows'] as List? ?? const [];
      final rawEncabezados = map['encabezados'] as List? ?? const [];
      return XlsxSheetImport(
        hoja: map['hoja'] as String,
        tabla: map['tabla'] == 'predios'
            ? XlsxTargetTable.predios
            : XlsxTargetTable.propietarios,
        rows: rawRows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
        encabezadosOriginales: rawEncabezados.map((h) => h.toString()).toList(growable: false),
      );
    }).toList(growable: false);

    return XlsxParseResult(
      hojas: hojas,
      preview: rawPreview
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      totalRows: (payload['totalRows'] as num?)?.toInt() ?? 0,
    );
  }

  static const Map<String, List<String>> _prediosAliases = {
    'clave_catastral': [
      'clave_catastral',
      'clave',
      'cve',
      'cve_catastral',
      'cve_cat',
      'clave_cat',
      'clave_predial',
      'cve_predial',
      'clave_del_predio',
      'no_clave',
      'numero_clave',
      'id_catastral',
      'id_sedatu',
      'idsedatu',
      'id_predio',
      'folio',
      'folio_real',
      'cvegeo',
      'num_predio',
      'no_predio',
      'numero_predio',
      'clave_predio',
      'clave_registro',
      // 'id' a propósito al final: es muy genérico (podría ser un simple
      // número de fila), así que solo se usa como último recurso si
      // ninguna columna más específica coincidió.
      'id',
    ],
    'tramo': [
      'tramo',
      'zona',
      'segmento',
      'sector',
      'modulo',
      'tramo_vial',
      // "Tipo de división" (Segmento/Tramo/Frente, o su abreviación T/F/S)
      'frente',
      't_f_s',
      'tfs',
      'tipo_fs',
    ],
    'tipo_propiedad': [
      'tipo_propiedad',
      'tipo',
      'uso_suelo',
      'uso',
      'regimen',
      'tipo_tenencia',
      'tenencia',
    ],
    'ejido': ['ejido', 'comunidad', 'localidad'],
    'estado': [
      'estado',
      'entidad',
      'entidad_federativa',
      'edo',
    ],
    'municipio': [
      'municipio',
      'mun',
      'mpio',
      'muni',
      'localidad_municipio',
    ],
      'estructura': [
        'estructura',
        'tipo_estructura',
        'clase_estructura',
        'estruc',
      ],
      'tipo_liberacion': [
        'tipo_liberacion',
        'tipo_de_liberacion',
        'liberacion',
        'cop_dot',
        'cop_dot_aop',
      ],
    'km_inicio': [
      'km_inicio',
      'km_inicial',
      'cadenamiento_inicial',
      'cad_ini',
      'km_i',
      'cadenamiento_inicio',
      'inicio',
    ],
    'km_fin': [
      'km_fin',
      'km_final',
      'cadenamiento_final',
      'cad_fin',
      'km_f',
      'cadenamiento_fin',
      'fin',
    ],
    'km_lineales': ['km_lineales', 'longitud_lineal'],
    'km_efectivos': ['km_efectivos', 'km_efectivo', 'km_ef', 'kmef', 'longitud_efectiva'],
    'superficie': [
      'superficie',
      'area',
      'area_m2',
      'shape_area',
      'sup',
      'superficie_m2',
      'sup_m2',
      'm2',
      'hectareas',
      'ha',
    ],
    'proyecto': [
      'proyecto',
      'obra',
      'nombre_proyecto',
      'proyecto_nombre',
      'proyecto_vial',
    ],
    'propietario_nombre': [
      'propietario',
      'propietarios',
      'propietario_nombre',
      'nombre_propietario',
      'titular',
      'nombre_titular',
      'titular_derecho',
      'dueno',
      'nombre',
      'razon_social',
      'beneficiario',
    ],
    'rfc_propietario': [
      'rfc_propietario',
      'rfc',
      'rfc_titular',
    ],
    'curp_propietario': [
      'curp_propietario',
      'curp',
      'curp_titular',
    ],
    'telefono_propietario': [
      'telefono_propietario',
      'telefono',
      'celular',
      'tel',
      'tel_propietario',
    ],
    'correo_propietario': [
      'correo_propietario',
      'correo',
      'email',
      'correo_electronico',
    ],
    // NOTA: 'estatus' NO es alias de 'cop' -esa palabra se reserva para
    // 'rango_estatus' (Liberado/Negociacion/Posible DOT/...)-, para no
    // chocar cuando el archivo trae ambas columnas.
    'cop': [
      'cop',
      'liberado',
      'libre',
      'convenio',
      'cop_firmado',
      'status',
    ],
    'rango_estatus': [
      'rango_estatus',
      'rango_de_estatus',
      'estatus',
      'estatus_predio',
    ],
    'cop_fecha': [
      'cop_fecha',
      'fecha_liberacion',
      'fecha_de_liberacion',
    ],
    'fecha_limite_pago': [
      'fecha_limite_pago',
      'fecha_limite_de_pago',
      'fecha_limite',
      'limite_pago',
      'fecha_pago',
      'fecha_de_pago',
    ],
    'identificacion': ['identificacion', 'identificado', 'id_realizada'],
    'levantamiento': ['levantamiento', 'levantado', 'lev'],
    'negociacion': ['negociacion', 'negociado', 'neg'],
    'poligono_insertado': [
      'poligono_insertado',
      'poligono',
      'polig',
      'geometria',
    ],
    'latitud': ['latitud', 'lat', 'y', 'coordy'],
    'longitud': ['longitud', 'lon', 'lng', 'x', 'coordx'],
  };

  static const Map<String, List<String>> _propietariosAliases = {
    'nombre': ['nombre'],
    'apellidos': ['apellidos'],
    'nombre_completo': ['nombre_completo', 'propietario', 'titular'],
    'tipo_persona': ['tipo_persona'],
    'razon_social': ['razon_social'],
    'curp': ['curp'],
    'rfc': ['rfc'],
    'telefono': ['telefono', 'celular'],
    'correo': ['correo', 'email'],
  };

  XlsxParseResult parse(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final imports = <XlsxSheetImport>[];
    final preview = <Map<String, dynamic>>[];
    var totalRows = 0;

    for (final hoja in workbook.tables.keys) {
      final table = workbook.tables[hoja];
      if (table == null || table.rows.length < 2) {
        continue;
      }

      final headerInfo = _detectarHeaderYTabla(table.rows);
      if (headerInfo == null) {
        continue;
      }

      final headers = headerInfo.headers;
      final target = headerInfo.tabla;

      final proyectoDeHoja = _inferirProyectoDeHoja(hoja);

      final rows = <Map<String, dynamic>>[];
      for (final row in table.rows.skip(headerInfo.headerRowIndex + 1)) {
        final rowMap = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          if (i >= row.length) continue;
          final key = headers[i];
          if (key.isEmpty) continue;
          final val = _cellToText(row[i]).trim();
          if (val.isNotEmpty) {
            rowMap[key] = val;
          }
        }
        if (rowMap.isEmpty) continue;

        var normalizedRow = target == XlsxTargetTable.predios
            ? _normalizarFilaPredio(rowMap)
            : _normalizarFilaPropietario(rowMap);
        if (normalizedRow.isEmpty) continue;

        // Inyectar proyecto inferido del nombre de hoja si la fila no lo tiene
        if (target == XlsxTargetTable.predios &&
            proyectoDeHoja != null &&
            (normalizedRow['proyecto'] == null ||
                (normalizedRow['proyecto'] as String).isEmpty)) {
          normalizedRow = {...normalizedRow, 'proyecto': proyectoDeHoja};
        }

        rows.add(normalizedRow);
      }

      if (rows.isEmpty) continue;

      totalRows += rows.length;
      imports.add(XlsxSheetImport(
        hoja: hoja,
        tabla: target,
        rows: rows,
        encabezadosOriginales:
            headerInfo.headersOriginales.where((h) => h.trim().isNotEmpty).toList(growable: false),
      ));

      for (final row in rows.take(3)) {
        preview.add({
          'hoja': hoja,
          'tabla': target == XlsxTargetTable.predios ? 'predios' : 'propietarios',
          ...row,
        });
      }
    }

    if (imports.isEmpty) {
      throw const FormatException(
        'El XLSX no contiene filas detectables para predios o propietarios. '
        'Verifica que incluya encabezados como clave_catastral, tramo, propietario, nombre o rfc.',
      );
    }

    return XlsxParseResult(hojas: imports, preview: preview, totalRows: totalRows);
  }

  _HeaderDetection? _detectarHeaderYTabla(List<List<dynamic>> allRows) {
    final maxRowsToScan = allRows.length < 10 ? allRows.length : 10;

    _HeaderDetection? best;

    for (var rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
      final rawHeaders = allRows[rowIndex].map(_cellToText).toList(growable: false);
      final headers = rawHeaders.map(_normalize).toList(growable: false);

      final hasAtLeastOneHeader = headers.any((h) => h.isNotEmpty);
      if (!hasAtLeastOneHeader) continue;

      final prediosScore = _score(headers, _prediosAliases);
      final propietariosScore = _score(headers, _propietariosAliases);
      final totalScore = prediosScore > propietariosScore ? prediosScore : propietariosScore;
      if (totalScore == 0) continue;

      final tabla = prediosScore >= propietariosScore
          ? XlsxTargetTable.predios
          : XlsxTargetTable.propietarios;

      final current = _HeaderDetection(
        headerRowIndex: rowIndex,
        headers: headers,
        headersOriginales: rawHeaders,
        tabla: tabla,
        score: totalScore,
      );

      if (best == null || current.score > best.score) {
        best = current;
      }
    }

    // Fallback: si no encuentra encabezado claro, intentar con la primera fila no vacía como predios.
    if (best == null) {
      for (var rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
        final rawHeaders = allRows[rowIndex].map(_cellToText).toList(growable: false);
        final headers = rawHeaders.map(_normalize).toList(growable: false);
        if (headers.any((h) => h.isNotEmpty)) {
          return _HeaderDetection(
            headerRowIndex: rowIndex,
            headers: headers,
            headersOriginales: rawHeaders,
            tabla: XlsxTargetTable.predios,
            score: 0,
          );
        }
      }
    }

    return best;
  }

  Future<XlsxImportResult> importar(XlsxParseResult parseResult) async {
    final repo = _importacionRepository;
    if (repo == null) {
      throw StateError(
        'XlsxImportService.importar requiere un ImportacionRepository configurado.',
      );
    }

    var procesados = 0;
    var creados = 0;
    var actualizados = 0;
    var errores = 0;
    final mensajes = <String>[];

    for (final hoja in parseResult.hojas) {
      // Filas con la MISMA clave_catastral van al mismo "carril" y se
      // procesan en orden estricto (nunca en paralelo entre sí): si dos
      // filas del XLSX comparten clave (relación 1:N real, p.ej. dos
      // afectaciones distintas del mismo predio), `upsertPredioPorClave`
      // necesita ver el resultado de la fila anterior antes de decidir si
      // la siguiente fusiona o crea un registro nuevo enlazado. Procesarlas
      // en paralelo (como antes, con `Future.wait` sobre todo el batch)
      // provocaba una condición de carrera: ambas leían el mismo estado
      // "vacío" antes de que la otra escribiera, y las dos terminaban
      // fusionándose en el mismo documento, perdiendo una de las dos filas.
      final lanes = _buildLanesParaHoja(hoja.rows);
      // Cuenta cuántas veces se ha visto cada clave DENTRO de este mismo
      // archivo: es la única señal confiable de relación 1:N real (ver
      // comentario en `PrediosRepository.upsertPredioPorClave`). Dos filas
      // con la misma clave siempre caen en el mismo carril (mismo hash), así
      // que este mapa compartido nunca se toca desde dos carriles a la vez
      // para la misma clave.
      final vecesVistaPorClave = <String, int>{};
      await Future.wait(
        lanes.map(
          (lane) => _procesarLane(
            hoja: hoja,
            lane: lane,
            vecesVistaPorClave: vecesVistaPorClave,
            onResult: (result) {
              procesados += 1;
              creados += result.creados;
              actualizados += result.actualizados;
              errores += result.errores;
              if (result.mensaje != null && mensajes.length < 8) {
                mensajes.add(result.mensaje!);
              }
            },
          ),
        ),
      );
    }

    return XlsxImportResult(
      procesados: procesados,
      creados: creados,
      actualizados: actualizados,
      errores: errores,
      mensajes: mensajes,
    );
  }

  Future<_ImportRowResult> _importarFila({
    required XlsxSheetImport hoja,
    required Map<String, dynamic> row,
    bool esRepetidoEnArchivo = false,
  }) async {
    final repo = _importacionRepository;
    if (repo == null) {
      return _ImportRowResult.error(
        'Servicio de importacion no configurado para escritura.',
      );
    }

    try {
      if (hoja.tabla == XlsxTargetTable.predios) {
        final clave = row['clave_catastral']?.toString().trim() ?? '';
        if (clave.isEmpty) {
          return _ImportRowResult.error(
            'Hoja ${hoja.hoja}: fila sin clave_catastral.',
          );
        }

        final result = await repo.upsertPredioConPropietario(
          row,
          esRepetidoEnArchivo: esRepetidoEnArchivo,
        );
        return _ImportRowResult(
          creados: result.creado ? 1 : 0,
          actualizados: result.actualizado ? 1 : 0,
          errores: 0,
        );
      }

      final result = await repo.upsertPropietario(row);
      return _ImportRowResult(
        creados: result.creado ? 1 : 0,
        actualizados: result.actualizado ? 1 : 0,
        errores: 0,
      );
    } catch (e) {
      return _ImportRowResult.error('Hoja ${hoja.hoja}: $e');
    }
  }

  /// Reparte las filas de una hoja en `_batchSize` carriles como máximo,
  /// agrupando las que comparten `clave_catastral` en el mismo carril (se
  /// procesan en el orden en que aparecen en el archivo) para que nunca se
  /// resuelvan en paralelo entre sí. Filas sin clave se reparten por
  /// índice, sin esa restricción.
  List<List<Map<String, dynamic>>> _buildLanesParaHoja(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const [];
    final laneCount = _batchSize > rows.length ? rows.length : _batchSize;
    final lanes = List.generate(laneCount, (_) => <Map<String, dynamic>>[]);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final clave = row['clave_catastral']?.toString().trim();
      final lane = (clave != null && clave.isNotEmpty)
          ? clave.hashCode.abs() % laneCount
          : i % laneCount;
      lanes[lane].add(row);
    }
    return lanes;
  }

  Future<void> _procesarLane({
    required XlsxSheetImport hoja,
    required List<Map<String, dynamic>> lane,
    required Map<String, int> vecesVistaPorClave,
    required void Function(_ImportRowResult result) onResult,
  }) async {
    for (final row in lane) {
      final clave = row['clave_catastral']?.toString().trim();
      var esRepetidoEnArchivo = false;
      if (clave != null && clave.isNotEmpty) {
        final vecesVista = (vecesVistaPorClave[clave] ?? 0) + 1;
        vecesVistaPorClave[clave] = vecesVista;
        esRepetidoEnArchivo = vecesVista > 1;
      }
      final result = await _importarFila(
        hoja: hoja,
        row: row,
        esRepetidoEnArchivo: esRepetidoEnArchivo,
      );
      onResult(result);
    }
  }

  int _score(List<String> headers, Map<String, List<String>> aliases) {
    var score = 0;
    for (final al in aliases.values) {
      if (headers.any(al.contains)) {
        score++;
      }
    }
    return score;
  }

  Map<String, dynamic> _normalizarFilaPredio(Map<String, String> row) {
    final out = <String, dynamic>{};

    String? pick(List<String> aliases) {
      for (final a in aliases) {
        final value = row[_normalize(a)]?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    double? pickDouble(List<String> aliases) {
      final raw = pick(aliases);
      if (raw == null) return null;
      return double.tryParse(raw.replaceAll(',', '').trim());
    }

    bool? pickBool(List<String> aliases) {
      final raw = pick(aliases);
      if (raw == null) return null;
      // Reconoce SI/SÍ/VERDADERO/TRUE/X/COMPLETADO/... como verdadero y
      // NO/FALSO/FALSE/FAKE/... como falso (ver import_normalization.dart).
      return norm.normalizeBoolean(raw);
    }

    final clave = pick(_prediosAliases['clave_catastral']!);
    if (clave != null) out['clave_catastral'] = _normalizeUpperCode(clave);

    // Firestore exige 'tramo' y 'tipo_propiedad' como string no vacío en cada
    // documento de 'predios' (firestore.rules); si el XLSX no trae estas
    // columnas la fila se queda sin esas claves y la escritura se rechaza
    // con "permission-denied". Se aplican los mismos valores por defecto
    // que ya usa la importación de GeoJSON (sincronizacion_service.dart)
    // para no romper el permiso de escritura.
    final tramo = pick(_prediosAliases['tramo']!);
    out['tramo'] = tramo != null ? _normalizeUpperCode(tramo) : 'S/T';

    final tipo = pick(_prediosAliases['tipo_propiedad']!);
    out['tipo_propiedad'] = _normalizeTipoPropiedadValue(tipo ?? '');

    final estructura = pick(_prediosAliases['estructura']!);
    if (estructura != null) out['estructura'] = norm.normalizeEstructura(estructura);

    final tipoLiberacion = pick(_prediosAliases['tipo_liberacion']!);
    if (tipoLiberacion != null) {
      out['tipo_liberacion'] = norm.normalizeTipoLiberacion(tipoLiberacion);
    }

    final rangoEstatus = pick(_prediosAliases['rango_estatus']!);
    if (rangoEstatus != null) out['rango_estatus'] = norm.normalizeRangoEstatus(rangoEstatus);

    final copFecha = pick(_prediosAliases['cop_fecha']!);
    if (copFecha != null) {
      final normalizada = norm.normalizeFechaLiberacion(copFecha);
      if (normalizada != null) out['cop_fecha'] = normalizada;
    }

    final fechaLimitePago = pick(_prediosAliases['fecha_limite_pago']!);
    if (fechaLimitePago != null) {
      final normalizada = norm.normalizeFechaLiberacion(fechaLimitePago);
      if (normalizada != null) out['fecha_limite_pago'] = normalizada;
    }

    // No todos los predios pertenecen a un ejido: "N/A"/"NO APLICA" se
    // reconocen y guardan como el marcador "N/A".
    final ejido = pick(_prediosAliases['ejido']!);
    if (ejido != null) out['ejido'] = norm.normalizeEjido(ejido);

    final estado = pick(_prediosAliases['estado']!);
    if (estado != null) out['estado'] = norm.normalizeTitleCase(estado);

    final municipio = pick(_prediosAliases['municipio']!);
    if (municipio != null) out['municipio'] = norm.normalizeTitleCase(municipio);

    final proyecto = pick(_prediosAliases['proyecto']!);
    if (proyecto != null) out['proyecto'] = _normalizeProyectoValue(proyecto);

    final propietarioNombre = pick(_prediosAliases['propietario_nombre']!);
    if (propietarioNombre != null) out['propietario_nombre'] = norm.normalizeTitleCase(propietarioNombre);

    // Acepta formato PK ("12+359") o decimal ("12.359") -misma distancia-;
    // siempre queda guardado como el mismo número para que Gestión lo
    // muestre consistentemente en formato PK.
    final kmInicioRaw = pick(_prediosAliases['km_inicio']!);
    final kmInicio = norm.normalizeKmValue(kmInicioRaw);
    if (kmInicio != null) out['km_inicio'] = kmInicio;

    final kmFinRaw = pick(_prediosAliases['km_fin']!);
    final kmFin = norm.normalizeKmValue(kmFinRaw);
    if (kmFin != null) out['km_fin'] = kmFin;

    final kmLineales = pickDouble(_prediosAliases['km_lineales']!);
    if (kmLineales != null) out['km_lineales'] = kmLineales;

    final kmEfectivos = pickDouble(_prediosAliases['km_efectivos']!);
    if (kmEfectivos != null) out['km_efectivos'] = kmEfectivos;

    final superficie = pickDouble(_prediosAliases['superficie']!);
    if (superficie != null) out['superficie'] = superficie;

    final lat = pickDouble(_prediosAliases['latitud']!);
    if (lat != null) out['latitud'] = lat;

    final lng = pickDouble(_prediosAliases['longitud']!);
    if (lng != null) out['longitud'] = lng;

    final cop = pickBool(_prediosAliases['cop']!);
    if (cop != null) out['cop'] = cop;

    final identificacion = pickBool(_prediosAliases['identificacion']!);
    if (identificacion != null) out['identificacion'] = identificacion;

    final levantamiento = pickBool(_prediosAliases['levantamiento']!);
    if (levantamiento != null) out['levantamiento'] = levantamiento;

    final negociacion = pickBool(_prediosAliases['negociacion']!);
    if (negociacion != null) out['negociacion'] = negociacion;

    final poligonoInsertado = pickBool(_prediosAliases['poligono_insertado']!);
    if (poligonoInsertado != null) out['poligono_insertado'] = poligonoInsertado;

    final rfcProp = pick(_prediosAliases['rfc_propietario']!);
    if (rfcProp != null) out['rfc_propietario'] = _normalizeUpperCode(rfcProp);

    final curpProp = pick(_prediosAliases['curp_propietario']!);
    if (curpProp != null) out['curp_propietario'] = _normalizeUpperCode(curpProp);

    final telProp = pick(_prediosAliases['telefono_propietario']!);
    if (telProp != null) out['telefono_propietario'] = _normalizePlainText(telProp);

    final correoProp = pick(_prediosAliases['correo_propietario']!);
    if (correoProp != null) out['correo_propietario'] = _normalizeEmail(correoProp);

    return out;
  }

  Map<String, dynamic> _normalizarFilaPropietario(Map<String, String> row) {
    final out = <String, dynamic>{};

    String? pick(List<String> aliases) {
      for (final a in aliases) {
        final value = row[_normalize(a)]?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    for (final entry in _propietariosAliases.entries) {
      final value = pick(entry.value);
      if (value != null) {
        out[entry.key] = _normalizePropietarioField(entry.key, value);
      }
    }

    if (!out.containsKey('nombre') && out['nombre_completo'] == null) {
      return {};
    }

    return out;
  }

  // ── Extraer texto de una celda de excel 4.x (CellValue typed) ─────────────
  String _cellToText(dynamic cell) {
    if (cell == null) return '';
    final v = (cell as dynamic).value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateTimeCellValue) return v.asDateTimeUtc().toIso8601String();
    if (v is DateCellValue) return v.asDateTimeLocal().toIso8601String();
    return v.toString();
  }

  // ── Detectar código de proyecto en el nombre de la hoja ──────────────────
  // Se reutiliza el registro de GeoJsonMapper (sincronizado con Estructura)
  // para no mantener una segunda lista que pueda desincronizarse.
  List<String> get _proyectosCodigo => GeoJsonMapper.proyectosConocidos;

  String? _inferirProyectoDeHoja(String hoja) {
    final upper = hoja.toUpperCase();
    for (final code in _proyectosCodigo) {
      // Debe aparecer como palabra completa o delimitada por no-alfanumérico
      final regex = RegExp(r'(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
      if (regex.hasMatch(upper)) return code;
    }
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    final regexTqm = RegExp(r'(^|[^A-Z0-9])TQM([^A-Z0-9]|$)');
    if (regexTqm.hasMatch(upper)) return 'TMQ';
    return null;
  }

  String _normalizePlainText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeUpperCode(String value) {
    return norm.normalizeCode(value) ?? _normalizePlainText(value).toUpperCase();
  }

  String _normalizeEmail(String value) {
    return _normalizePlainText(value).toLowerCase();
  }

  String _normalizeProyectoValue(String value) {
    final upper = _normalizeUpperCode(value);
    for (final code in _proyectosCodigo) {
      if (upper.contains(code)) return code;
    }
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    if (upper.contains('TQM')) return 'TMQ';
    return upper;
  }

  String _normalizeTipoPropiedadValue(String value) => norm.normalizeTipoPropiedad(value);

  String _normalizePropietarioField(String key, String value) {
    switch (key) {
      case 'rfc':
      case 'curp':
        return _normalizeUpperCode(value);
      case 'correo':
        return _normalizeEmail(value);
      case 'tipo_persona':
        return _normalizePlainText(value).toLowerCase();
      case 'nombre':
      case 'apellidos':
      case 'nombre_completo':
      case 'razon_social':
        return norm.normalizeTitleCase(value) ?? _normalizePlainText(value);
      default:
        return _normalizePlainText(value);
    }
  }

  String _normalize(String value) {
    var s = value.toLowerCase().trim();
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
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }
}

class _ImportRowResult {
  final int creados;
  final int actualizados;
  final int errores;
  final String? mensaje;

  const _ImportRowResult({
    this.creados = 0,
    this.actualizados = 0,
    this.errores = 0,
  }) : mensaje = null;

  const _ImportRowResult.error(this.mensaje)
      : creados = 0,
        actualizados = 0,
        errores = 1;
}

Map<String, dynamic> _parseXlsxPayload(Uint8List bytes) {
  final service = XlsxImportService();
  final result = service.parse(bytes);

  return {
    'hojas': result.hojas
        .map(
          (hoja) => {
            'hoja': hoja.hoja,
            'tabla': hoja.tabla == XlsxTargetTable.predios
                ? 'predios'
                : 'propietarios',
            'rows': hoja.rows,
            'encabezados': hoja.encabezadosOriginales,
          },
        )
        .toList(growable: false),
    'preview': result.preview,
    'totalRows': result.totalRows,
  };
}
