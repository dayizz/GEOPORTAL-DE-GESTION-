import '../../estructura/models/proyecto_item.dart';

/// Conserva prefijos explícitos y resuelve códigos sin letra con Estructura.
String normalizarCodigoDivision(String value, [ProyectoItem? proyecto]) {
  var codigo = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  codigo = codigo.replaceFirstMapped(
    RegExp(r'^([STF]?)0+(\d)'),
    (m) => '${m[1]}${m[2]}',
  );
  if (!RegExp(r'^\d').hasMatch(codigo)) return codigo;
  final candidatos = <String>{};
  for (final bloque in proyecto?.cadenamientos ?? <Cadenamiento>[]) {
    for (final pk in bloque.pks) {
      if (pk.numeroId.trim().toUpperCase() == codigo) {
        candidatos.add('${bloque.letra}$codigo');
      }
    }
  }
  if (candidatos.length == 1) return candidatos.single;
  if (candidatos.length > 1) return codigo;
  final letras =
      proyecto?.cadenamientos.map((b) => b.letra).toSet() ?? <String>{};
  return '${letras.length == 1 ? letras.single : 'S'}$codigo';
}
