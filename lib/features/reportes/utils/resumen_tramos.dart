import '../../../core/utils/import_normalization.dart' as norm;
import '../../estructura/models/proyecto_item.dart';
import '../../predios/models/predio.dart';
import 'balance_calculos.dart';

String claveTramoBalance(String value, [ProyectoItem? proyecto]) {
  var codigo = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  codigo = codigo.replaceFirstMapped(RegExp(r'^([STF]?)0+(\d)'), (m) => '${m[1]}${m[2]}');
  if (!RegExp(r'^\d').hasMatch(codigo)) return codigo;
  final candidatos = <String>{};
  for (final bloque in proyecto?.cadenamientos ?? <Cadenamiento>[]) {
    for (final pk in bloque.pks) {
      if (pk.numeroId.trim().toUpperCase() == codigo) candidatos.add('${bloque.letra}$codigo');
    }
  }
  if (candidatos.length == 1) return candidatos.single;
  if (candidatos.length > 1) return codigo;
  final letras = proyecto?.cadenamientos.map((b) => b.letra).toSet() ?? <String>{};
  return '${letras.length == 1 ? letras.single : 'S'}$codigo';
}

class ResumenTramoBalance {
  final String codigo;
  final double? inicio, fin;
  final List<Predio> predios;
  ResumenTramoBalance(this.codigo, this.inicio, this.fin, this.predios);
  double? get longitud => inicio != null && fin != null && fin! > inicio!
      ? fin! - inicio! : null;
  int get liberados => predios.where(predioEstaLiberado).length;
  double get kmLiberados => predios.where(predioEstaLiberado)
      .fold(0.0, (s, p) => s + (p.kmEfectivos ?? 0));
  double? get porcentaje => longitud == null ? null : kmLiberados / longitud! * 100;
}

List<ResumenTramoBalance> resumenTramosBalance(
  ProyectoItem? proyecto, List<Predio> predios, {String? segmento}
) {
  final grupos = <String, List<Predio>>{};
  for (final p in predios) {
    final codigo = claveTramoBalance(p.tramo, proyecto);
    grupos.putIfAbsent(codigo.isEmpty ? 'Sin T/F/S' : codigo, () => []).add(p);
  }
  final limites = <String, (double?, double?)>{};
  for (final bloque in proyecto?.cadenamientos ?? <Cadenamiento>[]) {
    for (final pk in bloque.pks) {
      final codigo = claveTramoBalance('${bloque.letra}${pk.numeroId}');
      if (codigo == 'S15A') continue;
      if (segmento != null && codigo != claveTramoBalance(segmento, proyecto)) continue;
      limites[codigo] = (norm.normalizeKmValue(pk.pkInicio), norm.normalizeKmValue(pk.pkFin));
    }
  }
  final codigos = {...limites.keys, ...grupos.keys}
      .where((codigo) => codigo != 'S15A').toList()..sort();
  return [for (final codigo in codigos)
    ResumenTramoBalance(codigo, limites[codigo]?.$1, limites[codigo]?.$2, grupos[codigo] ?? [])];
}
