import 'package:uuid/uuid.dart';
import '../models/elemento_composicion.dart';
import '../models/hoja.dart';

/// Renglón del panel de capas: una carpeta o un elemento (dentro de una
/// carpeta si [enCarpeta]).
class EntradaCapa {
  const EntradaCapa.carpeta(CarpetaCapas this.carpeta) : elemento = null, enCarpeta = false;
  const EntradaCapa.elemento(ElementoComposicion this.elemento, {this.enCarpeta = false}) : carpeta = null;
  final CarpetaCapas? carpeta;
  final ElementoComposicion? elemento;
  final bool enCarpeta;
}

/// Carpeta válida de [e] en [hoja] (una carpeta borrada cuenta como suelto).
String? _carpetaDe(Hoja hoja, ElementoComposicion e) =>
    e.carpetaId != null && hoja.carpetas.any((c) => c.id == e.carpetaId) ? e.carpetaId : null;

/// Renglones del panel, del frente al fondo. Cada carpeta aparece donde
/// está su elemento más al frente, con todos sus elementos debajo (si está
/// expandida); las carpetas vacías van arriba.
List<EntradaCapa> entradasCapas(Hoja hoja) {
  final porId = {for (final c in hoja.carpetas) c.id: c};
  final miembros = <String, List<ElementoComposicion>>{};
  for (final e in hoja.elementos.reversed) {
    final id = _carpetaDe(hoja, e);
    if (id != null) (miembros[id] ??= []).add(e);
  }
  final entradas = <EntradaCapa>[
    for (final c in hoja.carpetas)
      if (!miembros.containsKey(c.id)) EntradaCapa.carpeta(c),
  ];
  final emitidas = <String>{};
  for (final e in hoja.elementos.reversed) {
    final id = _carpetaDe(hoja, e);
    if (id == null) {
      entradas.add(EntradaCapa.elemento(e));
    } else if (emitidas.add(id)) {
      final carpeta = porId[id]!;
      entradas.add(EntradaCapa.carpeta(carpeta));
      if (carpeta.expandida) {
        for (final m in miembros[id]!) {
          entradas.add(EntradaCapa.elemento(m, enCarpeta: true));
        }
      }
    }
  }
  return entradas;
}

/// Orden z (fondo primero) que resulta de los renglones [entradas]: las
/// carpetas contraídas aportan sus elementos ocultos en su lugar.
List<ElementoComposicion> _ordenDesdeEntradas(Hoja hoja, List<EntradaCapa> entradas) {
  final frenteAFondo = <ElementoComposicion>[];
  final vistos = <String>{};
  void agregar(ElementoComposicion e) {
    if (vistos.add(e.id)) frenteAFondo.add(e);
  }
  for (final entrada in entradas) {
    final carpeta = entrada.carpeta;
    if (carpeta != null) {
      if (!carpeta.expandida) {
        for (final e in hoja.elementos.reversed) {
          if (_carpetaDe(hoja, e) == carpeta.id) agregar(e);
        }
      }
    } else {
      agregar(entrada.elemento!);
    }
  }
  // Por seguridad, nada se pierde aunque no tuviera renglón.
  for (final e in hoja.elementos.reversed) {
    agregar(e);
  }
  return frenteAFondo.reversed.toList();
}

/// Arrastre en el panel del renglón [viejo] a [nuevo] (índice ya ajustado
/// al hueco del renglón quitado, como `onReorderItem`).
///
/// Un elemento queda en la carpeta del renglón que tiene encima (la
/// carpeta misma o uno de sus elementos); arriba de todo o bajo un
/// elemento suelto, queda fuera de carpetas. Una carpeta se mueve con
/// todos sus elementos y no puede quedar dentro de otra.
Hoja reordenarCapas(Hoja hoja, int viejo, int nuevo) {
  final entradas = entradasCapas(hoja);
  if (viejo < 0 || viejo >= entradas.length) return hoja;
  final movida = entradas[viejo];
  final lista = [...entradas];

  if (movida.elemento != null) {
    lista.removeAt(viejo);
    final destino = nuevo.clamp(0, lista.length);
    final encima = destino > 0 ? lista[destino - 1] : null;
    final carpetaNueva = encima == null
        ? null
        : encima.carpeta?.id ?? (encima.enCarpeta ? _carpetaDe(hoja, encima.elemento!) : null);
    final actualizado = carpetaNueva == null
        ? movida.elemento!.copyWith(clearCarpetaId: true)
        : movida.elemento!.copyWith(carpetaId: carpetaNueva);
    lista.insert(destino, EntradaCapa.elemento(actualizado, enCarpeta: carpetaNueva != null));
    final orden = _ordenDesdeEntradas(hoja, lista);
    return hoja.copyWith(elementos: [for (final e in orden) e.id == actualizado.id ? actualizado : e]);
  }

  // Carpeta: el bloque es su renglón y los de sus elementos visibles.
  var fin = viejo + 1;
  while (fin < lista.length && lista[fin].enCarpeta) {
    fin++;
  }
  final bloque = lista.sublist(viejo, fin);
  lista.removeRange(viejo, fin);
  var destino = nuevo > viejo ? nuevo - (bloque.length - 1) : nuevo;
  destino = destino.clamp(0, lista.length);
  // No soltarla entre los elementos de otra carpeta.
  while (destino < lista.length && lista[destino].enCarpeta) {
    destino++;
  }
  lista.insertAll(destino, bloque);
  return hoja.copyWith(elementos: _ordenDesdeEntradas(hoja, lista));
}

/// "Carpeta n" con n consecutivo al mayor ya usado en la hoja.
Hoja agregarCarpeta(Hoja hoja) {
  final patron = RegExp(r'^Carpeta (\d+)$');
  var mayor = 0;
  for (final c in hoja.carpetas) {
    final n = int.tryParse(patron.firstMatch(c.nombre)?.group(1) ?? '');
    if (n != null && n > mayor) mayor = n;
  }
  return hoja.copyWith(carpetas: [
    ...hoja.carpetas,
    CarpetaCapas(id: const Uuid().v4(), nombre: 'Carpeta ${mayor + 1}'),
  ]);
}

Hoja cambiarCarpeta(Hoja hoja, String id, CarpetaCapas Function(CarpetaCapas) f) =>
    hoja.copyWith(carpetas: [for (final c in hoja.carpetas) c.id == id ? f(c) : c]);

/// Quita la carpeta; sus elementos se conservan, sueltos y en su lugar.
Hoja eliminarCarpeta(Hoja hoja, String id) => hoja.copyWith(
  carpetas: [for (final c in hoja.carpetas) if (c.id != id) c],
  elementos: [
    for (final e in hoja.elementos) e.carpetaId == id ? e.copyWith(clearCarpetaId: true) : e,
  ],
);

/// Elementos de la carpeta [id].
Iterable<ElementoComposicion> elementosDeCarpeta(Hoja hoja, String id) =>
    hoja.elementos.where((e) => e.carpetaId == id);

/// Aplica [f] a todos los elementos de la carpeta [id].
Hoja cambiarElementosDeCarpeta(
  Hoja hoja,
  String id,
  ElementoComposicion Function(ElementoComposicion) f,
) => hoja.copyWith(elementos: [for (final e in hoja.elementos) e.carpetaId == id ? f(e) : e]);
