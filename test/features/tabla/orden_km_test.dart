import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/tabla/utils/orden_km.dart';

Predio registro(String id, String tramo, double? km) => Predio(
  id: id, claveCatastral: id, tramo: tramo, tipoPropiedad: 'PRIVADA',
  kmInicio: km, createdAt: DateTime(2026),
);

void main() {
  test('mantiene los registros sin KM junto a su división', () {
    final registros = [
      registro('e', 'S10', 100), registro('b', 'S2', null),
      registro('c', 'S2', 21), registro('a', 'S2', 20),
      registro('d', 'S3', null),
    ]..sort(compararPrediosGestion);
    expect(registros.map((p) => p.id), ['a', 'c', 'b', 'd', 'e']);
  });
  test('ordena números y sufijos de forma natural', () {
    final codigos = ['S15B10', 'S15B2', 'S10', 'S2', 'S15B', 'S15A', 'S15'];
    codigos.sort(compararCodigosDivision);
    expect(codigos, ['S2', 'S10', 'S15', 'S15A', 'S15B', 'S15B2', 'S15B10']);
  });
  test('aplica la agrupación a tramos y frentes y deja sin división al final', () {
    for (final prefijo in ['T', 'F']) {
      final registros = [
        registro('c', '${prefijo}10', 1), registro('b', '${prefijo}2', null),
        registro('a', '${prefijo}2', 5), registro('d', 'S/T', 0),
      ]..sort(compararPrediosGestion);
      expect(registros.map((p) => p.id), ['a', 'b', 'c', 'd']);
    }
  });
}
