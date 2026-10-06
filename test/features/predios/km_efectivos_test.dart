import 'package:geoportal_predios/features/reportes/utils/balance_calculos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';

void main() {
  Predio predio({double? efectivos, double? inicio = 1.1, double? fin = 3.4}) => Predio(
    id: '1', claveCatastral: '1', tramo: 'S13', tipoPropiedad: 'PRIVADA',
    createdAt: DateTime(2026), kmInicio: inicio, kmFin: fin, kmEfectivos: efectivos);
  test('avance temporal suma km liberados y respeta fecha de corte', () {
    final liberado = predio().copyWith(rangoEstatus: 'Liberado');
    expect(cumulativePctKmLiberado([liberado, predio(efectivos: 8)],
      longitudKm: 10, finesDePeriodo: [DateTime(2025), DateTime(2026, 2)]),
      [0, closeTo(23, 0.00001)]);
  });
  test('periodos sin liberaciones fechadas quedan en cero', () {
    final registro = predio().copyWith(rangoEstatus: 'Liberado', copFecha: DateTime(2026, 2, 10));
    final valores = pctMedidaLiberadaPorPeriodo([registro, predio().copyWith(rangoEstatus: 'Liberado')],
      medidaTotal: 10,
      inicios: [DateTime(2026, 1), DateTime(2026, 2), DateTime(2026, 3)],
      fines: [DateTime(2026, 2), DateTime(2026, 3), DateTime(2026, 4)]);
    expect(valores, [0, closeTo(23, 0.00001), 0]);
  });
  test('calcula faltantes y los incluye al guardar', () {
    expect(predio().kmEfectivos, 2.3);
    expect(predio().toMap()['km_efectivos'], 2.3);
    expect(predio().copyWith(kmFin: 4.1).kmEfectivos, 3);
  });
  test('conserva valores capturados y no calcula extremos inválidos', () {
    expect(predio(efectivos: 0).kmEfectivos, 0);
    expect(predio(efectivos: 1).kmEfectivos, 1);
    expect(predio(inicio: null).kmEfectivos, isNull);
    expect(predio(fin: 0).kmEfectivos, isNull);
    expect(predio(inicio: 0, fin: 0).kmEfectivos, 0);
  });
}
