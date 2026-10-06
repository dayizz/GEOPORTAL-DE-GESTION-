import '../../../core/utils/import_normalization.dart' as norm;
import '../../estructura/models/proyecto_item.dart';
import '../../predios/models/predio.dart';
import 'balance_calculos.dart';

String claveTramoBalance(String value, [ProyectoItem? proyecto]) {
  var codigo = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  codigo = codigo.replaceFirstMapped(
    RegExp(r'^([STF]?)0+(\d)'),
    (m) => '${m[1]}${m[2]}',
  );
  if (!RegExp(r'^\d').hasMatch(codigo)) return codigo;
  final candidatos = <String>{};
  for (final bloque in proyecto?.cadenamientos ?? <Cadenamiento>[]) {
    for (final pk in bloque.pks) {
      if (pk.numeroId.trim().toUpperCase() == codigo)
        candidatos.add('${bloque.letra}$codigo');
    }
  }
  if (candidatos.length == 1) return candidatos.single;
  if (candidatos.length > 1) return codigo;
  final letras =
      proyecto?.cadenamientos.map((b) => b.letra).toSet() ?? <String>{};
  return '${letras.length == 1 ? letras.single : 'S'}$codigo';
}

class ResumenTramoBalance {
  final String codigo;
  final double? inicio, fin;
  final List<Predio> predios;
  ResumenTramoBalance(this.codigo, this.inicio, this.fin, this.predios);
  double? get longitud =>
      inicio != null && fin != null && fin! > inicio! ? fin! - inicio! : null;
  int get liberados => predios.where(predioEstaLiberado).length;
  double get kmLiberados => predios
      .where(predioEstaLiberado)
      .fold(0.0, (s, p) => s + (p.kmEfectivos ?? 0));
  double? get porcentaje =>
      longitud == null ? null : kmLiberados / longitud! * 100;
}

class ResumenMunicipioInfraestructuraBalance {
  final String codigoTramo;
  final String municipio;
  final CategoriaEstacionesBalance categoria;
  final List<Predio> predios;

  const ResumenMunicipioInfraestructuraBalance({
    required this.codigoTramo,
    required this.municipio,
    required this.categoria,
    required this.predios,
  });

  String get tipoInfraestructura => switch (categoria) {
    CategoriaEstacionesBalance.estaciones => 'Estación',
    CategoriaEstacionesBalance.edificiosAuxiliares => 'Edificio Auxiliar',
    CategoriaEstacionesBalance.zica => 'ZICA',
  };

  int get liberados => predios.where(predioEstaLiberado).length;
  double get superficieTotal => predios.fold<double>(
    0,
    (total, predio) => total + (predio.superficie ?? 0),
  );
  double get superficieLiberada => predios
      .where(predioEstaLiberado)
      .fold<double>(0, (total, predio) => total + (predio.superficie ?? 0));
  double? get porcentaje =>
      superficieTotal > 0 ? superficieLiberada / superficieTotal * 100 : null;
}

List<ResumenMunicipioInfraestructuraBalance>
resumenMunicipioInfraestructuraBalance(Iterable<ResumenTramoBalance> filas) {
  final grupos = <(String, String, CategoriaEstacionesBalance), List<Predio>>{};
  final municipios = <(String, String, CategoriaEstacionesBalance), String>{};

  for (final fila in filas) {
    for (final predio in fila.predios) {
      final categoria = categoriaEstacionesBalance(predio.estructura);
      if (categoria == null) continue;
      final municipio = predio.municipio?.trim();
      final nombreMunicipio = municipio == null || municipio.isEmpty
          ? 'Sin municipio'
          : municipio;
      final municipioNormalizado = norm
          .stripAccents(nombreMunicipio)
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      final clave = (fila.codigo, municipioNormalizado, categoria);
      grupos.putIfAbsent(clave, () => []).add(predio);
      municipios.putIfAbsent(clave, () => nombreMunicipio);
    }
  }

  final resumen = [
    for (final entrada in grupos.entries)
      ResumenMunicipioInfraestructuraBalance(
        codigoTramo: entrada.key.$1,
        municipio: municipios[entrada.key]!,
        categoria: entrada.key.$3,
        predios: entrada.value,
      ),
  ];
  resumen.sort((a, b) {
    final tramo = a.codigoTramo.compareTo(b.codigoTramo);
    if (tramo != 0) return tramo;
    final municipio = a.municipio.compareTo(b.municipio);
    return municipio != 0
        ? municipio
        : a.categoria.index.compareTo(b.categoria.index);
  });
  return resumen;
}

List<ResumenTramoBalance> resumenTramosBalance(
  ProyectoItem? proyecto,
  List<Predio> predios, {
  String? segmento,
}) {
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
      if (segmento != null && codigo != claveTramoBalance(segmento, proyecto))
        continue;
      limites[codigo] = (
        norm.normalizeKmValue(pk.pkInicio),
        norm.normalizeKmValue(pk.pkFin),
      );
    }
  }
  final codigos = {
    ...limites.keys,
    ...grupos.keys,
  }.where((codigo) => codigo != 'S15A').toList()..sort();
  return [
    for (final codigo in codigos)
      ResumenTramoBalance(
        codigo,
        limites[codigo]?.$1,
        limites[codigo]?.$2,
        grupos[codigo] ?? [],
      ),
  ];
}
