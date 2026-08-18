import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/predios_provider.dart';
import '../providers/demo_predios_notifier.dart';
import '../providers/local_predios_provider.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import '../../auth/providers/demo_provider.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PredioFormScreen extends ConsumerStatefulWidget {
  final String? id; // null = nuevo predio
  /// Proyecto preseleccionado al crear (p.ej. desde el botón "+" de Gestión,
  /// que pasa el proyecto actualmente activo en la pantalla).
  final String? proyectoInicial;
  const PredioFormScreen({super.key, this.id, this.proyectoInicial});

  @override
  ConsumerState<PredioFormScreen> createState() => _PredioFormScreenState();
}

class _PredioFormScreenState extends ConsumerState<PredioFormScreen> {
  static const List<String> _tipoLiberacionOpciones = [
    'COP',
    'DOT',
    'AOP',
    'EXPROPIACION',
    'SIN TIPO',
  ];
  static const List<String> _estructuraOpciones = [
    'Estacion',
    'Edificio auxiliar',
    'Viaducto',
    'DDV Troncal',
    'Carretera',
    'SICA',
  ];

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _loadingData = true;

  final _claveCtrl = TextEditingController();
  final _ejidoCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _tipoLiberacionCtrl = TextEditingController();
  final _kmInicioCtrl = TextEditingController();
  final _kmFinCtrl = TextEditingController();
  final _kmEfectivosCtrl = TextEditingController();
  final _superficieCtrl = TextEditingController();
  final _situacionSocialCtrl = TextEditingController();
  final _propietarioNombreCtrl = TextEditingController();

  String _tramo = 'T1';
  String _tramoTipo = 'TRAMO';
  String _tramoNumero = '1';
  String _tipoPropiedad = 'PRIVADA';
  String? _estructura;
  String? _proyecto;
  bool _cop = false;
  bool _poligonoInsertado = false;
  bool _identificacion = false;
  bool _levantamiento = false;
  bool _negociacion = false;
  String _rangoEstatus = 'No liberado';
  String? _rangoEstatusOriginal;
  DateTime? _rangoEstatusFechaOriginal;
  String? _propietarioId;
  String? _pdfUrl;
  DateTime? _copFecha;
  DateTime? _fechaLimitePago;
  String? _poligonoDwg;
  String? _planoPdf;
  String? _bdt;

  String _buildTramoValue() {
    const prefijos = {
      'TRAMO': 'T',
      'FRENTE': 'F',
      'SEGMENTO': 'S',
    };
    final prefijo = prefijos[_tramoTipo] ?? 'T';
    return '$prefijo$_tramoNumero';
  }

  /// Carga el T/F/S de un predio existente SIN reescribirlo. Antes, esta
  /// función siempre reconstruía `_tramo` como "letra+número" (vía
  /// `_buildTramoValue`), así que abrir y guardar un predio cuyo T/F/S real
  /// no seguía ese patrón (p.ej. "20", un segmento importado tal cual)
  /// terminaba renombrándolo a "T20" aunque el usuario nunca tocara ese
  /// campo. Ahora se conserva el valor real en `_tramo` -solo se usan
  /// `_tramoTipo`/`_tramoNumero` como ayuda visual en el dropdown+número-,
  /// y `_tramo` solo se reconstruye cuando el usuario edita esos controles
  /// explícitamente (ver los `onChanged` en el formulario).
  void _setTramoFromValue(String valor) {
    _tramo = valor;
    final limpio = valor.trim().toUpperCase();
    final match = RegExp(r'^([TFS])\s*(\d+)$').firstMatch(limpio);

    if (match != null) {
      final prefijo = match.group(1)!;
      final numero = match.group(2)!;
      _tramoTipo = switch (prefijo) {
        'F' => 'FRENTE',
        'S' => 'SEGMENTO',
        _ => 'TRAMO',
      };
      _tramoNumero = numero;
      return;
    }

    _tramoTipo = 'TRAMO';
    final numero = RegExp(r'(\d+)').firstMatch(limpio)?.group(1);
    _tramoNumero = numero ?? limpio;
  }

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadPredio();
    } else {
      _proyecto = widget.proyectoInicial;
      _loadingData = false;
    }
  }

  Future<void> _loadPredio() async {
    try {
      final predio = await ref.read(predioDetalleProvider(widget.id!).future);
      if (predio != null && mounted) {
        _claveCtrl.text = predio.claveCatastral;
        _ejidoCtrl.text = predio.ejido ?? '';
        _estadoCtrl.text = predio.estado ?? '';
        _municipioCtrl.text = predio.municipio ?? '';
        _tipoLiberacionCtrl.text = predio.tipoLiberacion ?? '';
        _kmInicioCtrl.text = predio.kmInicio?.toString() ?? '';
        _kmFinCtrl.text = predio.kmFin?.toString() ?? '';
        _kmEfectivosCtrl.text = predio.kmEfectivos?.toString() ?? '';
        _superficieCtrl.text = predio.superficie?.toString() ?? '';
        _pdfUrl = predio.pdfUrl ?? predio.copFirmado;
        _copFecha = predio.copFecha;
        _fechaLimitePago = predio.fechaLimitePago;
        _poligonoDwg = predio.poligonoDwg;
        _planoPdf = predio.planoPdf;
        _bdt = predio.bdt;
        _situacionSocialCtrl.text = predio.situacionSocial ?? '';
        _propietarioNombreCtrl.text = predio.propietarioNombre ?? '';
        _setTramoFromValue(predio.tramo);
        _tipoPropiedad = predio.tipoPropiedad;
        _estructura = _estructuraOpciones.contains(predio.estructura) ? predio.estructura : null;
        _proyecto = predio.proyecto;
        _cop = predio.cop;
        _poligonoInsertado = predio.poligonoInsertado;
        _identificacion = predio.identificacion;
        _levantamiento = predio.levantamiento;
        _negociacion = predio.negociacion;
        _rangoEstatus = predio.rangoEstatus;
        _rangoEstatusOriginal = predio.rangoEstatus;
        _rangoEstatusFechaOriginal = predio.rangoEstatusFecha;
        _propietarioId = predio.propietarioId;
      }
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _claveCtrl, _ejidoCtrl, _estadoCtrl, _municipioCtrl, _tipoLiberacionCtrl, _kmInicioCtrl, _kmFinCtrl,
      _kmEfectivosCtrl, _superficieCtrl,
      _situacionSocialCtrl, _propietarioNombreCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _resolvedPdfUrl() {
    final value = (_pdfUrl ?? '').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception('La URL del PDF es invalida.');
    }
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened) {
      throw Exception('No se pudo abrir el PDF.');
    }
  }

  Future<void> _pickCopFecha() async {
    final now = DateTime.now();
    final initialDate = _copFecha ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'MX'),
      helpText: 'Selecciona fecha',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _copFecha = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickFechaLimitePago() async {
    final now = DateTime.now();
    final initialDate = _fechaLimitePago ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'MX'),
      helpText: 'Selecciona fecha',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _fechaLimitePago = DateTime(picked.year, picked.month, picked.day);
    });
  }

  /// Tarjeta de un archivo-link (COP/DOT PDF, DWG, Plano PDF, BDT) con
  /// acciones de Abrir/Agregar/Sustituir/Eliminar. Mismo patrón que el
  /// diálogo "Editar archivos" de la tabla de Gestión, para que el link se
  /// pueda gestionar también desde "Editar predio".
  Widget _buildArchivoCard(
    String label,
    String? url,
    ValueChanged<String> onGuardar,
    VoidCallback onEliminar,
  ) {
    final hasUrl = url != null && url.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            color: hasUrl ? AppColors.secondary : Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  hasUrl ? 'Vinculado' : 'Sin vincular',
                  style: TextStyle(
                    color: hasUrl ? AppColors.secondary : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasUrl)
            IconButton(
              tooltip: 'Abrir',
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                try {
                  await _openPdf(url);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                  );
                }
              },
            ),
          IconButton(
            tooltip: hasUrl ? 'Sustituir' : 'Agregar',
            icon: Icon(hasUrl ? Icons.edit_outlined : Icons.add_link),
            onPressed: () async {
              final nuevaUrl = await _requestArchivoUrl(
                titulo: hasUrl ? 'Sustituir $label' : 'Agregar $label',
                initialValue: url ?? '',
              );
              if (nuevaUrl == null) return;
              onGuardar(nuevaUrl);
            },
          ),
          if (hasUrl)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () async {
                final confirmado = await _confirmarQuitarArchivo(label);
                if (confirmado) onEliminar();
              },
            ),
        ],
      ),
    );
  }

  String? _normalizedUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    if (!hasScheme) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }

  Future<String?> _requestArchivoUrl({
    required String titulo,
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    String? error;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(titulo),
              content: TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://.../archivo.pdf',
                  helperText: 'Pega o escribe el link del archivo',
                  errorText: error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Pegar',
                    icon: const Icon(Icons.content_paste),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final clip = data?.text?.trim() ?? '';
                      if (clip.isEmpty) return;
                      ctrl.text = clip;
                      setStateDialog(() => error = null);
                    },
                  ),
                ),
                onFieldSubmitted: (_) {
                  final url = _normalizedUrl(ctrl.text);
                  if (url == null) {
                    setStateDialog(() => error = 'Ingresa una URL valida (http o https).');
                    return;
                  }
                  Navigator.of(dialogContext).pop(url);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final url = _normalizedUrl(ctrl.text);
                    if (url == null) {
                      setStateDialog(() => error = 'Ingresa una URL valida (http o https).');
                      return;
                    }
                    Navigator.of(dialogContext).pop(url);
                  },
                  child: const Text('Guardar URL'),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
    return result;
  }

  Future<bool> _confirmarQuitarArchivo(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Quitar el $label vinculado? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Etiqueta con asterisco rojo para los campos obligatorios de Gestión.
  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final isDemo = ref.read(demoModeProvider);
      final isEdit = widget.id != null;
      final isLocalPredio = isEdit && widget.id!.startsWith('local-');
      final estatusDerivado = Predio.estatusSimplificado(_rangoEstatus);
      final estatusLiberado = estatusDerivado == 'Liberado';
      final estatusNoLiberado = estatusDerivado == 'No liberado';
      final rangoEstatusFecha = (!isEdit || _rangoEstatus != _rangoEstatusOriginal)
          ? DateTime.now()
          : _rangoEstatusFechaOriginal;

      if (isDemo && isEdit) {
        // En modo demo: actualizar estado local
        final predioActual = ref
            .read(demoPrediosNotifierProvider)
            .firstWhere((p) => p.id == widget.id);
        final actualizado = predioActual.copyWith(
          claveCatastral: _claveCtrl.text.trim(),
          tramo: _tramo,
          tipoPropiedad: _tipoPropiedad,
          estructura: _estructura,
          proyecto: _proyecto,
          ejido: _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          estado: _estadoCtrl.text.isEmpty ? null : _estadoCtrl.text.trim(),
          municipio: _municipioCtrl.text.isEmpty ? null : _municipioCtrl.text.trim(),
          kmInicio: _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          kmFin: _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          kmEfectivos: _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          superficie: _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          cop: estatusLiberado,
          copFirmado: _resolvedPdfUrl(),
          pdfUrl: _resolvedPdfUrl(),
          clearCopFirmado: _resolvedPdfUrl() == null,
          clearPdfUrl: _resolvedPdfUrl() == null,
          copFecha: _copFecha,
          clearCopFecha: _copFecha == null,
          fechaLimitePago: _fechaLimitePago,
          clearFechaLimitePago: _fechaLimitePago == null,
          poligonoDwg: _poligonoDwg,
          clearPoligonoDwg: _poligonoDwg == null,
          planoPdf: _planoPdf,
          clearPlanoPdf: _planoPdf == null,
          bdt: _bdt,
          clearBdt: _bdt == null,
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            tipoLiberacion:
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          rangoEstatus: _rangoEstatus,
          rangoEstatusFecha: rangoEstatusFecha,
          updatedAt: DateTime.now(),
        );
        ref.read(demoPrediosNotifierProvider.notifier).updatePredio(actualizado);
      } else if (isLocalPredio) {
        final localState = ref.read(localPrediosProvider);
        final predioActual = localState.firstWhere((p) => p.id == widget.id);
        final actualizado = predioActual.copyWith(
          claveCatastral: _claveCtrl.text.trim(),
          tramo: _tramo,
          tipoPropiedad: _tipoPropiedad,
          estructura: _estructura,
          proyecto: _proyecto,
          ejido: _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          estado: _estadoCtrl.text.isEmpty ? null : _estadoCtrl.text.trim(),
          municipio: _municipioCtrl.text.isEmpty ? null : _municipioCtrl.text.trim(),
          kmInicio: _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          kmFin: _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          kmEfectivos: _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          superficie: _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          cop: estatusLiberado,
          copFirmado: _resolvedPdfUrl(),
          pdfUrl: _resolvedPdfUrl(),
          clearCopFirmado: _resolvedPdfUrl() == null,
          clearPdfUrl: _resolvedPdfUrl() == null,
          copFecha: _copFecha,
          clearCopFecha: _copFecha == null,
          fechaLimitePago: _fechaLimitePago,
          clearFechaLimitePago: _fechaLimitePago == null,
          poligonoDwg: _poligonoDwg,
          clearPoligonoDwg: _poligonoDwg == null,
          planoPdf: _planoPdf,
          clearPlanoPdf: _planoPdf == null,
          bdt: _bdt,
          clearBdt: _bdt == null,
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            tipoLiberacion:
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          propietarioId: _propietarioId,
          rangoEstatus: _rangoEstatus,
          rangoEstatusFecha: rangoEstatusFecha,
          updatedAt: DateTime.now(),
        );
        ref.read(localPrediosProvider.notifier).updatePredio(actualizado);
      } else {
        final data = {
          'clave_catastral': _claveCtrl.text.trim(),
          'tramo': _tramo,
          'tipo_propiedad': _tipoPropiedad,
          'estructura': _estructura,
          'proyecto': _proyecto,
          'ejido': _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          'estado': _estadoCtrl.text.isEmpty ? null : _estadoCtrl.text.trim(),
          'municipio': _municipioCtrl.text.isEmpty ? null : _municipioCtrl.text.trim(),
          'km_inicio': _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          'km_fin': _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          'km_efectivos': _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          'superficie': _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          'cop': estatusLiberado,
          'cop_firmado': _resolvedPdfUrl(),
          'pdf_url': _resolvedPdfUrl(),
          'cop_fecha': _copFecha?.toIso8601String(),
          'fecha_limite_pago': _fechaLimitePago?.toIso8601String(),
          'poligono_dwg': _poligonoDwg,
          'plano_pdf': _planoPdf,
          'bdt': _bdt,
          'situacion_social': _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            'tipo_liberacion':
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          'poligono_insertado': _poligonoInsertado,
          'identificacion': _identificacion,
          'levantamiento': _levantamiento,
          'negociacion': estatusNoLiberado,
          'propietario_nombre': _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          'propietario_id': _propietarioId,
          'rango_estatus': _rangoEstatus,
          'rango_estatus_fecha': rangoEstatusFecha?.toIso8601String(),
        };

        final repo = ref.read(prediosRepositoryProvider);
        if (!isEdit) {
          await repo.createPredio(data);
        } else {
          await repo.updatePredio(widget.id!, data);
        }
      }

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      if (widget.id != null) ref.invalidate(predioDetalleProvider(widget.id!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.exitoGuardar),
            backgroundColor: AppColors.secondary,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/predios');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.id == null ? AppStrings.nuevoPredio : AppStrings.editarPredio;

    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(AppStrings.guardar, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Identificacion LDDV', Icons.description_outlined),
              const SizedBox(height: 12),
              TextFormField(
                controller: _claveCtrl,
                decoration: InputDecoration(label: _requiredLabel('Clave Catastral (ID SEDATU)'), prefixIcon: const Icon(Icons.tag)),
                validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final proyectos = ref.watch(proyectosCodigosProvider);
                final value = proyectos.contains(_proyecto) ? _proyecto : null;
                return DropdownButtonFormField<String>(
                  value: value,
                  decoration: InputDecoration(
                    label: _requiredLabel('Proyecto'),
                    prefixIcon: const Icon(Icons.folder_outlined),
                    hintText: 'Selecciona',
                  ),
                  items: proyectos
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                  onChanged: (v) => setState(() => _proyecto = v),
                );
              }),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tramoTipo,
                    decoration: const InputDecoration(labelText: 'T/F/S', prefixIcon: Icon(Icons.route)),
                    items: const ['TRAMO', 'FRENTE', 'SEGMENTO']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _tramoTipo = v ?? _tramoTipo;
                      _tramo = _buildTramoValue();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _tramoNumero,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Numero'),
                    onChanged: (v) => setState(() {
                      final limpio = v.trim();
                      _tramoNumero = limpio.isEmpty ? '1' : limpio;
                      _tramo = _buildTramoValue();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                    value: _tipoPropiedad,
                    decoration: const InputDecoration(labelText: 'Tipo Propiedad'),
                    items: ['SOCIAL','DOMINIO PLENO','PRIVADA','DESCONOCIDO','FEDERAL','GUBERNAMENTAL','ESTATAL','MUNICIPAL'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _tipoPropiedad = v ?? _tipoPropiedad),
                  ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _estructura,
                decoration: InputDecoration(label: _requiredLabel('Estructura'), hintText: 'Selecciona'),
                items: _estructuraOpciones
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _estructura = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ejidoCtrl,
                decoration: InputDecoration(label: _requiredLabel('Ejido'), prefixIcon: const Icon(Icons.agriculture_outlined)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _estadoCtrl,
                    decoration: InputDecoration(
                      label: _requiredLabel('Estado'),
                      prefixIcon: const Icon(Icons.map_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _municipioCtrl,
                    decoration: InputDecoration(
                      label: _requiredLabel('Municipio'),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('Cadenamiento (km)', Icons.linear_scale),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmInicioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(label: _requiredLabel('km Inicio')))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _kmFinCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(label: _requiredLabel('km Fin')))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmEfectivosCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(label: _requiredLabel('km Efectivos')))),
              ]),
              const SizedBox(height: 14),
              TextFormField(
                controller: _superficieCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(label: _requiredLabel('Superficie DDV (m2)'), prefixIcon: const Icon(Icons.square_foot)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Propietario', Icons.person_outline),
              const SizedBox(height: 12),
              TextFormField(
                controller: _propietarioNombreCtrl,
                decoration: InputDecoration(label: _requiredLabel('Nombre del Propietario'), prefixIcon: const Icon(Icons.person)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Documentos', Icons.folder_outlined),
              const SizedBox(height: 12),
              _buildArchivoCard(
                'COP/DOT PDF',
                _resolvedPdfUrl(),
                // La "Fecha de liberación" es independiente del link -ya no
                // se autocompleta al vincular el PDF-: se llena aparte, más
                // abajo, manualmente o desde un archivo importado.
                (url) => setState(() => _pdfUrl = url),
                () => setState(() => _pdfUrl = null),
              ),
              const SizedBox(height: 10),
              _buildArchivoCard(
                'DWG',
                _poligonoDwg,
                (url) => setState(() => _poligonoDwg = url),
                () => setState(() => _poligonoDwg = null),
              ),
              const SizedBox(height: 10),
              _buildArchivoCard(
                'Plano PDF',
                _planoPdf,
                (url) => setState(() => _planoPdf = url),
                () => setState(() => _planoPdf = null),
              ),
              const SizedBox(height: 10),
              _buildArchivoCard(
                'BDT',
                _bdt,
                (url) => setState(() => _bdt = url),
                () => setState(() => _bdt = null),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _situacionSocialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _tipoLiberacionOpciones.contains(_tipoLiberacionCtrl.text.trim().toUpperCase())
                    ? _tipoLiberacionCtrl.text.trim().toUpperCase()
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Tipo de liberacion',
                  prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                ),
                items: _tipoLiberacionOpciones
                    .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _tipoLiberacionCtrl.text = value ?? '';
                }),
              ),
              const SizedBox(height: 14),
              TextFormField(
                readOnly: true,
                onTap: _pickCopFecha,
                decoration: InputDecoration(
                  labelText: 'Fecha de liberación',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  hintText: _copFecha != null
                      ? DateFormat('dd/MM/yyyy').format(_copFecha!)
                      : 'Selecciona una fecha',
                  suffixIcon: _copFecha == null
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar fecha',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _copFecha = null),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                readOnly: true,
                onTap: _pickFechaLimitePago,
                decoration: InputDecoration(
                  labelText: 'Fecha límite de pago',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  hintText: _fechaLimitePago != null
                      ? DateFormat('dd/MM/yyyy').format(_fechaLimitePago!)
                      : 'Selecciona una fecha',
                  suffixIcon: _fechaLimitePago == null
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar fecha',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _fechaLimitePago = null),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Estatus del Predio', Icons.flag_outlined),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _rangoEstatus,
                decoration: const InputDecoration(
                  labelText: 'Rango de estatus',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                items: Predio.rangoEstatusOpciones
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _rangoEstatus = v;
                    _cop = Predio.estatusSimplificado(v) == 'Liberado';
                    _negociacion = Predio.estatusSimplificado(v) == 'No liberado';
                  });
                },
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final estatus = Predio.estatusSimplificado(_rangoEstatus);
                final color = estatus == 'Liberado' ? AppColors.rangoLiberado : AppColors.rangoNoLiberado;
                return Row(
                  children: [
                    const Text('Estatus: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        estatus,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),
              _buildSectionTitle('Avance DDV', Icons.checklist_outlined),
              const SizedBox(height: 8),
              CheckboxListTile(title: const Text('Identificacion'), value: _identificacion, onChanged: (v) => setState(() => _identificacion = v ?? false), dense: true),
              CheckboxListTile(title: const Text('Levantamiento'), value: _levantamiento, onChanged: (v) => setState(() => _levantamiento = v ?? false), dense: true),
              CheckboxListTile(
                title: const Text('Negociacion'),
                value: _negociacion,
                onChanged: (v) => setState(() {
                  _negociacion = v ?? false;
                  _rangoEstatus = _negociacion ? 'Negociacion' : _rangoEstatus;
                }),
                dense: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(widget.id == null ? 'Crear Predio' : 'Actualizar Predio'),
                  onPressed: _loading ? null : _submit,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
