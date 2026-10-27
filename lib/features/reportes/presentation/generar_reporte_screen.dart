import '../utils/balance_calculos.dart';
import '../utils/resumen_tramos.dart';
import 'dart:typed_data';
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
import '../../estructura/providers/proyectos_provider.dart';

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
  /// Códigos de proyecto vigentes, dados de alta en Estructura (Firestore).
  List<String> get _proyectos => ref.read(proyectosCodigosProvider);

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
  final _reporteNoCtrl = TextEditingController();
  final _remitenteCtrl = TextEditingController(text: 'Dirección de Verificación Ferroviaria "A"');

  // Controladores para elaborar y revisar
  final _elaboroCtrl = TextEditingController();
  final _revisoCtrl = TextEditingController();

  final Map<String, int> _consecutivoReportePorProyecto = {
    'TQI': 1,
    'TSNL': 1,
    'TAP': 1,
    'TMQ': 1,
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
    // Renderizar las páginas que realmente existen: el reporte puede
    // contener una sola hoja y no debe solicitar una segunda inexistente.
    await for (final page in Printing.raster(pdfBytes, dpi: 120)) {
      pages.add(await page.toPng());
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

  /// Número usado en el nombre del archivo: el capturado en "Reporte no."
  /// (saneado para nombre de archivo) o, si está vacío, el consecutivo.
  String get _numeroParaArchivo {
    final capturado = _reporteNoCtrl.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return capturado.isNotEmpty ? capturado : '$_numeroReporte';
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
    _reporteNoCtrl.dispose();
    _remitenteCtrl.dispose();
    _elaboroCtrl.dispose();
    _revisoCtrl.dispose();
    super.dispose();
  }
  String _predioProyecto(Predio predicado) {
    final proyectoDirecto = predicado.proyecto?.trim().toUpperCase();
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    if (proyectoDirecto == 'TQM') return 'TMQ';
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predicado.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TMQ') || compact.startsWith('TQM') || compact.startsWith('QM')) {
      return 'TMQ';
    }

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
    if (contenido.contains('TQM')) return 'TMQ';

    return 'Sin proyecto';
  }

  List<String> _segmentosDelProyecto(List<Predio> prediosProyecto) {
    final segmentos = prediosProyecto
        .map((p) => claveTramoBalance(p.tramo))
        .where((t) => t.isNotEmpty && t != '-')
        .toSet()
        .toList();
    segmentos.sort();
    return segmentos;
  }

  String _origenNumericoLabel() {
    if (_datosNumericosDe == 'Segmento' && _segmentoSeleccionado != null) {
      return 'T/F/S (${_segmentoSeleccionado!})';
    }
    return _datosNumericosDe;
  }

  String _normalizarTextoPdf(String value, String fallback) {
    final cleaned = value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'^[ \t]+', multiLine: true), '')
        .trimRight();
    if (cleaned.trim().isEmpty) return fallback;
    return cleaned;
  }

  /// Genera el PDF y guarda en bytes para previsualización
  Future<Uint8List?> _generarPreviewPdf() async {
    if (_isGenerating) return null;

    setState(() => _isGenerating = true);

    try {
      await _ensurePdfAssetsReady();
      final membretadaImage = _membretadaImage!;

      final predios = _datosNumericosDe == 'Ninguno' ? <Predio>[] : await ref.refresh(prediosMapaProvider.future);
      final prediosProyecto = predios.where((p) => _predioProyecto(p) == _proyectoActual).toList();
      final aplicarSegmento =
          _datosNumericosDe == 'Segmento' &&
          _segmentoSeleccionado != null;
      final prediosBase = aplicarSegmento
          ? prediosProyecto.where((p) => claveTramoBalance(p.tramo) == _segmentoSeleccionado).toList()
          : prediosProyecto;

      final clasificados = prediosBase.where((p) => grupoInfraestructuraBalance(p.estructura) == GrupoInfraestructuraBalance.predios).toList();
      final totalPredios = clasificados.length;
      final conCop = clasificados.where(predioEstaLiberado).length;
      final sinCop = totalPredios - conCop;
      final kmEfectivosLiberados = clasificados.where(predioEstaLiberado)
          .fold<double>(0, (sum, p) => sum + (p.kmEfectivos ?? 0));
      final proyectos = await ref.read(proyectosProvider.future);
      final coincidencias = proyectos.where(
        (p) => p.nombre.trim().toUpperCase() == _proyectoActual,
      );
      final proyecto = coincidencias.isEmpty ? null : coincidencias.first;
      final tramos = resumenTramosBalance(proyecto, const <Predio>[],
        segmento: aplicarSegmento ? _segmentoSeleccionado : null);
      final longitudes = tramos.where((t) => t.longitud != null).toList();
      final formatoKm = NumberFormat('#,##0.###', 'es_MX');
      final totalKmTexto = longitudes.isEmpty
          ? 'Sin longitud registrada'
          : '${formatoKm.format(longitudes.fold<double>(0, (s, t) => s + t.longitud!))} km';

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
      final reporteNoPdf = _reporteNoCtrl.text.trim();
      final remitentePdf = _remitenteCtrl.text.trim();
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
                            if (remitentePdf.isNotEmpty) ...[
                              pw.Text(
                                remitentePdf,
                                style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                              ),
                            ],
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  'Reporte no. ',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                                pw.Text(
                                  reporteNoPdf,
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                                ),
                              ],
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
                      if (_datosNumericosDe != 'Ninguno') pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tituloBalance,
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Total de predios identificados (clasificados): $totalPredios\n'
                            'Total de predios liberados: $conCop\n'
                            'Total de predios no liberados: $sinCop\n'
                            'Km efectivos liberados: ${formatoKm.format(kmEfectivosLiberados)} km/$totalKmTexto',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansRegular,
                                lineSpacing: 3.0,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 25),
                      pw.Center(child: pw.Text('ATENTAMENTE', style: pw.TextStyle(font: notoSansBold, fontSize: _fontSize))),
                      pw.SizedBox(height: 12),
                      pw.Text(firmaIniciales, style: pw.TextStyle(font: notoSansRegular, fontSize: 4.5)),
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
    if (pdfBytes == null || !mounted) return;
    setState(() {
      _previewPdfBytes = pdfBytes;
      _previewTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) _webPreviewImagesFuture = _rasterizeWebPreview(pdfBytes);
    });

    try {
      // Generar nombre automático: REPORTE_NUMERO_PROYECTO_FECHA
      // Ejemplo: REPORTE_1_TSNL_180626
      final ahora = DateTime.now();
      final fechaArchivo = DateFormat('yyMMdd').format(ahora);
      final nombreArchivo = 'REPORTE_${_numeroParaArchivo}_${_proyectoActual}_$fechaArchivo.pdf';

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
    ref.watch(proyectosCodigosProvider);
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

  // Estilos y espaciados compartidos del formulario, derivados del tema global
  // (Inter, bordes redondeados y padding de inputDecorationTheme).
  static const _espacioCampo = 16.0;
  static const _espacioEtiqueta = 6.0;

  TextStyle? get _estiloTituloSeccion =>
      Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
  TextStyle? get _estiloEtiqueta => Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  TextStyle? get _estiloValor => Theme.of(context).textTheme.bodyLarge;

  /// Tarjeta con título y campos separados uniformemente.
  Widget _seccion(String titulo, List<Widget> campos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: _estiloTituloSeccion),
            for (final campo in campos) ...[
              const SizedBox(height: _espacioCampo),
              campo,
            ],
          ],
        ),
      ),
    );
  }

  /// Etiqueta arriba del control, siempre con el mismo estilo y separación.
  Widget _campo(String etiqueta, Widget control) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(etiqueta, style: _estiloEtiqueta),
        const SizedBox(height: _espacioEtiqueta),
        control,
      ],
    );
  }

  /// Dos campos lado a lado; en pantallas angostas se apilan.
  Widget _filaCampos(Widget izquierda, Widget derecha) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [izquierda, const SizedBox(height: _espacioCampo), derecha],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: izquierda),
            const SizedBox(width: _espacioCampo),
            Expanded(child: derecha),
          ],
        );
      },
    );
  }

  /// Par etiqueta/valor de solo lectura para el resumen de la previsualización.
  Widget _dato(String etiqueta, String valor, [String? detalle]) {
    final texto = valor.trim().isNotEmpty ? valor.trim() : '(Sin capturar)';
    return _campo(
      etiqueta,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: _estiloValor),
          if (detalle != null)
            Text(
              detalle.trim().isNotEmpty ? detalle.trim() : '(Sin cargo)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _selectorProyecto(List<String> proyectosDisponibles) {
    return DropdownButtonFormField<String>(
      value: proyectosDisponibles.contains(_proyectoActual)
          ? _proyectoActual
          : proyectosDisponibles.first,
      items: proyectosDisponibles
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _proyectoActual = v;
          _segmentoSeleccionado = null;
          _sincronizarNumeroReportePorProyecto();
        });
        _actualizarAsuntoPorProyecto(v);
      },
    );
  }

  /// Vista del formulario
  Widget _buildFormView(List<String> proyectosDisponibles) {
    final prediosAsync = ref.watch(prediosMapaProvider);
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
          _seccion(
            'Proyecto',
            [_selectorProyecto(proyectosDisponibles)],
          ),
          const SizedBox(height: 16),

          // Formulario del reporte
          _seccion('Datos del reporte', [
            _filaCampos(
              _campo(
                'Dirección o subdirección remitente',
                TextField(controller: _remitenteCtrl),
              ),
              _campo(
                'Reporte no.',
                TextField(controller: _reporteNoCtrl),
              ),
            ),
            _filaCampos(
              _campo(
                'Para: nombre',
                TextField(controller: _paraNombreCtrl),
              ),
              _campo(
                'Para: cargo',
                TextField(controller: _paraCargoCtrl),
              ),
            ),
            _filaCampos(
              _campo(
                'De: nombre',
                TextField(controller: _deNombreCtrl),
              ),
              _campo(
                'De: cargo',
                TextField(controller: _deCargoCtrl),
              ),
            ),
            _campo(
              'Asunto',
              TextField(
                controller: _asuntoCtrl,
                decoration: const InputDecoration(
                  hintText: 'Informe del balance actual del proyecto (nombre)',
                ),
              ),
            ),
            _campo(
              'Contenido adicional',
              TextField(
                controller: _contenidoCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Escribe el contenido del reporte...',
                ),
              ),
            ),
            _filaCampos(
              _campo(
                'Elaboró: iniciales',
                TextField(
                  controller: _elaboroCtrl,
                  decoration: const InputDecoration(hintText: 'Ejemplo: ABCD'),
                ),
              ),
              _campo(
                'Revisó: iniciales',
                TextField(
                  controller: _revisoCtrl,
                  decoration: const InputDecoration(hintText: 'Ejemplo: EFGH'),
                ),
              ),
            ),
            _campo(
              'Colocar datos numéricos de',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final opcion in const [
                    ('Ninguno', 'Ninguno'),
                    ('Proyecto', 'Proyecto'),
                    ('Segmento', 'T/F/S'),
                  ])
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: opcion.$1,
                      groupValue: _datosNumericosDe,
                      title: Text(opcion.$2, style: _estiloValor),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _datosNumericosDe = v);
                      },
                    ),
                ],
              ),
            ),
            if (_datosNumericosDe == 'Segmento')
              _campo(
                'T/F/S',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedSegmento,
                      hint: const Text('Selecciona T/F/S'),
                      items: segmentosDisponibles
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _segmentoSeleccionado = v),
                    ),
                    if (segmentosDisponibles.isEmpty) ...[
                      const SizedBox(height: _espacioEtiqueta),
                      Text(
                        'No hay segmentos disponibles para el proyecto seleccionado.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
          ]),
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
    final panels = <Widget>[
        // Panel izquierdo - formulario (reducido)
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de proyecto
                _seccion('Proyecto', [_selectorProyecto(proyectosDisponibles)]),
                const SizedBox(height: 16),

                // Resumen del reporte
                _seccion('Datos del reporte', [
                  _dato('Dirección o subdirección remitente', _remitenteCtrl.text),
                  _dato('Reporte no.', _reporteNoCtrl.text),
                  _dato('Para', _paraNombreCtrl.text, _paraCargoCtrl.text),
                  _dato('De', _deNombreCtrl.text, _deCargoCtrl.text),
                  _dato('Datos numéricos de', _origenNumericoLabel()),
                ]),
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.preview, size: 20),
                      const Text(
                        'Previsualización del Reporte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'REPORTE_${_numeroParaArchivo}_${_proyectoActual}_${DateFormat('yyMMdd').format(DateTime.now())}.pdf',
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
      ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 900) return Row(children: panels);
      return DefaultTabController(length: 2, child: Column(children: [
        const TabBar(tabs: [Tab(icon: Icon(Icons.edit_outlined), text: 'Datos'), Tab(icon: Icon(Icons.preview), text: 'Vista previa')]),
        Expanded(child: TabBarView(children: [
          SizedBox.expand(child: (panels.first as SizedBox).child),
          (panels.last as Expanded).child,
        ])),
      ]));
    });
  }
}
