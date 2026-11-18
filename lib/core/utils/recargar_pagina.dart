import 'recargar_pagina_stub.dart'
    if (dart.library.html) 'recargar_pagina_web.dart' as impl;

/// Recarga la página en web (no hace nada en otras plataformas).
void recargarPagina() => impl.recargarPagina();
