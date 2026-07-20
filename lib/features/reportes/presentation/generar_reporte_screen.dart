import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/browser_download.dart';
import '../../predios/providers/predios_provider.dart';
import '../../predios/models/predio.dart';
import '../../auth/providers/auth_provider.dart';

// Variables para fuentes - se inicializan en el método de generación
late pw.Font notoSansRegular;
late pw.Font notoSansBold;

// Constante para tamaño de texto estándar
const _fontSize = 9.0;

class GenerarReporteScreen extends ConsumerStatefulWidget {
  final String? proyectoInicial;
  
  const GenerarReporteScreen({super.key, this.proyectoInicial});

  @override
  ConsumerState<GenerarReporteScreen> createState() => _GenerarReporteScreenState();
}

class _GenerarReporteScreenState extends ConsumerState<GenerarReporteScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  
  String _proyectoActual = 'TQI';
  String _datosNumericosDe = 'Proyecto';
  String? _segmentoSeleccionado;
  
  // Controladores para el formulario
  final _paraNombreCtrl = TextEditingController();
  final _paraCargoCtrl = TextEditingController();
  final _deNombreCtrl = TextEditingController();
  final _deCargoCtrl = TextEditingController();
  int _previewTimestamp = 0;
  final _asuntoCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  
  // Controladores para elaborar y revisar
  final _elaboroCtrl = TextEditingController();
  final _revisoCtrl = TextEditingController();

  final Map<String, int> _consecutivoReportePorProyecto = {
    'TQI': 1,
    'TSNL': 1,
    'TAP': 1,
    'TQM': 1,
  };
  int _numeroReporte = 1;
  bool _isGenerating = false;
  bool _showPreview = false;
  Uint8List? _previewPdfBytes;
  Future<List<Uint8List>>? _webPreviewImagesFuture;
  pw.MemoryImage? _membretadaImage;
  Future<void>? _pdfAssetsInitFuture;

  Future<List<Uint8List>> _rasterizeWebPreview(Uint8List pdfBytes) async {
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(pdfBytes, pages: const [0, 1], dpi: 120)) {
      pages.add(await page.toPng());
      if (pages.length >= 2) break;
    }
    return pages;
  }

  Future<void> _ensurePdfAssetsReady() {
    _pdfAssetsInitFuture ??= () async {
      // Intentar fuentes remotas en paralelo; si fallan, usar fallback local inmediato.
      try {
        final fonts = await Future.wait<pw.Font>([
          PdfGoogleFonts.notoSansRegular().timeout(const Duration(seconds: 4)),
          PdfGoogleFonts.notoSansBold().timeout(const Duration(seconds: 4)),
        ]);
        notoSansRegular = fonts[0];
        notoSansBold = fonts[1];
      } catch (_) {
        notoSansRegular = pw.Font.helvetica();
        notoSansBold = pw.Font.helveticaBold();
      }

      final membretadaBytes = await rootBundle.load('assets/reportes/hoja_membretada.png');
      _membretadaImage = pw.MemoryImage(membretadaBytes.buffer.asUint8List());
    }();
    return _pdfAssetsInitFuture!;
  }

  void _sincronizarNumeroReportePorProyecto() {
    _numeroReporte = _consecutivoReportePorProyecto[_proyectoActual] ?? 1;
  }

  void _avanzarConsecutivoProyectoActual() {
    _consecutivoReportePorProyecto[_proyectoActual] = _numeroReporte + 1;
    _sincronizarNumeroReportePorProyecto();
  }

  @override
  void initState() {
    super.initState();
    // Fallback inmediato para no bloquear en caso de red lenta.
    notoSansRegular = pw.Font.helvetica();
    notoSansBold = pw.Font.helveticaBold();
    // Usar el proyecto inicial si se proporcionó
    if (widget.proyectoInicial != null && _proyectos.contains(widget.proyectoInicial)) {
      _proyectoActual = widget.proyectoInicial!;
    }
    _sincronizarNumeroReportePorProyecto();
    // Establecer el asunto por defecto según el proyecto inicial
    _asuntoCtrl.text = 'Informe del balance actual del proyecto $_proyectoActual';
  }

  void _actualizarAsuntoPorProyecto(String nuevoProyecto) {
    // Solo actualizar si el campo asunto está vacío o tiene el formato anterior
    final textoActual = _asuntoCtrl.text;
    if (textoActual.isEmpty || textoActual.startsWith('Informe del balance actual del proyecto')) {
      _asuntoCtrl.text = 'Informe del balance actual del proyecto $nuevoProyecto';
    }
  }

  @override
  void dispose() {
    _paraNombreCtrl.dispose();
    _paraCargoCtrl.dispose();
    _deNombreCtrl.dispose();
    _deCargoCtrl.dispose();
    _asuntoCtrl.dispose();
    _contenidoCtrl.dispose();
    _elaboroCtrl.dispose();
    _revisoCtrl.dispose();
    super.dispose();
  }
  String _predioProyecto(Predio predicado) {
    final proyectoDirecto = predicado.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predicado.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

    final contenido = [
      predicado.claveCatastral,
      predicado.ejido ?? '',
      predicado.poligonoDwg ?? '',
      predicado.oficio ?? '',
      predicado.copFirmado ?? '',
    ].join(' ').toUpperCase();

    for (final proyecto in _proyectos) {
      if (contenido.contains(proyecto)) return proyecto;
    }

    return 'Sin proyecto';
  }

  List<String> _segmentosDelProyecto(List<Predio> prediosProyecto) {
    final segmentos = prediosProyecto
        .map((p) => p.tramo.trim())
        .where((t) => t.isNotEmpty && t != '-')
        .toSet()
        .toList();
    segmentos.sort();
    return segmentos;
  }

  String _origenNumericoLabel() {
    if (_datosNumericosDe == 'Segmento' && _segmentoSeleccionado != null) {
      return 'Segmento (${_segmentoSeleccionado!})';
    }
    return 'Proyecto';
  }

  String _normalizarTextoPdf(String value, String fallback) {
    final cleaned = value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'^[ \t]+', multiLine: true), '')
        .trimRight();
    if (cleaned.trim().isEmpty) return fallback;
    return cleaned;
  }

  String _buildDonutSvg({
    required int completado,
    required int total,
    required String colorHex,
  }) {
    final progress = total > 0 ? (completado / total).clamp(0.0, 1.0) : 0.0;
    const radius = 38.0;
    final circumference = 2 * math.pi * radius;
    final dash = circumference * progress;
    final gap = circumference - dash;
    final percent = (progress * 100).round();

    return '''
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">
  <g transform="rotate(-90 60 60)">
    <circle cx="60" cy="60" r="$radius" fill="none" stroke="#E5E7EB" stroke-width="14"/>
    <circle cx="60" cy="60" r="$radius" fill="none" stroke="$colorHex" stroke-width="14" stroke-linecap="round" stroke-dasharray="$dash $gap"/>
  </g>
  <text x="60" y="58" text-anchor="middle" font-family="Helvetica" font-size="9" font-weight="700" fill="#111827">$percent%</text>
  <text x="60" y="72" text-anchor="middle" font-family="Helvetica" font-size="9" fill="#6B7280">$completado/$total</text>
</svg>
''';
  }

  pw.Widget _buildPdfDonutCard({
    required String titulo,
    required int completado,
    required int totalReferencia,
  }) {
    return pw.SizedBox(
      height: 94,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            height: 10,
            child: pw.Center(
              child: pw.Text(
                titulo,
                style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
          pw.SizedBox(height: 0),
          pw.SizedBox(
            width: 74,
            height: 74,
            child: pw.SvgImage(
              svg: _buildDonutSvg(
                completado: completado,
                total: totalReferencia,
                colorHex: '#611232',
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTipoPropiedadSection({
    required String titulo,
    required List<Predio> predios,
  }) {
    final total = predios.length;
    final liberados = predios.where((p) => p.cop).length;
    final identificados = predios.where((p) => p.identificacion).length;
    final levantados = predios.where((p) => p.levantamiento).length;
    final negociados = predios.where((p) => p.negociacion).length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          height: 9,
          child: pw.Align(
            alignment: pw.Alignment.topLeft,
            child: pw.Text(
              titulo,
              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
            ),
          ),
        ),
        pw.SizedBox(
          height: 9,
          child: pw.Text(
            'Total de predios: $total',
            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
          ),
        ),
        pw.SizedBox(height: 16),
        _buildPdfDonutCard(
          titulo: 'Predios liberados',
          completado: liberados,
          totalReferencia: total,
        ),
        pw.SizedBox(height: 0),
        _buildPdfDonutCard(
          titulo: 'Predios con identificación',
          completado: identificados,
          totalReferencia: total,
        ),
        pw.SizedBox(height: 0),
        _buildPdfDonutCard(
          titulo: 'Predios con levantamiento',
          completado: levantados,
          totalReferencia: total,
        ),
        pw.SizedBox(height: 0),
        _buildPdfDonutCard(
          titulo: 'Predios con negociación',
          completado: negociados,
          totalReferencia: total,
        ),
      ],
    );
  }

  /// Genera el PDF y guarda en bytes para previsualización
  Future<Uint8List?> _generarPreviewPdf() async {
    if (_isGenerating) return null;

    setState(() => _isGenerating = true);

    try {
      await _ensurePdfAssetsReady();
      final membretadaImage = _membretadaImage!;

      final prediosAsync = ref.read(prediosListProvider);
      final predios = prediosAsync.asData?.value ?? <Predio>[];
      final prediosProyecto = predios.where((p) => _predioProyecto(p) == _proyectoActual).toList();
      final segmentosDisponibles = _segmentosDelProyecto(prediosProyecto);
      final aplicarSegmento =
          _datosNumericosDe == 'Segmento' &&
          _segmentoSeleccionado != null &&
          segmentosDisponibles.contains(_segmentoSeleccionado);
      final prediosBase = aplicarSegmento
          ? prediosProyecto.where((p) => p.tramo.trim() == _segmentoSeleccionado).toList()
          : prediosProyecto;

      final totalPredios = prediosBase.length;
      final conCop = prediosBase.where((p) => p.cop).length;
      final sinCop = prediosBase.where((p) => !p.cop).length;
      final kmEfectivosLiberados = prediosBase
          .where((p) => p.cop)
          .fold<double>(0, (sum, p) => sum + (p.kmEfectivos ?? 0));
      final superficieLiberada = prediosBase
          .where((p) => p.cop)
          .fold<double>(0, (sum, p) => sum + (p.superficie ?? 0));

      final prediosPrivada = prediosBase.where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA').toList();
      final prediosSocialDominio = prediosBase
          .where((p) => p.tipoPropiedad.toUpperCase() == 'SOCIAL' || p.tipoPropiedad.toUpperCase() == 'DOMINIO PLENO')
          .toList();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: notoSansRegular,
          bold: notoSansBold,
        ),
      );

      final ahora = DateTime.now();
      final fechaFormateada = DateFormat('dd/MM/yyyy').format(ahora);
      final proyectoNombre = _proyectoActual;
      final tituloBalance = _datosNumericosDe == 'Segmento'
          ? 'Balance general del segmento'
          : 'Balance general del proyecto';
      final paraNombrePdf = _normalizarTextoPdf(_paraNombreCtrl.text, '(Nombre)');
      final paraCargoPdf = _normalizarTextoPdf(_paraCargoCtrl.text, '(Cargo)');
      final deNombrePdf = _normalizarTextoPdf(_deNombreCtrl.text, '(Nombre)');
      final deCargoPdf = _normalizarTextoPdf(_deCargoCtrl.text, '(Cargo)');
      final elaboroIniciales = _normalizarTextoPdf(_elaboroCtrl.text, '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final revisoIniciales = _normalizarTextoPdf(_revisoCtrl.text, '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final firmaIniciales =
          '${elaboroIniciales.isNotEmpty ? elaboroIniciales : 'N/A'}/${revisoIniciales.isNotEmpty ? revisoIniciales : 'N/A'}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(membretadaImage, fit: pw.BoxFit.fill),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 60, right: 60, top: 100, bottom: 60),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Align(
                        alignment: pw.Alignment.topRight,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.SizedBox(height: 9),
                            pw.Text(
                              'Agencia de Trenes y Transporte Público Integrado',
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Unidad de Verificación, Seguridad y Registro',
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Dirección de Verificación Ferroviaria "A"',
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Ciudad de México a $fechaFormateada',
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  'Asunto: ',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                                pw.Text(
                                  _asuntoCtrl.text.isNotEmpty
                                      ? _asuntoCtrl.text
                                      : 'Informe del balance actual del proyecto $proyectoNombre',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Center(
                        child: pw.Text(
                          'Reporte informativo ($_numeroReporte)',
                          style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PARA: ',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              paraNombrePdf,
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        paraCargoPdf,
                        style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DE: ',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              deNombrePdf,
                              style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        deCargoPdf,
                        style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        'Presente',
                        style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                      ),
                      pw.SizedBox(height: 15),
                      if (_contenidoCtrl.text.isNotEmpty) ...[
                        pw.Text(
                          _contenidoCtrl.text,
                          style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          textAlign: pw.TextAlign.justify,
                        ),
                        pw.SizedBox(height: 20),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tituloBalance,
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Total de predios: $totalPredios\n'
                            'Liberados: $conCop\n'
                            'No liberados: $sinCop\n'
                            'KM efectivos liberados: ${NumberFormat('#,##0.00', 'es_MX').format(kmEfectivosLiberados)}\n'
                            'Superficie liberada: ${NumberFormat('#,##0.00', 'es_MX').format(superficieLiberada)} m²',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansRegular,
                                lineSpacing: 3.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(membretadaImage, fit: pw.BoxFit.fill),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 60, right: 60, top: 100, bottom: 60),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Avance por tipo de propiedad',
                        style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _buildPdfTipoPropiedadSection(
                              titulo: 'Propiedad privada',
                              predios: prediosPrivada,
                            ),
                          ),
                          pw.SizedBox(width: 22),
                          pw.Expanded(
                            child: _buildPdfTipoPropiedadSection(
                              titulo: 'Propiedad social / dominio pleno',
                              predios: prediosSocialDominio,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 40),
                      pw.Center(
                        child: pw.Text(
                          'ATENTAMENTE',
                          style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          firmaIniciales,
                          style: pw.TextStyle(fontSize: 4.5, font: notoSansRegular),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Método para aceptar y generar la previsualización
  Future<void> _aceptar() async {
    if (_datosNumericosDe == 'Segmento' && (_segmentoSeleccionado == null || _segmentoSeleccionado!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un segmento para generar datos numéricos por segmento.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final pdfBytes = await _generarPreviewPdf();
    if (pdfBytes == null || !mounted) return;

    setState(() {
      _previewPdfBytes = pdfBytes;
      _showPreview = true;
      _previewTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        _webPreviewImagesFuture = _rasterizeWebPreview(pdfBytes);
      }
    });
  }

  /// Método para generar y descargar el PDF con nombre automático
  Future<void> _generarPdf() async {
    // Siempre regenerar para evitar descargar una versión en caché.
    final pdfBytes = await _generarPreviewPdf();
    if (pdfBytes == null) return;
    _previewPdfBytes = pdfBytes;
    _previewTimestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // Generar nombre automático: REPORTE_NUMERO_PROYECTO_FECHA
      // Ejemplo: REPORTE_1_TSNL_180626
      final ahora = DateTime.now();
      final fechaArchivo = DateFormat('yyMMdd').format(ahora);
      final nombreArchivo = 'REPORTE_${_numeroReporte}_${_proyectoActual}_$fechaArchivo.pdf';

      if (kIsWeb) {
        await downloadBytesForBrowser(
          _previewPdfBytes!,
          fileName: nombreArchivo,
          mimeType: 'application/pdf',
        );

        if (mounted) {
          setState(_avanzarConsecutivoProyectoActual);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF descargado: $nombreArchivo'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        return;
      }

      // Determinar directorio de descarga según la plataforma
      String directorioDescarga;
      if (Platform.isAndroid || Platform.isIOS) {
        // En móviles, usar el directorio de documentos
        final dir = await getApplicationDocumentsDirectory();
        directorioDescarga = dir.path;
      } else {
        // En desktop, usar el directorio de descargas
        if (Platform.isMacOS) {
          directorioDescarga = (await getDownloadsDirectory())?.path ?? 
              (await getApplicationDocumentsDirectory()).path;
        } else {
          directorioDescarga = (await getDownloadsDirectory())?.path ?? 
              (await getApplicationDocumentsDirectory()).path;
        }
      }

      final filePath = '$directorioDescarga/$nombreArchivo';
      final file = File(filePath);
      await file.writeAsBytes(_previewPdfBytes!);

      if (mounted) {
        setState(_avanzarConsecutivoProyectoActual);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF descargado: $nombreArchivo'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAllProjects = ref.watch(canAccessAllProjectsProvider);
    final proyectosAsignados = ref.watch(currentUserAssignedProjectsProvider);
    final proyectosDisponibles = canAllProjects
        ? _proyectos
        : _proyectos.where(proyectosAsignados.contains).toList(growable: false);

    if (proyectosDisponibles.isEmpty) {
      return const AppScaffold(
        currentIndex: 4,
        title: 'Generar Reporte',
        child: Center(child: Text('Sin proyecto asignado')),
      );
    }

    if (!proyectosDisponibles.contains(_proyectoActual)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _proyectoActual = proyectosDisponibles.first;
          _segmentoSeleccionado = null;
        });
      });
    }

    return AppScaffold(
      currentIndex: 4,
      title: 'Generar Reporte',
      child: _showPreview && _previewPdfBytes != null
          ? _buildPreviewView(proyectosDisponibles)
          : _buildFormView(proyectosDisponibles),
    );
  }

  /// Vista del formulario
  Widget _buildFormView(List<String> proyectosDisponibles) {
    final prediosAsync = ref.watch(prediosListProvider);
    final predios = prediosAsync.asData?.value ?? <Predio>[];
    final prediosProyecto = predios.where((p) => _predioProyecto(p) == _proyectoActual).toList();
    final segmentosDisponibles = _segmentosDelProyecto(prediosProyecto);
    final selectedSegmento = segmentosDisponibles.contains(_segmentoSeleccionado)
        ? _segmentoSeleccionado
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de proyecto
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proyecto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: proyectosDisponibles.contains(_proyectoActual)
                        ? _proyectoActual
                        : proyectosDisponibles.first,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: proyectosDisponibles.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _proyectoActual = v;
                          _segmentoSeleccionado = null;
                          _sincronizarNumeroReportePorProyecto();
                        });
                        _actualizarAsuntoPorProyecto(v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Formulario del reporte
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos del Reporte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
// Número de reporte automático: proyecto-fechaHora
                  Row(
                    children: [
                      const Text('Número de reporte:'),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$_proyectoActual-$_numeroReporte',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // PARA
                  const Text(
                    'PARA:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paraNombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paraCargoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cargo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // DE
                  const Text(
                    'DE:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deNombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deCargoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cargo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Asunto
                  TextField(
                    controller: _asuntoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Asunto',
                      border: OutlineInputBorder(),
                      hintText: 'Informe del balance actual del proyecto (nombre)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Contenido adicional
                  const Text(
                    'Contenido adicional:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contenidoCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Contenido adicional',
                      border: OutlineInputBorder(),
                      hintText: 'Escribe el contenido del reporte...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ELABORO y REVISO
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ELABORO:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _elaboroCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Iniciales',
                                border: OutlineInputBorder(),
                                hintText: 'Ejemplo: ABCD',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REVISO:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _revisoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Iniciales',
                                border: OutlineInputBorder(),
                                hintText: 'Ejemplo: EFGH',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Colocar Datos Numéricos de:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: 'Proyecto',
                    groupValue: _datosNumericosDe,
                    title: const Text('Proyecto'),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _datosNumericosDe = v);
                    },
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: 'Segmento',
                    groupValue: _datosNumericosDe,
                    title: const Text('Segmento'),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _datosNumericosDe = v);
                    },
                  ),
                  if (_datosNumericosDe == 'Segmento') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSegmento,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona segmento',
                        border: OutlineInputBorder(),
                      ),
                      items: segmentosDisponibles
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _segmentoSeleccionado = v),
                    ),
                    if (segmentosDisponibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No hay segmentos disponibles para el proyecto seleccionado.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Botón Aceptar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isGenerating 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isGenerating ? 'Generando...' : 'Aceptar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isGenerating ? null : _aceptar,
            ),
          ),
        ],
      ),
    );
  }

  /// Vista de previsualización
  Widget _buildPreviewView(List<String> proyectosDisponibles) {
    return Row(
      children: [
        // Panel izquierdo - formulario (reducido)
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de proyecto
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proyecto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: proyectosDisponibles.contains(_proyectoActual)
                              ? _proyectoActual
                              : proyectosDisponibles.first,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: proyectosDisponibles.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _proyectoActual = v);
                              _actualizarAsuntoPorProyecto(v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Resumen del reporte
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del Reporte',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Número de reporte automático
                        Row(
                          children: [
                            const Text('Número de reporte:'),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(color: Colors.blue.shade200),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$_proyectoActual-$_numeroReporte',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // PARA
                        Text(
                          'PARA: ${_paraNombreCtrl.text.isNotEmpty ? _paraNombreCtrl.text : "(Sin nombre)"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${_paraCargoCtrl.text.isNotEmpty ? _paraCargoCtrl.text : "(Sin cargo)"}',
                          textAlign: TextAlign.left,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        
                        // DE
                        Text(
                          'DE: ${_deNombreCtrl.text.isNotEmpty ? _deNombreCtrl.text : "(Sin nombre)"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${_deCargoCtrl.text.isNotEmpty ? _deCargoCtrl.text : "(Sin cargo)"}',
                          textAlign: TextAlign.left,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Datos numéricos de: ${_origenNumericoLabel()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _showPreview = false;
                            _previewPdfBytes = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isGenerating 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(_isGenerating ? 'Descargando...' : 'Generar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isGenerating ? null : _generarPdf,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Divisor
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        
        // Panel derecho - previsualización
        Expanded(
          child: Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                // Encabezado
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.preview, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Previsualización del Reporte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'REPORTE_${_numeroReporte}_${_proyectoActual}_${DateFormat('yyMMdd').format(DateTime.now())}.pdf',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Visor del PDF
                Expanded(
                  child: _previewPdfBytes == null
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : kIsWeb
                          ? FutureBuilder<List<Uint8List>>(
                              future: _webPreviewImagesFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'No fue posible renderizar la previsualización en web.',
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final bytes = _previewPdfBytes;
                                              if (bytes == null) return;
                                              setState(() {
                                                _webPreviewImagesFuture = _rasterizeWebPreview(bytes);
                                              });
                                            },
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Reintentar'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final images = snapshot.data ?? const <Uint8List>[];
                                if (images.isEmpty) {
                                  return const Center(
                                    child: Text('No hay páginas para mostrar.'),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: images.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    return Card(
                                      elevation: 2,
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Image.memory(
                                          images[index],
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : PdfPreview(
                              key: ValueKey<int>(_previewTimestamp),
                              build: (format) async => _previewPdfBytes!,
                              canChangeOrientation: false,
                              canChangePageFormat: false,
                              canDebug: false,
                              allowPrinting: false,
                              allowSharing: false,
                              pdfFileName: 'preview.pdf',
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
