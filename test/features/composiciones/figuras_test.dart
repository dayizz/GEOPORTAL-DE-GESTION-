import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/elemento_contenido.dart';

void main() {
  for (final tipo in [TipoFigura.circulo, TipoFigura.cruz, TipoFigura.estrella, TipoFigura.linea]) {
    testWidgets('$tipo se guarda y dibuja con trazo continuo y segmentado', (tester) async {
      final original = ElementoComposicion.forma(figuraTipo: tipo, x: 0, y: 0, width: 120, height: 120);
      final recuperado = ElementoComposicion.fromMap(original.toMap());
      expect(recuperado.figuraTipo, tipo);
      expect(recuperado.nombreCapa, original.nombreCapa);
      for (final estilo in EstiloLinea.values) {
        await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 120, height: 120,
          child: buildElementoContenidoEstatico(recuperado.copyWith(estiloLinea: estilo)),
        ))));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
