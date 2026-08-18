import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

import '../../../core/utils/browser_download.dart';
import '../../carga/utils/file_download_io.dart';
import '../../estructura/models/proyecto_item.dart';
import '../../predios/models/predio.dart';
import '../models/composicion.dart';
import '../models/elemento_composicion.dart';
import '../models/hoja.dart';
import '../presentation/widgets/hoja_export_widget.dart';
import 'pptx_writer.dart';

/// Rasteriza hojas de una [Composicion] a PNG/JPG y arma el PDF completo,
/// reutilizando el patrón ya establecido en el resto de la app para
/// exportar (`ScreenshotController` + `package:image` + `package:pdf`,
/// ver `lib/features/mapa/utils/screenshot_crop_controller.dart` y
/// `lib/features/reportes/presentation/generar_reporte_screen.dart`) y
/// para descargar en el navegador (`browser_download.dart`).
class ComposicionExportService {
  /// Resolución de exportación en puntos por pulgada. 150dpi es un buen
  /// equilibrio entre calidad de impresión y tamaño de archivo/tiempo de
  /// captura para hojas grandes (A1/A2).
  static const double dpiPorDefecto = 150;

  final _screenshotController = ScreenshotController();

  double _pxPorMm(double dpi) => dpi / 25.4;

  /// Rasteriza una hoja a PNG. Requiere un [context] montado (se usa para
  /// heredar tema/fuentes durante la captura offscreen, ver
  /// `ScreenshotController.captureFromWidget`). [predios] ya debe venir
  /// resuelto (y filtrado por proyecto) por quien llama, para los
  /// elementos de tipo mapa -ver `MapaViewportWidget`-.
  Future<Uint8List> capturarHojaPng(
    BuildContext context,
    Hoja hoja, {
    double dpi = dpiPorDefecto,
    List<Predio> predios = const [],
    ProyectoItem? proyectoItem,
  }) async {
    final scale = _pxPorMm(dpi);
    final (anchoMm, altoMm) = hoja.dimensionesMm;
    final anchoPx = anchoMm * scale;
    final altoPx = altoMm * scale;
    // Los tiles del mapa se cargan por red de forma asíncrona; sin mapa
    // 300ms alcanza para que fuentes/imágenes embebidas asienten, con
    // mapa se da más margen para que los tiles lleguen antes de capturar.
    final tieneMapa = hoja.elementos.any((e) => e.tipo == TipoElemento.mapa && e.visible);

    return _screenshotController.captureFromWidget(
      HojaExportWidget(
        hoja: hoja,
        anchoPx: anchoPx,
        altoPx: altoPx,
        scale: scale,
        predios: predios,
        proyectoItem: proyectoItem,
      ),
      context: context,
      delay: Duration(milliseconds: tieneMapa ? 1500 : 300),
      pixelRatio: 1.0,
      targetSize: Size(anchoPx, altoPx),
    );
  }

  Future<Uint8List> capturarHojaJpg(
    BuildContext context,
    Hoja hoja, {
    double dpi = dpiPorDefecto,
    int calidad = 92,
    List<Predio> predios = const [],
    ProyectoItem? proyectoItem,
  }) async {
    final pngBytes = await capturarHojaPng(context, hoja, dpi: dpi, predios: predios, proyectoItem: proyectoItem);
    final decodificada = img.decodePng(pngBytes);
    if (decodificada == null) return pngBytes;
    // Los JPG no soportan transparencia; se aplana sobre blanco.
    final aplanada = img.Image(width: decodificada.width, height: decodificada.height, numChannels: 3)
      ..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(aplanada, decodificada);
    return Uint8List.fromList(img.encodeJpg(aplanada, quality: calidad));
  }

  /// Arma un PDF con una página por hoja, cada una del tamaño exacto de
  /// la hoja (respetando orientación) y con el raster de esa hoja
  /// llenando la página completa (sin márgenes de PDF adicionales: el
  /// margen ya es parte del diseño de la hoja si el usuario lo definió).
  Future<Uint8List> exportarPdf(
    BuildContext context,
    Composicion composicion, {
    double dpi = dpiPorDefecto,
    List<Predio> predios = const [],
    ProyectoItem? proyectoItem,
  }) async {
    final pdf = pw.Document();
    for (final hoja in composicion.hojas) {
      if (!context.mounted) break;
      final pngBytes =
          await capturarHojaPng(context, hoja, dpi: dpi, predios: predios, proyectoItem: proyectoItem);
      final (anchoMm, altoMm) = hoja.dimensionesMm;
      final pageFormat = PdfPageFormat(anchoMm * PdfPageFormat.mm, altoMm * PdfPageFormat.mm);
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fill),
        ),
      );
    }
    return pdf.save();
  }

  /// Arma un `.pptx` con una diapositiva por hoja, cada una como el mismo
  /// raster PNG usado para PNG/PDF (ver `PptxWriter` para el alcance y
  /// las limitaciones de este generador OOXML propio).
  Future<Uint8List> exportarPptx(
    BuildContext context,
    Composicion composicion, {
    double dpi = dpiPorDefecto,
    List<Predio> predios = const [],
    ProyectoItem? proyectoItem,
  }) async {
    final slides = <PptxSlideImage>[];
    for (final hoja in composicion.hojas) {
      if (!context.mounted) break;
      final pngBytes =
          await capturarHojaPng(context, hoja, dpi: dpi, predios: predios, proyectoItem: proyectoItem);
      final (anchoMm, altoMm) = hoja.dimensionesMm;
      slides.add(PptxSlideImage(pngBytes: pngBytes, anchoMm: anchoMm, altoMm: altoMm));
    }
    return PptxWriter.build(slides, titulo: composicion.nombre);
  }

  Future<void> descargar(Uint8List bytes, {required String fileName, required String mimeType}) async {
    if (kIsWeb) {
      await downloadBytesForBrowser(bytes, fileName: fileName, mimeType: mimeType);
    } else {
      await downloadBytes(bytes, fileName: fileName, mimeType: mimeType);
    }
  }
}
