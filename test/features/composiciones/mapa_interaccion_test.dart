import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/mapa_viewport_widget.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/elemento_box.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';

void main() {
  testWidgets('resize reuses parsed polygons; changed data invalidates cache', (tester) async {
    final feature = <String, dynamic>{'geometry': {'type': 'Polygon', 'coordinates': [
      [[-100.35,20.72],[-100.34,20.72],[-100.34,20.73],[-100.35,20.72]]
    ]}};
    Widget view(double width, List<Map<String, dynamic>> features) => MaterialApp(home: Scaffold(
      body: SizedBox(width: width, height: 250, child: MapaViewportWidget(
        lat: 20.72, lng: -100.35, zoom: 12, predios: const [],
        importedFeatures: features, baseLayer: 'sinMapa',
      )),
    ));
    await tester.pumpWidget(view(300, [feature])); await tester.pump();
    final before = tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons;
    expect(before, hasLength(1));
    await tester.pumpWidget(view(450, [feature])); await tester.pump();
    expect(tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons, same(before));
    await tester.pumpWidget(view(450, [])); await tester.pump();
    expect(tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving a map applies pointer movement once', (tester) async {
    var element = ElementoComposicion.mapa(lat: 20.72, lng: -100.35, zoom: 12, proyecto: 'P', x: 30, y: 30)
      .copyWith(width: 200, height: 160, mapaBaseLayer: 'sinMapa');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, update) {
      return Stack(children: [ElementoBox(
        elemento: element, scale: 1, hojaAnchoMm: 800, hojaAltoMm: 600,
        seleccionado: true, onSelect: () {},
        onGeometriaChanged: (x,y,w,h) => update(() { element = element.copyWith(x:x,y:y,width:w,height:h); }),
      )]);
    }))));
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(25, 15)); await tester.pump();
    await gesture.moveBy(const Offset(25, 15)); await tester.pump();
    await gesture.up(); await tester.pump(const Duration(milliseconds: 400));
    expect(element.x, 80);
    expect(element.y, 60);
    expect(element.width, 200);
    final corner = await tester.startGesture(const Offset(278, 218));
    await corner.moveBy(const Offset(20, 20)); await tester.pump();
    await corner.moveBy(const Offset(20, 20)); await tester.pump();
    await corner.up(); await tester.pump(const Duration(milliseconds: 400));
    expect(element.x, 80);
    expect(element.y, 60);
    expect(element.width, greaterThan(200));
    expect(element.height, greaterThan(160));
    expect(tester.takeException(), isNull);
  });
}
