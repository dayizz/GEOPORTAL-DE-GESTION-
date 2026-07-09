import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/predios/providers/local_predios_provider.dart';

Predio buildPredio({required String id, required String claveCatastral}) {
  return Predio(
    id: id,
    claveCatastral: claveCatastral,
    tramo: 'T1',
    tipoPropiedad: 'PRIVADA',
    createdAt: DateTime(2026),
  );
}

void main() {
  test('removeByClaves removes matching predios using normalized clave values', () {
    final notifier = LocalPrediosNotifier();

    notifier.upsertMany([
      buildPredio(id: '1', claveCatastral: ' abc-123 '),
      buildPredio(id: '2', claveCatastral: 'XYZ-999'),
      buildPredio(id: '3', claveCatastral: 'LMN-555'),
    ]);

    final removed = notifier.removeByClaves({'ABC-123', 'XYZ-999'});

    expect(removed, 2);
    expect(
      notifier.state.map((predio) => predio.claveCatastral).toList(),
      ['LMN-555'],
    );
  });
}