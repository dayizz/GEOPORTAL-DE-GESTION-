import 'package:uuid/uuid.dart';
import 'elemento_composicion.dart';

/// Tamaños de hoja soportados. El ancho/alto en mm coincide con los
/// tamaños estándar de `PdfPageFormat` (paquete `pdf`), reutilizados tal
/// cual al exportar a PDF (fase 2) en vez de duplicar dimensiones.
enum TamanoHoja { a1, a2, a3, a4, carta, oficio }

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
class Hoja {
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
    this.horizontal = false,
    this.margenMm = 10,
    this.colorFondoHex,
    this.elementos = const [],
  });

  factory Hoja.nueva({required String nombre, TamanoHoja tamano = TamanoHoja.a4}) {
    return Hoja(id: const Uuid().v4(), nombre: nombre, tamano: tamano);
  }

  /// Ancho/alto en mm respetando `horizontal`.
  (double anchoMm, double altoMm) get dimensionesMm {
    final (ancho, alto) = tamano.dimensionesMm;
    return horizontal ? (alto, ancho) : (ancho, alto);
  }

  Hoja copyWith({
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
      nombre: nombre ?? this.nombre,
      tamano: tamano ?? this.tamano,
      horizontal: horizontal ?? this.horizontal,
      margenMm: margenMm ?? this.margenMm,
      colorFondoHex: clearColorFondo ? null : (colorFondoHex ?? this.colorFondoHex),
      elementos: elementos ?? this.elementos,
    );
  }

  Map<String, dynamic> toMap() => {
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
      id: (map['id'] as String?) ?? const Uuid().v4(),
      nombre: (map['nombre'] as String?) ?? 'Hoja',
      tamano: tamanoHojaFromString((map['tamano'] as String?) ?? 'a4'),
      horizontal: (map['horizontal'] as bool?) ?? false,
      margenMm: (map['margen_mm'] as num?)?.toDouble() ?? 10,
      colorFondoHex: map['color_fondo'] as String?,
      elementos: (map['elementos'] as List<dynamic>? ?? const [])
          .map((e) => ElementoComposicion.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
