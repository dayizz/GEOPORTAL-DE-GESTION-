import 'portapapeles_navegador_stub.dart'
    if (dart.library.html) 'portapapeles_navegador_web.dart' as impl;

/// Escucha los eventos nativos `copy`/`cut`/`paste` del navegador (solo en
/// web). A diferencia de `Clipboard.getData`, el evento `paste` trae el
/// texto sin pedir permiso de lectura del portapapeles.
///
/// [alCopiar] devuelve el texto a copiar, o `null` si no le corresponde
/// (p. ej. se está escribiendo en un campo y el navegador copia solo).
/// [alPegar] devuelve `true` si usó el texto. Devuelve la función que
/// quita los oyentes.
void Function() escucharPortapapelesNavegador({
  required String? Function(bool cortar) alCopiar,
  required bool Function(String texto) alPegar,
}) => impl.escucharPortapapelesNavegador(alCopiar: alCopiar, alPegar: alPegar);

/// `true` si los atajos de copiar/pegar llegan como eventos del navegador.
const portapapelesNavegadorDisponible = impl.disponible;
