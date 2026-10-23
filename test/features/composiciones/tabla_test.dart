import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/panel_propiedades_tabla.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/elemento_contenido.dart';

void main() {
  test('tabla conserva celdas al guardar, recuperar y mover sin arrays anidados en Firestore', () {
    final tabla = ElementoComposicion.tabla(x: 1, y: 2, celdas: [['Clave', 'KM'], ['S1', '35+100']]);
    final datos = tabla.toMap();
    expect((datos['tabla_celdas'] as List).first, isA<Map>());
    final recuperada = ElementoComposicion.fromMap(datos).copyWith(x: 10);
    expect(recuperada.tipo, TipoElemento.tabla);
    expect(recuperada.tablaCeldas, tabla.tablaCeldas);
    expect(recuperada.x, 10);
  });
  testWidgets('inserta y edita celdas, agrega filas y renderiza para exportación', (tester) async {
    List<List<String>>? resultado;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 252, child: PanelPropiedadesTabla(onChanged: (v) => resultado = v)))));
    expect(find.byType(TextField), findsNWidgets(9));
    await tester.enterText(find.byType(TextField).first, 'Predio');
    await tester.tap(find.text('+ Fila'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(12));
    await tester.tap(find.text('+ Columna'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(16));
    expect(find.byType(AlertDialog), findsNothing);
    expect(resultado!.first.first, 'Predio');
    final tabla = ElementoComposicion.tabla(x: 0, y: 0, celdas: resultado!);
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 500, height: 200, child: buildElementoContenidoEstatico(tabla))));
    expect(find.text('Predio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
