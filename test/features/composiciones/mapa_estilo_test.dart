import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/mapa_viewport_widget.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/elemento_contenido.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/marco_clipper.dart';

void main() {
  final mapa = ElementoComposicion.mapa(
    lat: 20.72, lng: -100.35, zoom: 12, proyecto: 'P', x: 10, y: 10);
  test('label styles and border survive saving independently; old maps load', () {
    final styled = mapa.copyWith(
      mapaEstiloClave: const EstiloEtiquetaMapa(tamano: 18, colorHex: '#FF0000',
        fuente: 'Arial', bufferColorHex: '#00FF00', bufferGrosor: 4),
      mapaEstiloPks: const EstiloEtiquetaMapa(tamano: 12, bufferGrosor: 0),
      mapaBordeEstilo: EstiloLinea.segmentada,
    );
    final saved = ElementoComposicion.fromMap(styled.toMap());
    expect(saved.mapaEstiloClave.toMap(), styled.mapaEstiloClave.toMap());
    expect(saved.mapaEstiloPks.toMap(), styled.mapaEstiloPks.toMap());
    expect(saved.mapaBordeEstilo, EstiloLinea.segmentada);
    final old = mapa.toMap()..remove('mapa_estilo_clave')
      ..remove('mapa_estilo_pks')..remove('mapa_borde_estilo');
    final loaded = ElementoComposicion.fromMap(old);
    expect(loaded.mapaEstiloClave.tamano, 9);
    expect(loaded.mapaBordeEstilo, EstiloLinea.continua);
  });

  final points = <Map<String, dynamic>>[
    {'geometry': {'type': 'Point', 'coordinates': [-100.35, 20.72]},
      'properties': {'PK': '10+000'}}
  ];
  testWidgets('PK style updates label and buffer without reparsing polygons', (tester) async {
    Widget view(EstiloEtiquetaMapa estilo) => MaterialApp(home: SizedBox(
      width: 500, height: 400, child: MapaViewportWidget(
        lat: 20.72, lng: -100.35, zoom: 12, predios: const [],
        baseLayer: 'sinMapa', mostrarPks: true, pksFeatures: points, estiloPks: estilo,
      )));
    const first = EstiloEtiquetaMapa(fuente: 'Arial', tamano: 9);
    await tester.pumpWidget(view(first)); await tester.pump();
    final layers = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer));
    expect(layers.expand((l) => l.markers), isNotEmpty);
    final polygons = tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons;
    await tester.pumpWidget(view(first.copyWith(tamano: 24, colorHex: '#FF0000', bufferGrosor: 0)));
    await tester.pump();
    final label = tester.widget<Text>(find.text('10+000'));
    expect(label.style!.fontSize, 24);
    expect(label.style!.color, const Color(0xFFFF0000));
    expect(tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons, same(polygons));
    expect(tester.takeException(), isNull);
  });

  testWidgets('export renderer carries label styles, PK data and border style', (tester) async {
    final styled = mapa.copyWith(mapaBaseLayer: 'sinMapa', mapaMostrarPks: true,
      mapaEstiloPks: const EstiloEtiquetaMapa(fuente: 'Arial', tamano: 14),
      mapaBordeActivo: true, mapaBordeEstilo: EstiloLinea.punteada);
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 500, height: 400,
      child: buildElementoContenidoEstatico(styled, pksFeatures: points))));
    await tester.pump();
    final viewport = tester.widget<MapaViewportWidget>(find.byType(MapaViewportWidget));
    expect(viewport.estiloPks.tamano, 14);
    expect(viewport.pksFeatures, points);
    final borders = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter).whereType<MarcoBorderPainter>();
    expect(borders.single.estilo, EstiloLinea.punteada);
    expect(tester.takeException(), isNull);
  });
}
