import 'dart:convert';

import 'propietario.dart';

class Predio {
  final String id;
  final String claveCatastral; // ID SEDATU o identificador del predio
  final String? propietarioNombre; // Nombre directo del propietario
  final String tramo; // T1, T2, T3, T4
  final String tipoPropiedad; // SOCIAL, DOMINIO PLENO, PRIVADA
  final String? ejido;
  final String? estado;
  final String? municipio;
  final double? kmInicio;
  final double? kmFin;
  final double? kmLineales;
  final double? kmEfectivos;
  final double? superficie; // M2
  final bool cop; // Convenio de Ocupación Previa
  final String? copFirmado; // Archivo PDF del COP firmado
  final String? pdfUrl; // URL publica del PDF COP/DOT en storage
  final DateTime? copFecha; // Fecha asociada al documento COP/DOT
  final String? poligonoDwg; // Archivo DWG del polígono
  final String? oficio; // Oficio entregado
  final String? proyecto;
  final bool poligonoInsertado;
  final bool identificacion;
  final bool levantamiento;
  final bool negociacion;
  final String? situacionSocial;
  final String? tipoLiberacion;
  final double? latitud;
  final double? longitud;
  final Map<String, dynamic>? geometry;
  final String? propietarioId;
  final Propietario? propietario;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Aliases para compatibilidad con pantallas existentes
  String get usoSuelo => tipoPropiedad;
  String get zona => tramo;
  String get direccion => ejido ?? '-';

  const Predio({
    required this.id,
    required this.claveCatastral,
    this.propietarioNombre,
    required this.tramo,
    required this.tipoPropiedad,
    this.ejido,
    this.estado,
    this.municipio,
    this.kmInicio,
    this.kmFin,
    this.kmLineales,
    this.kmEfectivos,
    this.superficie,
    this.cop = false,
    this.copFirmado,
    this.pdfUrl,
    this.copFecha,
    this.poligonoDwg,
    this.oficio,
    this.proyecto,
    this.poligonoInsertado = false,
    this.identificacion = false,
    this.levantamiento = false,
    this.negociacion = false,
    this.situacionSocial,
    this.tipoLiberacion,
    this.latitud,
    this.longitud,
    this.geometry,
    this.propietarioId,
    this.propietario,
    required this.createdAt,
    this.updatedAt,
  });

  factory Predio.fromMap(Map<String, dynamic> map) {
    String? pickText(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return null;
    }

    double? pickDouble(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.replaceAll(',', '').trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    String normalizeTipoPropiedad(String? value) {
      final upper = (value ?? '').toUpperCase().trim();
      final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (compact.contains('SOC')) return 'SOCIAL';
      if (compact.contains('DOMINIOPLENO') || (compact.contains('DOMINIO') && compact.contains('PLENO'))) return 'DOMINIO PLENO';
      if (compact.contains('EJI')) return 'EJIDAL';
      if (compact.contains('MIX')) return 'MIXTO';
      if (compact.contains('FEDERAL')) return 'FEDERAL';
      if (compact.contains('GUBERNAMENTAL') || compact.contains('GUBERNAM') || compact.contains('GOBIERNO')) return 'GUBERNAMENTAL';
      if (compact.contains('PRIVAD') || compact == 'PRI') return 'PRIVADA';
      return upper.isEmpty ? 'PRIVADA' : upper;
    }

    Map<String, String?> inferEstadoMunicipioDesdeClave(String? clave) {
      if (clave == null || clave.trim().isEmpty) {
        return {'estado': null, 'municipio': null};
      }

      final upper = clave.trim().toUpperCase();
      final tokens = upper
          .split(RegExp(r'[^A-Z0-9]+'))
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      final code = tokens.length >= 2 ? tokens[1] : '';

      const municipiosTsnl = {
        'SLV': 'Salinas Victoria',
        'VIL': 'Villaldama',
        'BUS': 'Bustamante',
        'LAM': 'Lampazos de Naranjo',
        'ANA': 'Anahuac',
        'SAB': 'Sabinas Hidalgo',
      };

      return {
        'estado': upper.startsWith('SNL') || upper.startsWith('TSNL')
            ? 'Nuevo Leon'
            : null,
        'municipio': municipiosTsnl[code],
      };
    }

    // Normalizar geometría: puede venir como string JSON o como Map
    Map<String, dynamic>? geometry;
    final geometryRaw = map['geometry'];
    if (geometryRaw != null) {
      if (geometryRaw is String) {
        try {
          geometry = jsonDecode(geometryRaw) as Map<String, dynamic>;
        } catch (_) {
          geometry = null;
        }
      } else if (geometryRaw is Map) {
        geometry = Map<String, dynamic>.from(geometryRaw);
      }
    }
    
    final ubicacionInferida = inferEstadoMunicipioDesdeClave(
      pickText([
        'clave_catastral',
        'CLAVE_CATASTRAL',
        'clave',
        'CLAVE',
        'id_sedatu',
        'ID_SEDATU',
      ]) ?? map['clave_catastral']?.toString() ?? map['CLAVE']?.toString(),
    );

    return Predio(
      id: map['id'] as String,
      claveCatastral: map['clave_catastral'] as String? ?? map['id_sedatu'] as String? ?? '',
      propietarioNombre: map['propietario_nombre'] as String?,
      tramo: (map['tramo'] as String?) ?? '',
      tipoPropiedad: normalizeTipoPropiedad(
        pickText([
          'tipo_propiedad',
          'TIPO_PROPIEDAD',
          'tipopropiedad',
          'tipo propiedad',
          'tipo_de_propiedad',
          'tipo',
          'regimen',
          'tenencia',
        ]) ?? map['tipo_propiedad']?.toString(),
      ),
      ejido: map['ejido'] as String?,
      estado: pickText([
        'estado', 'ESTADO',
        'entidad', 'ENTIDAD',
        'entidad_federativa', 'ENTIDAD_FEDERATIVA',
        'edo', 'EDO',
        'state', 'STATE',
        'nom_estado', 'NOM_ESTADO',
        'nombre_estado', 'NOMBRE_ESTADO',
      ]) ?? map['estado'] as String? ?? ubicacionInferida['estado'],
      municipio: pickText([
        'municipio', 'MUNICIPIO',
        'mun', 'MUN',
        'mpio', 'MPIO',
        'muni', 'MUNI',
        'municipality', 'MUNICIPALITY',
        'nom_municipio', 'NOM_MUNICIPIO',
        'nombre_municipio', 'NOMBRE_MUNICIPIO',
      ]) ?? map['municipio'] as String? ?? ubicacionInferida['municipio'],
      kmInicio: pickDouble(['km_inicio', 'KM_INICIO', 'km inicio', 'KM INICIO', 'km_ini', 'KM_INI']) ?? (map['km_inicio'] as num?)?.toDouble(),
      kmFin: pickDouble(['km_fin', 'KM_FIN', 'km fin', 'KM FIN', 'cadenamiento_final', 'CADENAMIENTO_FINAL']) ?? (map['km_fin'] as num?)?.toDouble(),
      kmLineales: pickDouble(['km_lineales', 'KM_LINEALES', 'km lineales', 'KM LINEALES', 'longitud_km', 'LONGITUD_KM']) ?? (map['km_lineales'] as num?)?.toDouble(),
      kmEfectivos: pickDouble(['km_efectivos', 'KM_EFECTIVOS', 'km efectivos', 'KM EFECTIVOS', 'longitud_efectiva', 'LONGITUD_EFECTIVA']) ?? (map['km_efectivos'] as num?)?.toDouble(),
      superficie: (map['superficie'] as num?)?.toDouble(),
      cop: map['cop'] as bool? ?? false,
      copFirmado: map['cop_firmado'] as String?,
      pdfUrl: map['pdf_url'] as String? ?? map['cop_firmado'] as String?,
        copFecha: map['cop_fecha'] != null
          ? DateTime.tryParse(map['cop_fecha'] as String)
          : null,
      poligonoDwg: map['poligono_dwg'] as String?,
      oficio: map['oficio'] as String?,
      proyecto: map['proyecto'] as String?,
      poligonoInsertado: map['poligono_insertado'] as bool? ?? false,
      identificacion: map['identificacion'] as bool? ?? false,
      levantamiento: map['levantamiento'] as bool? ?? false,
      negociacion: map['negociacion'] as bool? ?? false,
      situacionSocial: map['situacion_social'] as String?,
      tipoLiberacion: map['tipo_liberacion'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      geometry: geometry,
      propietarioId: map['propietario_id'] as String?,
      propietario: map['propietarios'] != null
          ? Propietario.fromMap(map['propietarios'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clave_catastral': claveCatastral,
      'propietario_nombre': propietarioNombre,
      'tramo': tramo,
      'tipo_propiedad': tipoPropiedad,
      'ejido': ejido,
      'estado': estado,
      'municipio': municipio,
      'km_inicio': kmInicio,
      'km_fin': kmFin,
      'km_lineales': kmLineales,
      'km_efectivos': kmEfectivos,
      'superficie': superficie,
      'cop': cop,
      'cop_firmado': copFirmado,
      'pdf_url': pdfUrl,
      'cop_fecha': copFecha?.toIso8601String(),
      'poligono_dwg': poligonoDwg,
      'oficio': oficio,
      'poligono_insertado': poligonoInsertado,
      'identificacion': identificacion,
      'levantamiento': levantamiento,
      'negociacion': negociacion,
      'situacion_social': situacionSocial,
      'tipo_liberacion': tipoLiberacion,
      'latitud': latitud,
      'longitud': longitud,
      'geometry': geometry,
      'propietario_id': propietarioId,
    };
  }

  double get porcentajeAvance {
    int c = 0;
    if (identificacion) c++;
    if (levantamiento) c++;
    if (negociacion) c++;
    if (cop) c++;
    if (poligonoInsertado) c++;
    return c / 5.0;
  }

  String get nombrePropietario {
    if (propietario != null) return propietario!.nombreCompleto;
    return propietarioNombre ?? claveCatastral;
  }

  Predio copyWith({
    String? id,
    String? claveCatastral,
    String? propietarioNombre,
    String? tramo,
    String? tipoPropiedad,
    String? ejido,
    String? estado,
    String? municipio,
    double? kmInicio,
    double? kmFin,
    double? kmLineales,
    double? kmEfectivos,
    double? superficie,
    bool? cop,
    String? copFirmado,
    String? pdfUrl,
    DateTime? copFecha,
    String? poligonoDwg,
    String? oficio,
    String? proyecto,
    bool? poligonoInsertado,
    bool? identificacion,
    bool? levantamiento,
    bool? negociacion,
    String? situacionSocial,
    String? tipoLiberacion,
    double? latitud,
    double? longitud,
    Map<String, dynamic>? geometry,
    String? propietarioId,
    Propietario? propietario,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Predio(
      id: id ?? this.id,
      claveCatastral: claveCatastral ?? this.claveCatastral,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      tramo: tramo ?? this.tramo,
      tipoPropiedad: tipoPropiedad ?? this.tipoPropiedad,
      ejido: ejido ?? this.ejido,
      estado: estado ?? this.estado,
      municipio: municipio ?? this.municipio,
      kmInicio: kmInicio ?? this.kmInicio,
      kmFin: kmFin ?? this.kmFin,
      kmLineales: kmLineales ?? this.kmLineales,
      kmEfectivos: kmEfectivos ?? this.kmEfectivos,
      superficie: superficie ?? this.superficie,
      cop: cop ?? this.cop,
      copFirmado: copFirmado ?? this.copFirmado,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      copFecha: copFecha ?? this.copFecha,
      poligonoDwg: poligonoDwg ?? this.poligonoDwg,
      oficio: oficio ?? this.oficio,
      proyecto: proyecto ?? this.proyecto,
      poligonoInsertado: poligonoInsertado ?? this.poligonoInsertado,
      identificacion: identificacion ?? this.identificacion,
      levantamiento: levantamiento ?? this.levantamiento,
      negociacion: negociacion ?? this.negociacion,
      situacionSocial: situacionSocial ?? this.situacionSocial,
      tipoLiberacion: tipoLiberacion ?? this.tipoLiberacion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      geometry: geometry ?? this.geometry,
      propietarioId: propietarioId ?? this.propietarioId,
      propietario: propietario ?? this.propietario,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
