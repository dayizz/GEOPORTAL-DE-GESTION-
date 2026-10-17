import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/estructura/models/proyecto_item.dart';
import 'package:geoportal_predios/features/predios/utils/codigo_division.dart';

void main() {
  ProyectoItem proyecto(String tipo) => ProyectoItem(
    id: 'p', nombre: 'P', descripcion: '', activo: true,
    createdAt: DateTime(2026),
    cadenamientos: [Cadenamiento(id: 'c', tipoDivision: tipo, pks: const [])],
  );

  test('unifica números y sufijos sin duplicar la inicial', () {
    for (final valor in ['15B', 'S15B', ' s15b ']) {
      expect(normalizarCodigoDivision(valor, proyecto('Segmento')), 'S15B');
    }
    expect(normalizarCodigoDivision('19', proyecto('Segmento')), 'S19');
    expect(normalizarCodigoDivision('15A1', proyecto('Segmento')), 'S15A1');
  });

  test('usa el tipo de división configurado para cada proyecto', () {
    expect(normalizarCodigoDivision('19', proyecto('Tramo')), 'T19');
    expect(normalizarCodigoDivision('15B', proyecto('Frente')), 'F15B');
  });

  test('respeta la selección explícita aunque difiera del proyecto', () {
    expect(normalizarCodigoDivision('T15B', proyecto('Segmento')), 'T15B');
    expect(normalizarCodigoDivision('F19', proyecto('Tramo')), 'F19');
  });

  test('conserva códigos sin dato sin inventar números', () {
    expect(normalizarCodigoDivision('S/T'), 'S/T');
    expect(normalizarCodigoDivision(''), '');
  });
}
