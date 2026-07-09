import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../predios/models/predio.dart';
import '../providers/carga_provider.dart';
import 'geojson_mapper.dart';

class ArchiveExportPayload {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const ArchiveExportPayload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

bool isGeoJsonArchive(ImportedFile file) {
  final ext = _archiveExtension(file.name);
  return ext == 'geojson' || ext == 'json';
}

bool isXlsxArchive(ImportedFile file) {
  final ext = _archiveExtension(file.name);
  return ext == 'xlsx' || ext == 'xls' || ext == 'xlsl';
}

Future<ArchiveExportPayload> buildArchiveExportPayload({
  required ImportedFile file,
  required List<Predio> currentPredios,
  required String formato,
  String? fallbackProject,
}) async {
  if (formato == 'geojson') {
    return _buildGeoJsonPayload(file, currentPredios);
  }
  return _buildXlsxPayload(
    file,
    currentPredios,
    fallbackProject: fallbackProject,
  );
}

Future<ArchiveExportPayload> _buildGeoJsonPayload(
  ImportedFile file,
  List<Predio> currentPredios,
) async {
  final currentByClave = <String, Predio>{
    for (final predio in currentPredios)
      predio.claveCatastral.trim().toUpperCase(): predio,
  };

  final sourceFeatures = file.features.isNotEmpty
      ? file.features
      : currentPredios
          .map(
            (predio) => <String, dynamic>{
              'type': 'Feature',
              'properties': predio.toMap(),
              if (predio.geometry != null) 'geometry': predio.geometry,
            },
          )
          .toList(growable: false);

  final exportedFeatures = sourceFeatures.map((source) {
    final sourceMap = Map<String, dynamic>.from(source);
    final props = _extractProperties(sourceMap);
    final clave = _extractClave(props);
    final current = clave == null ? null : currentByClave[clave];

    final mergedProps = <String, dynamic>{...props};
    if (current != null) {
      final currentMap = current.toMap();
      mergedProps
        ..addAll(currentMap)
        ..['id'] = current.id
        ..['clave_catastral'] = current.claveCatastral
        ..['estado'] = current.estado
        ..['municipio'] = current.municipio
        ..['proyecto'] = current.proyecto
        ..['tipo_propiedad'] = current.tipoPropiedad
        ..['tramo'] = current.tramo
        ..['cop'] = current.cop
        ..['identificacion'] = current.identificacion
        ..['levantamiento'] = current.levantamiento
        ..['negociacion'] = current.negociacion
        ..['tipo_liberacion'] = current.tipoLiberacion;
    }

    final geometry = sourceMap['geometry'] ?? current?.geometry;
    final feature = <String, dynamic>{
      'type': 'Feature',
      'properties': mergedProps,
    };
    if (geometry != null) {
      feature['geometry'] = geometry;
    }
    return feature;
  }).toList(growable: false);

  final collection = <String, dynamic>{
    'type': 'FeatureCollection',
    'features': exportedFeatures,
  };

  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(collection)));
  final baseName = _archiveBaseName(file.name);
  return ArchiveExportPayload(
    fileName: '$baseName.geojson',
    mimeType: 'application/geo+json',
    bytes: bytes,
  );
}

Future<ArchiveExportPayload> _buildXlsxPayload(
  ImportedFile file,
  List<Predio> currentPredios, {
  String? fallbackProject,
}) async {
  final currentByClave = <String, Predio>{
    for (final predio in currentPredios)
      predio.claveCatastral.trim().toUpperCase(): predio,
  };

  final keysFromArchive = _extractClavesFromArchive(file.features);
  final prediosToExport = keysFromArchive.isNotEmpty
      ? currentPredios
          .where((predio) => keysFromArchive.contains(predio.claveCatastral.trim().toUpperCase()))
          .toList(growable: false)
      : (fallbackProject == null || fallbackProject.trim().isEmpty)
          ? currentPredios
          : currentPredios
              .where((predio) => predio.proyecto?.trim().toUpperCase() == fallbackProject.trim().toUpperCase())
              .toList(growable: false);

  final excel = Excel.createExcel();
  final sheet = excel['Archivo_${_archiveBaseName(file.name)}'];

  const headers = [
    'CLAVE',
    'PROYECTO',
    'T/F/S',
    'TIPO',
    'ESTADO',
    'MUNICIPIO',
    'EJIDO',
    'PROPIETARIOS',
    'KM INICIO',
    'KM FIN',
    'KM EFECTIVOS',
    'SUPERFICIE M2',
    'COP',
    'FECHA COP',
    'ESTATUS',
    'IDENTIFICACION',
    'LEVANTAMIENTO',
    'NEGOCIACION',
    'OBSERVACIONES',
  ];

  for (var col = 0; col < headers.length; col++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).value =
        TextCellValue(headers[col]);
  }

  for (var row = 0; row < prediosToExport.length; row++) {
    final predio = prediosToExport[row];
    final original = currentByClave[predio.claveCatastral.trim().toUpperCase()];
    final rowData = [
      predio.claveCatastral,
      predio.proyecto ?? original?.proyecto ?? '',
      predio.tramo,
      predio.tipoPropiedad,
      predio.estado ?? '',
      predio.municipio ?? '',
      predio.ejido ?? '',
      predio.nombrePropietario,
      predio.kmInicio?.toString() ?? '',
      predio.kmFin?.toString() ?? '',
      predio.kmEfectivos?.toString() ?? '',
      predio.superficie?.toString() ?? '',
      predio.cop ? 'SI' : 'NO',
      predio.copFecha != null
          ? '${predio.copFecha!.day}/${predio.copFecha!.month}/${predio.copFecha!.year}'
          : '',
      predio.cop ? 'Liberado' : 'No liberado',
      predio.identificacion ? 'SI' : 'NO',
      predio.levantamiento ? 'SI' : 'NO',
      predio.negociacion ? 'SI' : 'NO',
      predio.situacionSocial ?? '',
    ];

    for (var col = 0; col < rowData.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1))
          .value = TextCellValue(rowData[col].toString());
    }
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo codificar el archivo XLSX.');
  }

  final baseName = _archiveBaseName(file.name);
  return ArchiveExportPayload(
    fileName: '$baseName.xlsx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    bytes: Uint8List.fromList(bytes),
  );
}

String _archiveBaseName(String name) {
  final withoutExtension = name.replaceAll(RegExp(r'\.[^.]+$'), '');
  return withoutExtension.replaceAll(RegExp(r'[^A-Za-z0-9\-_]+'), '_');
}

String _archiveExtension(String name) {
  final parts = name.toLowerCase().split('.');
  return parts.length > 1 ? parts.last : '';
}

Map<String, dynamic> _extractProperties(Map<String, dynamic> source) {
  final rawProps = source['properties'];
  if (rawProps is Map) {
    return Map<String, dynamic>.from(rawProps);
  }
  return Map<String, dynamic>.from(source);
}

String? _extractClave(Map<String, dynamic> props) {
  final normalized = GeoJsonMapper.normalizeProperties(props);
  final candidates = [
    normalized['clave_catastral'],
    props['clave_catastral'],
    props['CLAVE_CATASTRAL'],
    props['clave'],
    props['CLAVE'],
    props['id_sedatu'],
    props['ID_SEDATU'],
    props['folio'],
    props['FOLIO'],
  ];

  for (final candidate in candidates) {
    if (candidate == null) continue;
    final text = candidate.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text.toUpperCase();
    }
  }

  return null;
}

Set<String> _extractClavesFromArchive(List<Map<String, dynamic>> features) {
  final claves = <String>{};
  for (final source in features) {
    final props = _extractProperties(source);
    final clave = _extractClave(props);
    if (clave != null && clave.isNotEmpty) {
      claves.add(clave);
    }
  }
  return claves;
}
