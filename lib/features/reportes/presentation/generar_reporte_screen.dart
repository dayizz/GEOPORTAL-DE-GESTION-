import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import '../../predios/providers/predios_provider.dart';
import '../../predios/models/predio.dart';

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
  
  // Controladores para el formulario
  final _paraNombreCtrl = TextEditingController();
  final _paraCargoCtrl = TextEditingController();
  final _deNombreCtrl = TextEditingController();
  final _deCargoCtrl = TextEditingController();
  final _asuntoCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  
  // Controladores para elaborar y revisar
  final _elaboroCtrl = TextEditingController();
  final _revisoCtrl = TextEditingController();
  
  int _numeroReporte = 1;
  bool _isGenerating = false;
  bool _showPreview = false;
  Uint8List? _previewPdfBytes;

  @override
  void initState() {
    super.initState();
    // Usar el proyecto inicial si se proporcionó
    if (widget.proyectoInicial != null && _proyectos.contains(widget.proyectoInicial)) {
      _proyectoActual = widget.proyectoInicial!;
    }
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
  /// Helper para generar la cadena ELABORO/REVISO
  String _getElaboroReviso() {
    final elaboro = _elaboroCtrl.text.isNotEmpty ? _elaboroCtrl.text : 'BDVV';
    final reviso = _revisoCtrl.text.isNotEmpty ? _revisoCtrl.text : 'EJJQ';
    return '$elaboro/$reviso';
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

  /// Genera el PDF y guarda en bytes para previsualización
  Future<Uint8List?> _generarPreviewPdf() async {
    if (_isGenerating) return null;
    
    setState(() => _isGenerating = true);

    // Inicializar fuentes
    notoSansRegular = await PdfGoogleFonts.notoSansRegular();
    notoSansBold = await PdfGoogleFonts.notoSansBold();

    try {
      // Cargar imagen membretada
      final membretadaBytes = await rootBundle.load('assets/reportes/hoja_membretada.png');
      final membretadaImage = pw.MemoryImage(membretadaBytes.buffer.asUint8List());

      final prediosAsync = ref.read(prediosListProvider);
      final predios = prediosAsync.asData?.value ?? [];
      final prediosProyecto = predios.where((p) => _predioProyecto(p) == _proyectoActual).toList();
      
      // Calcular estadísticas
      final totalPredios = prediosProyecto.length;
      final social = prediosProyecto.where((p) => p.tipoPropiedad == 'SOCIAL').length;
      final dominioPleno = prediosProyecto.where((p) => p.tipoPropiedad == 'DOMINIO PLENO').length;
      final privada = prediosProyecto.where((p) => p.tipoPropiedad == 'PRIVADA').length;
      final conCop = prediosProyecto.where((p) => p.cop).length;
      final sinCop = prediosProyecto.where((p) => !p.cop).length;
      
      // Calcular superficie total
      double superficieTotal = 0;
      for (final p in prediosProyecto) {
        if (p.superficie != null) {
          superficieTotal += p.superficie!;
        }
      }

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: notoSansRegular,
          bold: notoSansBold,
        ),
      );

      final ahora = DateTime.now();
      final fechaFormateada = DateFormat('dd/MM/yyyy').format(ahora);
      final proyectoNombre = _proyectoActual;

      // Primera página con membrete - márgenes mínimos para imagen de corner a corner
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                // Imagen membretada como fondo - de corner a corner
                pw.Positioned.fill(
                  child: pw.Image(membretadaImage, fit: pw.BoxFit.fill),
                ),
                // Contenido del reporte con márgenes
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 60, right: 60, top: 100, bottom: 60),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Encabezado - alineado a la derecha
                      pw.Align(
                        alignment: pw.Alignment.topRight,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
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
                                  _asuntoCtrl.text.isNotEmpty ? _asuntoCtrl.text : 'Informe del balance actual del proyecto $proyectoNombre',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      
                      // Reporte informativo - centrado y en negritas
                      pw.Center(
                        child: pw.Text(
                          'Reporte informativo ($_numeroReporte)',
                          style: pw.TextStyle(
                            fontSize: _fontSize + 2,
                            font: notoSansBold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      
                      // PARA - en la misma línea: PARA: Nombre (en negritas)
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PARA: ',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansBold,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  _paraNombreCtrl.text.isNotEmpty ? _paraNombreCtrl.text : '(Nombre)',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _paraCargoCtrl.text.isNotEmpty ? _paraCargoCtrl.text : '(Cargo)',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      // DE - en la misma línea: DE: Nombre (en negritas)
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DE: ',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansBold,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  _deNombreCtrl.text.isNotEmpty ? _deNombreCtrl.text : '(Nombre)',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _deCargoCtrl.text.isNotEmpty ? _deCargoCtrl.text : '(Cargo)',
                                  style: pw.TextStyle(fontSize: _fontSize, font: notoSansBold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      
                      // Presente
                      pw.Text(
                        'Presente',
                        style: pw.TextStyle(
                          fontSize: _fontSize,
                          font: notoSansBold,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      
                      // Contenido personalizado
                      if (_contenidoCtrl.text.isNotEmpty) ...[
                        pw.Text(
                          _contenidoCtrl.text,
                          style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                      
                      // Resumen de información del proyecto (sin cuadro)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RESUMEN DEL PROYECTO $proyectoNombre',
                            style: pw.TextStyle(
                              fontSize: _fontSize + 1,
                              font: notoSansBold,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Total de predios: $totalPredios',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Superficie total: ${NumberFormat('#,##0.00').format(superficieTotal)} m²',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Por tipo de propiedad:',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansBold,
                            ),
                          ),
                          pw.Text(
                            '  - SOCIAL: $social',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.Text(
                            '  - DOMINIO PLENO: $dominioPleno',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.Text(
                            '  - PRIVADA: $privada',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Estatus COP:',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansBold,
                            ),
                          ),
                          pw.Text(
                            '  - Liberados: $conCop',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
                          ),
                          pw.Text(
                            '  - No liberados: $sinCop',
                            style: pw.TextStyle(fontSize: _fontSize, font: notoSansRegular),
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

      // Páginas adicionales con tabla de predios si hay contenido
      if (prediosProyecto.isNotEmpty) {
        // Dividir en páginas de 25 registros cada una
        const registrosPorPagina = 25;
        final totalPaginas = (prediosProyecto.length / registrosPorPagina).ceil();
        
        for (var pagina = 0; pagina < totalPaginas; pagina++) {
          final inicio = pagina * registrosPorPagina;
          final fin = (inicio + registrosPorPagina).clamp(0, prediosProyecto.length);
          final prediosPagina = prediosProyecto.sublist(inicio, fin);
          final esUltimaPagina = (pagina == totalPaginas - 1);
          
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.letter,
              margin: pw.EdgeInsets.zero,
              build: (context) {
                return pw.Stack(
                  children: [
                    // Imagen membretada como fondo - de corner a corner
                    pw.Positioned.fill(
                      child: pw.Image(membretadaImage, fit: pw.BoxFit.fill),
                    ),
                    // Contenido de la tabla con márgenes
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 60, right: 60, top: 100, bottom: 60),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Proyecto $proyectoNombre - Predios (continuación)',
                                style: pw.TextStyle(
                                  fontSize: _fontSize + 1,
                                  font: notoSansBold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Table(
                                border: pw.TableBorder.all(color: PdfColors.grey400),
                                columnWidths: {
                                  0: const pw.FlexColumnWidth(2.5),
                                  1: const pw.FlexColumnWidth(2),
                                  2: const pw.FlexColumnWidth(1.5),
                                  3: const pw.FlexColumnWidth(1),
                                  4: const pw.FlexColumnWidth(1.5),
                                  5: const pw.FlexColumnWidth(2),
                                },
                                children: [
                                  // Encabezado de la tabla
                                  pw.TableRow(
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.grey300,
                                    ),
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Clave', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Tipo', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Tramo', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Estatus', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Superficie', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text('Propietario', style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansBold)),
                                      ),
                                    ],
                                  ),
                                  // Filas de datos
                                  ...prediosPagina.map((p) => pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.claveCatastral, style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.tipoPropiedad, style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.tramo, style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.cop ? 'Liberado' : 'No liberado', style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.superficie != null ? NumberFormat('#,##0.00').format(p.superficie) : '-', style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(p.propietarioNombre ?? '-', style: const pw.TextStyle(fontSize: _fontSize - 2)),
                                      ),
                                    ],
                                  )),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'Página ${pagina + 2} de ${totalPaginas + 1}',
                                style: pw.TextStyle(fontSize: _fontSize - 1, font: notoSansRegular),
                              ),
                            ],
                          ),
                          // Footer en la última página
                          if (esUltimaPagina) ...[
                            pw.SizedBox(height: 30),
                            // ATENTAMENTE centrado y en negritas
                            pw.Center(
                              child: pw.Text(
                                'ATENTAMENTE',
                                style: pw.TextStyle(
                                  fontSize: _fontSize,
                                  font: notoSansBold,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            // ELABORO/REVISO al final de la última hoja, lado izquierdo
                            pw.Align(
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(
                                'ELABORO/REVISO: ${_getElaboroReviso()}',
                                style: pw.TextStyle(fontSize: 6, font: notoSansRegular),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }
      } else {
        // Si no hay predios, agregar una página final con ATENTAMENTE y ELABORO/REVISO
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.Stack(
                children: [
                  // Imagen membretada como fondo
                  pw.Positioned.fill(
                    child: pw.Image(membretadaImage, fit: pw.BoxFit.fill),
                  ),
                  // Contenido
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 60, right: 60, top: 100, bottom: 60),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 100),
                        // ATENTAMENTE centrado y en negritas
                        pw.Center(
                          child: pw.Text(
                            'ATENTAMENTE',
                            style: pw.TextStyle(
                              fontSize: _fontSize,
                              font: notoSansBold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 30),
                        // ELABORO/REVISO al final de la última hoja, lado izquierdo
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            'ELABORO/REVISO: ${_getElaboroReviso()}',
                            style: pw.TextStyle(fontSize: 6, font: notoSansRegular),
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
      }

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
    final pdfBytes = await _generarPreviewPdf();
    if (pdfBytes != null && mounted) {
      setState(() {
        _previewPdfBytes = pdfBytes;
        _showPreview = true;
      });
    }
  }

  /// Método para generar y descargar el PDF con nombre automático
  Future<void> _generarPdf() async {
    if (_previewPdfBytes == null) {
      // Si no hay previsualización, generarla primero
      final pdfBytes = await _generarPreviewPdf();
      if (pdfBytes == null) return;
    }

    try {
      // Generar nombre automático: REPORTE_NUMERO_PROYECTO_FECHA
      // Ejemplo: REPORTE_1_TSNL_180626
      final ahora = DateTime.now();
      final fechaArchivo = DateFormat('yyMMdd').format(ahora);
      final nombreArchivo = 'REPORTE_${_numeroReporte}_${_proyectoActual}_$fechaArchivo.pdf';

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
    return AppScaffold(
      currentIndex: 4,
      title: 'Generar Reporte',
      child: _showPreview && _previewPdfBytes != null
          ? _buildPreviewView()
          : _buildFormView(),
    );
  }

  /// Vista del formulario
  Widget _buildFormView() {
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
                    value: _proyectoActual,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _proyectos.map((p) => DropdownMenuItem(
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
                  
// Número de reporte automático: proyecto-numero
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
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Siguiente número',
                        onPressed: () => setState(() => _numeroReporte++),
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
                                hintText: 'Ejemplo: BDVV',
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
                                hintText: 'Ejemplo: JLPC',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
  Widget _buildPreviewView() {
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
                          value: _proyectoActual,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _proyectos.map((p) => DropdownMenuItem(
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
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Siguiente número',
                              onPressed: () => setState(() => _numeroReporte++),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        
                        // ELABORO/REVISO
                        Text(
                          'ELABORO/REVISO: ${_getElaboroReviso()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  child: _previewPdfBytes != null
                      ? PdfPreview(
                          build: (format) async => _previewPdfBytes!,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          allowPrinting: false,
                          allowSharing: false,
                          pdfFileName: 'preview.pdf',
                        )
                      : const Center(
                          child: CircularProgressIndicator(),
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
