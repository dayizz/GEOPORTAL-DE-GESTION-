// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

const disponible = true;

void Function() escucharPortapapelesNavegador({
  required String? Function(bool cortar) alCopiar,
  required bool Function(String texto) alPegar,
}) {
  void copiar(html.ClipboardEvent evento, {required bool cortar}) {
    final texto = alCopiar(cortar);
    if (texto == null) return;
    evento.clipboardData?.setData('text/plain', texto);
    evento.preventDefault();
  }

  final subs = [
    html.document.onCopy.listen((e) => copiar(e, cortar: false)),
    html.document.onCut.listen((e) => copiar(e, cortar: true)),
    html.document.onPaste.listen((e) {
      final texto = e.clipboardData?.getData('text/plain');
      if (texto != null && texto.isNotEmpty && alPegar(texto)) e.preventDefault();
    }),
  ];
  return () {
    for (final s in subs) {
      s.cancel();
    }
  };
}
