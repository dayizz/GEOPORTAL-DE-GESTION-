import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/core/utils/import_normalization.dart';

void main() {
  test('la misma clave en proyectos distintos produce llaves distintas', () {
    expect(llaveClaveProyecto('N/D-36', 'TQS'), isNot(llaveClaveProyecto('N/D-36', 'TIG')));
    expect(llaveClaveProyecto('N/D-100', 'TQS'), 'TQS|N/D-100');
  });

  test('normaliza mayúsculas, espacios y el alias TQM', () {
    expect(llaveClaveProyecto(' n/d-36 ', 'tqs'), llaveClaveProyecto('N/D-36', 'TQS'));
    expect(llaveClaveProyecto('A-1', 'TQM'), llaveClaveProyecto('A-1', 'TMQ'));
  });

  test('sin clave no hay llave; sin proyecto no se mezcla con uno con proyecto', () {
    expect(llaveClaveProyecto('', 'TQS'), isNull);
    expect(llaveClaveProyecto('N/D-36', null), isNot(llaveClaveProyecto('N/D-36', 'TQS')));
  });
}
