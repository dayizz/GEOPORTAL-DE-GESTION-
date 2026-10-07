import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/utils/import_normalization.dart' as norm;

const tiposLinea = ['Envolvente de proyecto', 'DDV histórico', 'Eje de carga', 'Eje de pasajeros'];
Color colorTipoLinea(String tipo) => switch (tipo) {
  'DDV histórico' => const Color(0xFF006A4E),
  'Eje de carga' => const Color(0xFF001F54),
  'Eje de pasajeros' => const Color(0xFFE53935),
  _ => const Color(0xFFFF8C00),
};
String _clave(String value) => norm.stripAccents(value).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
String propiedadTrazo(Map<String, dynamic> feature, List<String> claves) {
  final props = feature['properties'];
  if (props is! Map) return '';
  for (final clave in claves) {
    for (final entry in props.entries) {
      if (_clave(entry.key.toString()) == _clave(clave)) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
    }
  }
  return '';
}
String tipoLineaTrazo(Map<String, dynamic> feature) {
  final value = propiedadTrazo(feature, ['__tipo_linea', 'tipo_linea', 'tipo de linea']);
  return tiposLinea.firstWhere((t) => _clave(t) == _clave(value), orElse: () => tiposLinea.first);
}
String proyectoTrazo(Map<String, dynamic> feature) {
  final value = propiedadTrazo(feature, ['__proyecto_trazo', 'proyecto', 'project']);
  return value.isEmpty ? 'Sin proyecto' : value.toUpperCase();
}
String divisionTrazo(Map<String, dynamic> feature) {
  final value = propiedadTrazo(feature, ['__tfs_trazo', 'T/F/S', 'T/S/F', 'S/T/F', 'tramo', 'segmento', 'frente']);
  return value.isEmpty ? 'Sin T/F/S' : value.toUpperCase();
}

List<Map<String, dynamic>> combinarTrazos(
  List<Map<String, dynamic>> actuales, List<Map<String, dynamic>> nuevos,
) {
  final claves = <String>{};
  return [...actuales, ...nuevos].where((f) => claves.add(jsonEncode([
    f['geometry'], proyectoTrazo(f), tipoLineaTrazo(f), divisionTrazo(f), f['properties'],
  ]))).toList();
}
