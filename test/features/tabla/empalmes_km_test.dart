import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/core/utils/import_normalization.dart' as norm;
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/tabla/utils/empalmes_km.dart';

Predio predio(String id, double? inicio, double? fin) => Predio(
  id: id, claveCatastral: id, tramo: 'S1', tipoPropiedad: 'PRIVADA',
  kmInicio: inicio, kmFin: fin, createdAt: DateTime(2026),
);

void main() {
  test('320+100 como fin e inicio compartido no es empalme', () {
    expect(detectarEmpalmesKm([
      predio('X', norm.normalizeKmValue('319+000'), norm.normalizeKmValue('320+100')),
      predio('Y', norm.normalizeKmValue('320+100'), norm.normalizeKmValue('325+000')),
    ]), isEmpty);
  });
  test('320+100–325+000 y 324+300–328+200 se marcan ambos', () {
    expect(detectarEmpalmesKm([
      predio('X', norm.normalizeKmValue('320+100'), norm.normalizeKmValue('325+000')),
      predio('Y', norm.normalizeKmValue('324+300'), norm.normalizeKmValue('328+200')),
    ]), {'X', 'Y'});
  });
  test('marca ambos registros de un empalme parcial sin depender del orden', () {
    expect(detectarEmpalmesKm([
      predio('b', 15, 25), predio('a', 10, 20), predio('c', 30, 40),
    ]), {'a', 'b'});
  });
  test('detecta intervalos contenidos, idénticos y cadenas de empalmes', () {
    expect(detectarEmpalmesKm([
      predio('a', 0, 10), predio('b', 1, 2), predio('c', 3, 4),
      predio('d', 0, 10), predio('e', 9, 15), predio('f', 14, 20),
    ]), {'a', 'b', 'c', 'd', 'e', 'f'});
  });
  test('extremos adyacentes y registros aislados no se marcan', () {
    expect(detectarEmpalmesKm([
      predio('a', 0, 10), predio('b', 10, 20), predio('c', 21, 22),
    ]), isEmpty);
  });
  test('ignora intervalos incompletos, invertidos o sin longitud', () {
    expect(detectarEmpalmesKm([
      predio('a', null, 10), predio('b', 0, null), predio('c', 9, 2),
      predio('d', 5, 5), predio('e', double.nan, 6),
      predio('f', 0, double.infinity), predio('g', 0, 10),
    ]), isEmpty);
  });
  test('al corregir el intervalo desaparece la marca de ambos registros', () {
    final a = predio('a', 10, 20);
    final b = predio('b', 15, 25);
    expect(detectarEmpalmesKm([a, b]), {'a', 'b'});
    expect(detectarEmpalmesKm([a, b.copyWith(kmInicio: 20)]), isEmpty);
  });
}
