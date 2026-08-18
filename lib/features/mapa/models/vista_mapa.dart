import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de mapa base capturado con la vista (mismos valores que
/// `MapaBaseLayer` en `lib/features/mapa/providers/mapa_provider.dart`,
/// duplicado aquí como String para no acoplar esta colección al enum de
/// la pantalla Mapa).
String mapaBaseLayerToString(String? value) {
  const validos = {'estandar', 'satelital', 'satelitalSinEtiquetas', 'sinMapa'};
  return validos.contains(value) ? value! : 'estandar';
}

/// Una vista de mapa guardada (colección Firestore `vistas_mapa`): una
/// posición de cámara (centro + zoom) con nombre, asociada a un proyecto,
/// para reutilizarse como punto de partida de un elemento de tipo mapa en
/// Composiciones (ver `lib/features/composiciones/`). También retiene el
/// tipo de mapa base y si las etiquetas de clave estaban activas al
/// capturar la vista, para que el elemento de mapa insertado en una
/// composición se vea igual que en Mapa al momento de guardarla.
class VistaMapa {
  final String id;
  final String nombre;
  final String proyecto;
  final double lat;
  final double lng;
  final double zoom;
  final String baseLayer;
  final bool mostrarEtiquetasClave;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? createdByEmail;

  const VistaMapa({
    required this.id,
    required this.nombre,
    required this.proyecto,
    required this.lat,
    required this.lng,
    required this.zoom,
    this.baseLayer = 'estandar',
    this.mostrarEtiquetasClave = false,
    required this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByEmail,
  });

  factory VistaMapa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['created_at'];
    final updatedAtRaw = data['updated_at'];
    return VistaMapa(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? 'Sin nombre',
      proyecto: (data['proyecto'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      zoom: (data['zoom'] as num?)?.toDouble() ?? 14,
      baseLayer: mapaBaseLayerToString(data['base_layer'] as String?),
      mostrarEtiquetasClave: (data['mostrar_etiquetas_clave'] as bool?) ?? false,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now(),
      updatedAt: updatedAtRaw is Timestamp ? updatedAtRaw.toDate() : null,
      createdByUid: data['created_by_uid'] as String?,
      createdByEmail: data['created_by_email'] as String?,
    );
  }
}
