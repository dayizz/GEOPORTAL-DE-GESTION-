import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/models/hoja.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';
import 'package:geoportal_predios/features/composiciones/utils/limites_hoja.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/hoja_export_widget.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/numero_pagina_widget.dart';

void main() {
  test('configuración personalizada y márgenes independientes sobreviven el guardado', () {
    final h = Hoja.nueva(nombre: 'Prueba').copyWith(tamano: TamanoHoja.personalizado,
      anchoPersonalizadoMm: 250, altoPersonalizadoMm: 400,
      margenSuperiorMm: 11, margenInferiorMm: 12, margenIzquierdoMm: 13, margenDerechoMm: 14,
      numerarPagina: true, inicioPagina: 2, posicionPagina: PosicionPagina.inferiorDerecha, opacidadFondo: .4);
    final r = Hoja.fromMap(h.toMap());
    expect(r.dimensionesMm, (400.0, 250.0));
    expect(r.copyWith(horizontal: false).dimensionesMm, (250.0, 400.0));
    expect([r.margenArriba, r.margenAbajo, r.margenIzquierda, r.margenDerecha], [11,12,13,14]);
    expect(r.opacidadFondo, .4);
    expect(r.posicionPagina, PosicionPagina.inferiorDerecha);
    expect(r.numeroEnHoja(0), isNull);
    expect(r.numeroEnHoja(1), 1);
    expect(r.numeroEnHoja(2), 2);
    final e = limitarElementoAHoja(ElementoComposicion.texto(x: -100, y: 300), r);
    expect(e.x, greaterThanOrEqualTo(13));
    expect(e.y + e.height, lessThanOrEqualTo(238));
  });
  test('hojas antiguas conservan margen uniforme y numeración desactivada', () {
    final h = Hoja.fromMap({'id':'a', 'margen_mm':15});
    expect([h.margenArriba,h.margenAbajo,h.margenIzquierda,h.margenDerecha], [15,15,15,15]);
    expect(h.numeroEnHoja(0), isNull);
    expect(h.opacidadFondo, 1);
  });
  testWidgets('exportación muestra número y posición desde la hoja elegida', (tester) async {
    final h = Hoja.nueva(nombre: 'Prueba').copyWith(numerarPagina: true, inicioPagina: 3, posicionPagina: PosicionPagina.superiorCentral, opacidadFondo: .5);
    for (final i in [1,2,3]) {
      await tester.pumpWidget(MaterialApp(home: Center(child: HojaExportWidget(hoja:h, indiceHoja:i, anchoPx:297, altoPx:210, scale:1))));
      expect(find.byType(NumeroPaginaWidget), findsOneWidget);
      expect(find.text('${i - 1}'), i == 1 ? findsNothing : findsOneWidget);
      if (i >= 2) expect(tester.getTopLeft(find.text('${i - 1}')).dy, lessThan(220));
      expect(tester.takeException(), isNull);
    }
  });
}
