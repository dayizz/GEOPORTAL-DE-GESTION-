import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/mapa/utils/trazo_metadata.dart';
void main() {
  test('lee tipo, proyecto y divisiones sin perder identificadores alfanuméricos', () {
    final feature = <String, dynamic>{'properties': {'tipo de linea': 'DDV historico', 'PROYECTO': 'tqi', 'T/F/S': 'S15A1'}};
    expect(tipoLineaTrazo(feature), 'DDV histórico');
    expect(proyectoTrazo(feature), 'TQI');
    expect(divisionTrazo(feature), 'S15A1');
    expect(tiposLinea.map(colorTipoLinea).toSet().length, 4);
  });
  test('compatibilidad antigua y unión sin duplicar trazos', () {
    final feature = <String, dynamic>{'geometry': {'type':'LineString','coordinates': [[1,2],[3,4]]}, 'properties': {'tramo': 'T2'}};
    expect(tipoLineaTrazo(feature), 'Envolvente de proyecto');
    expect(divisionTrazo(feature), 'T2');
    expect(divisionTrazo({}), 'Sin T/F/S');
    expect(combinarTrazos([feature], [feature]).length, 1);
    final carga = {...feature, 'properties': {'tramo': 'T2', '__tipo_linea':'Eje de carga'}};
    expect(combinarTrazos([feature], [carga]).length, 2);
  });
}
