import 'dart:math' as math;
import '../models/elemento_composicion.dart';
import '../models/hoja.dart';

/// Conserva la proporción y la rotación al encajar la caja del elemento
/// dentro del margen. Un margen cero desactiva esta restricción.
ElementoComposicion limitarElementoAHoja(ElementoComposicion e, Hoja hoja) {
  final margen = hoja.margenMm;
  if (!margen.isFinite || margen <= 0) return e;
  final (ancho, alto) = hoja.dimensionesMm;
  final disponibleW = ancho - 2 * margen;
  final disponibleH = alto - 2 * margen;
  if (disponibleW <= 0 || disponibleH <= 0) return e;
  final rad = e.rotacion * math.pi / 180;
  final cos = math.cos(rad).abs();
  final sin = math.sin(rad).abs();
  final envolventeW = e.width * cos + e.height * sin;
  final envolventeH = e.width * sin + e.height * cos;
  final factor = math.min(
    1.0,
    math.min(disponibleW / envolventeW, disponibleH / envolventeH),
  );
  final w = e.width * factor;
  final h = e.height * factor;
  final mitadW = math.min(disponibleW / 2, envolventeW * factor / 2);
  final mitadH = math.min(disponibleH / 2, envolventeH * factor / 2);
  final cx = (e.x + e.width / 2).clamp(
    margen + mitadW,
    ancho - margen - mitadW,
  );
  final cy = (e.y + e.height / 2).clamp(
    margen + mitadH,
    alto - margen - mitadH,
  );
  if ((cx - w / 2 - e.x).abs() < 1e-9 &&
      (cy - h / 2 - e.y).abs() < 1e-9 &&
      (w - e.width).abs() < 1e-9 && (h - e.height).abs() < 1e-9) {
    return e;
  }
  return e.copyWith(x: cx - w / 2, y: cy - h / 2, width: w, height: h);
}

Hoja aplicarMargenHoja(Hoja hoja) => hoja.copyWith(
  elementos: hoja.elementos.map((e) => limitarElementoAHoja(e, hoja)).toList(),
);
