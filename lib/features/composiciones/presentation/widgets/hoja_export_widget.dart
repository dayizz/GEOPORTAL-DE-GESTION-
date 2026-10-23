import 'package:flutter/material.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../models/hoja.dart';
import '../../utils/color_hex.dart';
import 'elemento_contenido.dart';
import 'numero_pagina_widget.dart';

/// Render "plano" (sin selección, sin gestos, sin edición) de una [Hoja]
/// completa a un tamaño de píxeles ya resuelto (`anchoPx`/`altoPx`), para
/// rasterizar con `ScreenshotController.captureFromWidget` al exportar
/// (PNG/JPG/PDF). `scale` son los px por mm usados para calcular
/// `anchoPx`/`altoPx`, y se reutiliza para posicionar cada elemento en
/// las mismas unidades que el editor. `predios` ya viene resuelto por
/// quien exporta (necesario para elementos de tipo mapa; ver
/// `MapaViewportWidget` para el porqué no se lee aquí con Riverpod).
class HojaExportWidget extends StatelessWidget {
  const HojaExportWidget({
    super.key,
    required this.hoja,
    this.indiceHoja = 0,
    required this.anchoPx,
    required this.altoPx,
    required this.scale,
    this.predios = const [],
    this.pksFeatures = const [],
    this.proyectoItem,
  });

  final Hoja hoja;
  final int indiceHoja;
  final double anchoPx;
  final double altoPx;
  final double scale;
  final List<Predio> predios;
  final List<Map<String, dynamic>> pksFeatures;
  final ProyectoItem? proyectoItem;

  @override
  Widget build(BuildContext context) {
    // `ScreenshotController.captureFromWidget` ya envuelve el árbol con
    // `Material`/`MediaQuery`/`Directionality` cuando se le pasa un
    // `context` (ver llamada en `ComposicionExportService`), así que no
    // hace falta duplicarlo aquí.
    return SizedBox(
      width: anchoPx,
      height: altoPx,
      child: Container(
        color: (colorFromHex(hoja.colorFondoHex) ?? Colors.white).withValues(alpha: hoja.opacidadFondo.clamp(0, 1)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final e in hoja.elementos)
              if (e.visible)
                Positioned(
                  left: e.x * scale,
                  top: e.y * scale,
                  width: e.width * scale,
                  height: e.height * scale,
                  child: Transform.rotate(
                    angle: e.rotacion * 3.1415926535 / 180,
                    child: buildElementoContenidoEstatico(
                      e,
                      predios: predios,
                      pksFeatures: pksFeatures,
                      hojaElementos: hoja.elementos,
                      scale: scale,
                      proyectoItem: proyectoItem,
                    ),
                  ),
                ),
            Positioned.fill(child: NumeroPaginaWidget(hoja: hoja, indice: indiceHoja, scale: scale)),
          ],
        ),
      ),
    );
  }
}
