import 'package:flutter/material.dart';

/// Iconos básicos que se pueden insertar en una hoja. La clave es la que se
/// guarda en `ElementoComposicion.iconoNombre`, así que no debe cambiarse
/// una vez publicada (se puede cambiar la etiqueta o el icono). Un icono
/// `null` se dibuja a mano (ver [_iconosDibujados]) porque no existe en
/// las fuentes de iconos disponibles.
const List<(String, String, IconData?)> iconosComposicion = [
  ('ubicacion', 'Ubicación', Icons.place),
  ('bandera', 'Bandera', Icons.flag),
  ('estrella', 'Estrella', Icons.star),
  ('casa', 'Casa', Icons.home),
  ('edificio', 'Edificio', Icons.apartment),
  ('fabrica', 'Fábrica', Icons.factory),
  ('escuela', 'Escuela', Icons.school),
  ('hospital', 'Hospital', Icons.local_hospital),
  ('tren', 'Tren de frente', Icons.train),
  ('tren_lado', 'Tren de lado', null),
  ('auto', 'Automóvil', Icons.directions_car),
  ('camion', 'Camión', Icons.local_shipping),
  ('persona', 'Persona (busto)', Icons.person),
  ('persona_pie', 'Persona', Icons.man),
  ('persona_caminando', 'Persona caminando', Icons.directions_walk),
  ('grupo', 'Grupo', Icons.groups),
  ('arbol', 'Árbol', Icons.park),
  ('terreno', 'Terreno', Icons.terrain),
  ('agua', 'Agua', Icons.water_drop),
  ('electricidad', 'Electricidad', Icons.bolt),
  ('obra', 'Obra', Icons.construction),
  ('advertencia', 'Advertencia', Icons.warning),
  ('informacion', 'Información', Icons.info),
  ('aprobado', 'Aprobado', Icons.check_circle),
  ('cancelado', 'Cancelado', Icons.cancel),
  ('flecha_arriba', 'Flecha', Icons.arrow_upward),
  ('camara', 'Cámara', Icons.photo_camera),
];

final Map<String, CustomPainter Function(Color)> _iconosDibujados = {
  'tren_lado': (color) => _TrenLadoPainter(color),
};

/// Dibuja el icono [nombre] del catálogo en un cuadro de [size] px.
class IconoComposicion extends StatelessWidget {
  const IconoComposicion(this.nombre, {super.key, required this.size, required this.color});

  final String? nombre;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dibujado = _iconosDibujados[nombre];
    if (dibujado != null) {
      return CustomPaint(size: Size.square(size), painter: dibujado(color));
    }
    IconData icono = Icons.help_outline;
    for (final (clave, _, data) in iconosComposicion) {
      if (clave == nombre && data != null) icono = data;
    }
    return Icon(icono, size: size, color: color);
  }
}

/// Tren visto de lado sobre su vía, en la retícula de 24×24 de los iconos
/// de Material para que su tamaño visual coincida con el resto.
class _TrenLadoPainter extends CustomPainter {
  _TrenLadoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    final carroceria = Path()
      ..moveTo(1, 5)
      ..lineTo(17, 5)
      ..quadraticBezierTo(22, 5.5, 23, 12)
      ..lineTo(23, 16)
      ..lineTo(1, 16)
      ..close()
      // Ventanas como huecos (regla par-impar).
      ..addRect(const Rect.fromLTRB(3, 7, 6.5, 10.5))
      ..addRect(const Rect.fromLTRB(8, 7, 11.5, 10.5))
      ..addRect(const Rect.fromLTRB(13, 7, 16.5, 10.5))
      ..moveTo(18, 7)
      ..lineTo(19.5, 7)
      ..quadraticBezierTo(21, 8.5, 21.4, 10.5)
      ..lineTo(18, 10.5)
      ..close()
      ..addRect(const Rect.fromLTRB(1, 12.5, 23, 13.5))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(carroceria, paint);
    for (final x in [4.5, 8.5, 15.5, 19.5]) {
      canvas.drawCircle(Offset(x, 18), 1.7, paint);
    }
    canvas.drawRect(const Rect.fromLTRB(0, 20.5, 24, 21.7), paint);
  }

  @override
  bool shouldRepaint(_TrenLadoPainter old) => old.color != color;
}
