import 'package:uuid/uuid.dart';
import 'elemento_composicion.dart';

/// Tamaños de hoja soportados. El ancho/alto en mm coincide con los
/// tamaños estándar de `PdfPageFormat` (paquete `pdf`), reutilizados tal
/// cual al exportar a PDF (fase 2) en vez de duplicar dimensiones.
enum TamanoHoja { a1, a2, a3, a4, carta, oficio, personalizado }

TamanoHoja tamanoHojaFromString(String value) {
  return TamanoHoja.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TamanoHoja.a4,
  );
}

extension TamanoHojaDimensiones on TamanoHoja {
  /// Ancho/alto en milímetros, orientación vertical (portrait).
  (double anchoMm, double altoMm) get dimensionesMm {
    switch (this) {
      case TamanoHoja.personalizado:
        return (210, 297);
      case TamanoHoja.a1:
        return (594, 841);
      case TamanoHoja.a2:
        return (420, 594);
      case TamanoHoja.a3:
        return (297, 420);
      case TamanoHoja.a4:
        return (210, 297);
      case TamanoHoja.carta:
        return (215.9, 279.4);
      case TamanoHoja.oficio:
        return (215.9, 355.6);
    }
  }

  String get etiqueta {
    switch (this) {
      case TamanoHoja.personalizado:
        return 'Personalizado';
      case TamanoHoja.a1:
        return 'A1';
      case TamanoHoja.a2:
        return 'A2';
      case TamanoHoja.a3:
        return 'A3';
      case TamanoHoja.a4:
        return 'A4';
      case TamanoHoja.carta:
        return 'Carta';
      case TamanoHoja.oficio:
        return 'Oficio';
    }
  }
}

/// Una hoja/lámina dentro de una [Composicion]. `elementos` está ordenada
/// por z-index (índice 0 = fondo, último = frente).
enum PosicionPagina {
  inferiorIzquierda,
  inferiorDerecha,
  inferiorCentral,
  superiorIzquierda,
  superiorDerecha,
  superiorCentral,
}

extension PosicionPaginaEtiqueta on PosicionPagina {
  String get etiqueta => switch (this) {
    PosicionPagina.inferiorIzquierda => 'Inferior izquierda',
    PosicionPagina.inferiorDerecha => 'Inferior derecha',
    PosicionPagina.inferiorCentral => 'Inferior central',
    PosicionPagina.superiorIzquierda => 'Superior izquierda',
    PosicionPagina.superiorDerecha => 'Superior derecha',
    PosicionPagina.superiorCentral => 'Superior central',
  };
}

PosicionPagina posicionPaginaFromString(String? value) {
  final actualizado = switch (value) {
    'superior' => 'superiorCentral',
    'izquierda' => 'inferiorIzquierda',
    'derecha' => 'inferiorDerecha',
    'inferior' || 'central' => 'inferiorCentral',
    _ => value,
  };
  return PosicionPagina.values.firstWhere(
    (p) => p.name == actualizado,
    orElse: () => PosicionPagina.inferiorCentral,
  );
}

class Hoja {
  final double anchoPersonalizadoMm;
  final double altoPersonalizadoMm;
  final double? margenSuperiorMm;
  final double? margenInferiorMm;
  final double? margenIzquierdoMm;
  final double? margenDerechoMm;
  final bool numerarPagina;
  final int inicioPagina;
  final PosicionPagina posicionPagina;
  final double opacidadFondo;
  final String id;
  final String nombre;
  final TamanoHoja tamano;
  final bool horizontal;
  final double margenMm;
  final String? colorFondoHex; // null = sin fondo
  final List<ElementoComposicion> elementos;

  const Hoja({
    required this.id,
    required this.nombre,
    required this.tamano,
    this.anchoPersonalizadoMm = 210,
    this.altoPersonalizadoMm = 297,
    this.margenSuperiorMm,
    this.margenInferiorMm,
    this.margenIzquierdoMm,
    this.margenDerechoMm,
    this.numerarPagina = false,
    this.inicioPagina = 1,
    this.posicionPagina = PosicionPagina.inferiorCentral,
    this.opacidadFondo = 1,
    this.horizontal = false,
    this.margenMm = 10,
    this.colorFondoHex,
    this.elementos = const [],
  });

  factory Hoja.nueva({
    required String nombre,
    TamanoHoja tamano = TamanoHoja.a4,
  }) {
    return Hoja(
      id: const Uuid().v4(),
      nombre: nombre,
      tamano: tamano,
      horizontal: true,
    );
  }

  /// Ancho/alto en mm respetando `horizontal`.
  (double anchoMm, double altoMm) get dimensionesMm {
    final (ancho, alto) = tamano == TamanoHoja.personalizado
        ? (
            anchoPersonalizadoMm < altoPersonalizadoMm
                ? anchoPersonalizadoMm
                : altoPersonalizadoMm,
            anchoPersonalizadoMm < altoPersonalizadoMm
                ? altoPersonalizadoMm
                : anchoPersonalizadoMm,
          )
        : tamano.dimensionesMm;
    return horizontal ? (alto, ancho) : (ancho, alto);
  }

  double get margenArriba => margenSuperiorMm ?? margenMm;
  double get margenAbajo => margenInferiorMm ?? margenMm;
  double get margenIzquierda => margenIzquierdoMm ?? margenMm;
  double get margenDerecha => margenDerechoMm ?? margenMm;
  int? numeroEnHoja(int indice) => numerarPagina && indice + 1 >= inicioPagina
      ? indice + 2 - inicioPagina
      : null;

  Hoja copyWith({
    double? anchoPersonalizadoMm,
    double? altoPersonalizadoMm,
    double? margenSuperiorMm,
    double? margenInferiorMm,
    double? margenIzquierdoMm,
    double? margenDerechoMm,
    bool? numerarPagina,
    int? inicioPagina,
    PosicionPagina? posicionPagina,
    double? opacidadFondo,
    String? nombre,
    TamanoHoja? tamano,
    bool? horizontal,
    double? margenMm,
    bool clearColorFondo = false,
    String? colorFondoHex,
    List<ElementoComposicion>? elementos,
  }) {
    return Hoja(
      id: id,
      anchoPersonalizadoMm: anchoPersonalizadoMm ?? this.anchoPersonalizadoMm,
      altoPersonalizadoMm: altoPersonalizadoMm ?? this.altoPersonalizadoMm,
      margenSuperiorMm: margenSuperiorMm ?? this.margenSuperiorMm,
      margenInferiorMm: margenInferiorMm ?? this.margenInferiorMm,
      margenIzquierdoMm: margenIzquierdoMm ?? this.margenIzquierdoMm,
      margenDerechoMm: margenDerechoMm ?? this.margenDerechoMm,
      numerarPagina: numerarPagina ?? this.numerarPagina,
      inicioPagina: inicioPagina ?? this.inicioPagina,
      posicionPagina: posicionPagina ?? this.posicionPagina,
      opacidadFondo: opacidadFondo ?? this.opacidadFondo,
      nombre: nombre ?? this.nombre,
      tamano: tamano ?? this.tamano,
      horizontal: horizontal ?? this.horizontal,
      margenMm: margenMm ?? this.margenMm,
      colorFondoHex: clearColorFondo
          ? null
          : (colorFondoHex ?? this.colorFondoHex),
      elementos: elementos ?? this.elementos,
    );
  }

  Map<String, dynamic> toMap() => {
    'ancho_personalizado_mm': anchoPersonalizadoMm,
    'alto_personalizado_mm': altoPersonalizadoMm,
    'margen_superior_mm': margenSuperiorMm,
    'margen_inferior_mm': margenInferiorMm,
    'margen_izquierdo_mm': margenIzquierdoMm,
    'margen_derecho_mm': margenDerechoMm,
    'numerar_pagina': numerarPagina,
    'inicio_pagina': inicioPagina,
    'posicion_pagina': posicionPagina.name,
    'opacidad_fondo': opacidadFondo,
    'id': id,
    'nombre': nombre,
    'tamano': tamano.name,
    'horizontal': horizontal,
    'margen_mm': margenMm,
    'color_fondo': colorFondoHex,
    'elementos': elementos.map((e) => e.toMap()).toList(),
  };

  factory Hoja.fromMap(Map<String, dynamic> map) {
    return Hoja(
      anchoPersonalizadoMm:
          (map['ancho_personalizado_mm'] as num?)?.toDouble() ?? 210,
      altoPersonalizadoMm:
          (map['alto_personalizado_mm'] as num?)?.toDouble() ?? 297,
      margenSuperiorMm: (map['margen_superior_mm'] as num?)?.toDouble(),
      margenInferiorMm: (map['margen_inferior_mm'] as num?)?.toDouble(),
      margenIzquierdoMm: (map['margen_izquierdo_mm'] as num?)?.toDouble(),
      margenDerechoMm: (map['margen_derecho_mm'] as num?)?.toDouble(),
      numerarPagina: (map['numerar_pagina'] as bool?) ?? false,
      inicioPagina: ((map['inicio_pagina'] as num?)?.toInt() ?? 1).clamp(1, 3),
      posicionPagina: posicionPaginaFromString(
        map['posicion_pagina'] as String?,
      ),
      opacidadFondo: (map['opacidad_fondo'] as num?)?.toDouble() ?? 1,
      id: (map['id'] as String?) ?? const Uuid().v4(),
      nombre: (map['nombre'] as String?) ?? 'Hoja',
      tamano: tamanoHojaFromString((map['tamano'] as String?) ?? 'a4'),
      horizontal: (map['horizontal'] as bool?) ?? false,
      margenMm: (map['margen_mm'] as num?)?.toDouble() ?? 10,
      colorFondoHex: map['color_fondo'] as String?,
      elementos: (map['elementos'] as List<dynamic>? ?? const [])
          .map(
            (e) => ElementoComposicion.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}
