import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/predios_provider.dart';
import '../providers/demo_predios_notifier.dart';
import '../providers/local_predios_provider.dart';
import '../data/predios_repository.dart';
import '../../auth/providers/demo_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PredioFormScreen extends ConsumerStatefulWidget {
  final String? id; // null = nuevo predio
  const PredioFormScreen({super.key, this.id});

  @override
  ConsumerState<PredioFormScreen> createState() => _PredioFormScreenState();
}

class _PredioFormScreenState extends ConsumerState<PredioFormScreen> {
  static const List<String> _tipoLiberacionOpciones = ['COP', 'DOT', 'AOP'];

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
  final _poligonoDwgCtrl = TextEditingController();
  final _situacionSocialCtrl = TextEditingController();
  final _propietarioNombreCtrl = TextEditingController();

  String _tramo = 'T1';
  String _tramoTipo = 'TRAMO';
  String _tramoNumero = '1';
  String _tipoPropiedad = 'PRIVADA';
  bool _cop = false;
  bool _poligonoInsertado = false;
  bool _identificacion = false;
  bool _levantamiento = false;
  bool _negociacion = false;
  String _estatusPredio = 'No liberado';
  String? _propietarioId;
  String? _pdfUrl;
  DateTime? _copFecha;

  String _buildTramoValue() {
    const prefijos = {
      'TRAMO': 'T',
      'FRENTE': 'F',
      'SEGMENTO': 'S',
    };
    final prefijo = prefijos[_tramoTipo] ?? 'T';
    return '$prefijo$_tramoNumero';
  }

  void _setTramoFromValue(String valor) {
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
      _tramo = _buildTramoValue();
      return;
    }

    _tramoTipo = 'TRAMO';
    final numero = RegExp(r'(\d+)').firstMatch(limpio)?.group(1);
    _tramoNumero = numero ?? '1';
    _tramo = _buildTramoValue();
  }

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadPredio();
    } else {
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
        _poligonoDwgCtrl.text = predio.poligonoDwg ?? '';
        _situacionSocialCtrl.text = predio.situacionSocial ?? '';
        _propietarioNombreCtrl.text = predio.propietarioNombre ?? '';
        _setTramoFromValue(predio.tramo);
        _tipoPropiedad = predio.tipoPropiedad;
        _cop = predio.cop;
        _poligonoInsertado = predio.poligonoInsertado;
        _identificacion = predio.identificacion;
        _levantamiento = predio.levantamiento;
        _negociacion = predio.negociacion;
        _estatusPredio = predio.cop ? 'Liberado' : 'No liberado';
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
      _kmEfectivosCtrl, _superficieCtrl, _poligonoDwgCtrl,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final isDemo = ref.read(demoModeProvider);
      final isEdit = widget.id != null;
      final isLocalPredio = isEdit && widget.id!.startsWith('local-');
      final estatusLiberado = _estatusPredio == 'Liberado';
      final estatusNoLiberado = _estatusPredio == 'No liberado';

      if (isDemo && isEdit) {
        // En modo demo: actualizar estado local
        final predioActual = ref
            .read(demoPrediosNotifierProvider)
            .firstWhere((p) => p.id == widget.id);
        final actualizado = predioActual.copyWith(
          claveCatastral: _claveCtrl.text.trim(),
          tramo: _tramo,
          tipoPropiedad: _tipoPropiedad,
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
          copFecha: _copFecha,
          poligonoDwg: _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            tipoLiberacion:
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
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
          copFecha: _copFecha,
          poligonoDwg: _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            tipoLiberacion:
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          propietarioId: _propietarioId,
          updatedAt: DateTime.now(),
        );
        ref.read(localPrediosProvider.notifier).updatePredio(actualizado);
      } else {
        final data = {
          'clave_catastral': _claveCtrl.text.trim(),
          'tramo': _tramo,
          'tipo_propiedad': _tipoPropiedad,
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
          'poligono_dwg': _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          'situacion_social': _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
            'tipo_liberacion':
              _tipoLiberacionCtrl.text.isEmpty ? null : _tipoLiberacionCtrl.text.trim(),
          'poligono_insertado': _poligonoInsertado,
          'identificacion': _identificacion,
          'levantamiento': _levantamiento,
          'negociacion': estatusNoLiberado,
          'propietario_nombre': _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          'propietario_id': _propietarioId,
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
                decoration: const InputDecoration(labelText: 'Clave Catastral (ID SEDATU)', prefixIcon: Icon(Icons.tag)),
                validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                textCapitalization: TextCapitalization.characters,
              ),
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
              TextFormField(
                controller: _ejidoCtrl,
                decoration: const InputDecoration(labelText: 'Ejido', prefixIcon: Icon(Icons.agriculture_outlined)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _estadoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _municipioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Municipio',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('Cadenamiento (km)', Icons.linear_scale),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmInicioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Inicio'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _kmFinCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Fin'))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmEfectivosCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Efectivos'))),
              ]),
              const SizedBox(height: 14),
              TextFormField(
                controller: _superficieCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Superficie DDV (m2)', prefixIcon: Icon(Icons.square_foot)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Propietario', Icons.person_outline),
              const SizedBox(height: 12),
              TextFormField(
                controller: _propietarioNombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Propietario', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Documentos', Icons.folder_outlined),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: _resolvedPdfUrl() != null
                              ? AppColors.secondary
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COP/DOT PDF',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _resolvedPdfUrl() != null
                                    ? 'Documento vinculado al expediente.'
                                    : 'No hay PDF cargado para este predio.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'La URL de COP/DOT se gestiona directamente desde la tabla de Gestion.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (_resolvedPdfUrl() != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openPdf(_resolvedPdfUrl()!),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir PDF'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _situacionSocialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Situacion social',
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
                  labelText: 'Fecha',
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
              const SizedBox(height: 24),
              _buildSectionTitle('Estatus del Predio', Icons.flag_outlined),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _estatusPredio,
                decoration: const InputDecoration(
                  labelText: 'Estatus',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Liberado', child: Text('Liberado')),
                  DropdownMenuItem(value: 'No liberado', child: Text('No liberado')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _estatusPredio = v;
                    _cop = v == 'Liberado';
                    _negociacion = v == 'No liberado';
                  });
                },
              ),
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
                  _estatusPredio = _negociacion ? 'No liberado' : _estatusPredio;
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
