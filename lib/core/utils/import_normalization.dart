/// Normalización centralizada de datos provenientes de archivos importados
/// (GeoJSON/XLSX) antes de guardarlos en Gestión (`predios`) y sus
/// complementos (`propietarios`).
///
/// Antes de este archivo existían más de media docena de funciones
/// `_toBool`/`_normalizeTipoPropiedad`/mapas de acentos casi idénticas
/// repetidas por todo `lib/features/carga` y `lib/features/predios`, cada
/// una con pequeñas diferencias (qué palabras cuentan como "verdadero", en
/// qué orden se revisan los tipos de propiedad, etc.) que hacían que el
/// mismo archivo importado dos veces por rutas distintas (GeoJSON vs XLSX)
/// terminara con capitalización, acentos o valores de catálogo distintos.
library;

/// Quita acentos/diéresis de vocales y la ñ. Se usa como parte de la
/// normalización de TODO texto importado (claves, nombres, lugares) para
/// que "Querétaro" y "Queretaro" -o "Nuñez" y "Nunez"- terminen siendo el
/// mismo valor guardado, en vez de dos variantes distintas conviviendo en
/// Gestión según cómo se haya escrito en el archivo de origen.
String stripAccents(String value) {
  const mapa = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    'ñ': 'n', 'Ñ': 'N',
  };
  var out = value;
  mapa.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// Limpieza base para cualquier texto importado: recorta espacios, colapsa
/// espacios/guiones/puntos repetidos, quita guiones/puntos sueltos al
/// inicio o final (residuos comunes de exportaciones de Excel) y quita
/// acentos. No cambia mayúsculas/minúsculas -eso lo deciden
/// [normalizeCode]/[normalizeTitleCase] según el tipo de campo-.
String _limpiarBase(String value) {
  var s = stripAccents(value.trim());
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'-{2,}'), '-');
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');
  s = s.replaceAll(RegExp(r'^[\s\-.]+|[\s\-.]+$'), '');
  return s.trim();
}

/// Normaliza campos tipo "código" (clave catastral, tramo, RFC, CURP,
/// proyecto): limpieza base + MAYÚSCULAS. Devuelve `null` si el resultado
/// queda vacío.
String? normalizeCode(String? value) {
  if (value == null) return null;
  final limpio = _limpiarBase(value);
  if (limpio.isEmpty) return null;
  return limpio.toUpperCase();
}

/// Normaliza campos de texto libre para mostrar (propietario, ejido,
/// estado, municipio, colonia, dirección, situación social): limpieza base
/// + Capitalización De Cada Palabra, para que "MARIA PEREZ", "maria perez"
/// y "Maria   Perez" terminen guardados de la misma forma. Devuelve `null`
/// si el resultado queda vacío.
String? normalizeTitleCase(String? value) {
  if (value == null) return null;
  final limpio = _limpiarBase(value);
  if (limpio.isEmpty) return null;
  return limpio
      .split(' ')
      .map((palabra) {
        if (palabra.isEmpty) return palabra;
        // Conectores comunes en nombres/direcciones en español se dejan en
        // minúsculas salvo que sean la primera palabra (p.ej. "Rio de la Plata").
        const conectores = {'de', 'del', 'la', 'las', 'los', 'y', 'en'};
        final lower = palabra.toLowerCase();
        if (conectores.contains(lower)) return lower;
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ')
      .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
}

/// Convierte texto/num/bool libre a `bool`, aceptando las variantes que
/// realmente aparecen en archivos importados para campos tipo "checklist"
/// (Identificación, Levantamiento, Negociación, COP/liberado):
/// SI/SÍ/S/YES/Y/TRUE/VERDADERO/1/X/COMPLETADO/COMPLETE/LIBERADO/LIBERADA/
/// IDENTIFICADO/LEVANTADO/NEGOCIADO -> true;
/// NO/N/FALSE/FALSO/FAKE/0/'-' o vacío -> false.
/// Cualquier otro texto no reconocido también cae en `false` (nunca lanza).
bool normalizeBoolean(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final texto = stripAccents(value.toString().trim().toUpperCase());
  if (texto.isEmpty) return defaultValue;

  const verdaderos = {
    'SI', 'S', 'YES', 'Y', 'TRUE', 'VERDADERO', '1', 'X',
    'COMPLETADO', 'COMPLETE', 'LIBERADO', 'LIBERADA',
    'IDENTIFICADO', 'LEVANTADO', 'NEGOCIADO',
  };
  const falsos = {'NO', 'N', 'FALSE', 'FALSO', 'FAKE', '0', '-'};

  if (verdaderos.contains(texto)) return true;
  if (falsos.contains(texto)) return false;
  return defaultValue;
}

/// Catálogo vigente de "Tipo de propiedad" (coincide con el dropdown de
/// `predio_form_screen.dart`).
const List<String> tipoPropiedadOpciones = [
  'SOCIAL',
  'DOMINIO PLENO',
  'PRIVADA',
  'DESCONOCIDO',
  'FEDERAL',
  'GUBERNAMENTAL',
  'ESTATAL',
  'MUNICIPAL',
  // Catálogo extendido reconocido al importar, aunque no esté en el
  // dropdown de captura manual (datos históricos reales lo usan).
  'EJIDAL',
  'MIXTO',
];

/// Normaliza "tipo_propiedad" contra el catálogo vigente. Reconoce
/// variantes con/sin acentos, mayúsculas mezcladas, puntos y guiones
/// (p.ej. "dominio-pleno", "Dominio.Pleno", "DOMINIO PLENO" -> la misma
/// clave). Si no coincide con nada conocido, devuelve el texto tal cual en
/// mayúsculas; si viene vacío, devuelve 'PRIVADA' (el default histórico).
String normalizeTipoPropiedad(String? value) {
  final limpio = normalizeCode(value) ?? '';
  final compacto = limpio.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compacto.contains('SOC')) return 'SOCIAL';
  if (compacto.contains('DOMINIOPLENO') ||
      (compacto.contains('DOMINIO') && compacto.contains('PLENO'))) {
    return 'DOMINIO PLENO';
  }
  if (compacto.contains('EJI')) return 'EJIDAL';
  if (compacto.contains('MIX')) return 'MIXTO';
  if (limpio.contains('FEDERAL')) return 'FEDERAL';
  if (limpio.contains('GUBERNAMENTAL') ||
      limpio.contains('GUBERNAM') ||
      limpio.contains('GOBIERNO')) {
    return 'GUBERNAMENTAL';
  }
  if (limpio.contains('ESTATAL')) return 'ESTATAL';
  if (limpio.contains('MUNICIPAL')) return 'MUNICIPAL';
  if (compacto.contains('PRIVAD') || compacto == 'PRI') return 'PRIVADA';
  return limpio.isEmpty ? 'PRIVADA' : limpio;
}

/// Catálogo vigente de "Tipo de liberación" (coincide con el dropdown de
/// `predio_form_screen.dart`).
const List<String> tipoLiberacionOpciones = [
  'COP',
  'DOT',
  'AOP',
  'EXPROPIACION',
  'SIN TIPO',
];

/// Normaliza "tipo_liberacion" contra COP/DOT/AOP/EXPROPIACION, ignorando
/// puntos, espacios y prefijos como "Posible": "D.O.T.", "Posible DOT",
/// "posible-d.o.t", "cop" -> "DOT"/"COP" respectivamente. Valores vacíos,
/// "No", "N/A" o nulos se registran como "SIN TIPO" en vez de perderse o
/// guardarse tal cual (p.ej. la palabra "No" no debe quedar como texto
/// crudo en el catálogo).
String normalizeTipoLiberacion(String? value) {
  if (value == null) return 'SIN TIPO';
  final compacto = stripAccents(value.toUpperCase()).replaceAll(RegExp(r'[^A-Z]'), '');
  if (compacto.isEmpty) return 'SIN TIPO';
  const sinTipoVariantes = {'NO', 'NA', 'NULO', 'NULL', 'NINGUNO', 'NINGUNA', 'SIN'};
  if (sinTipoVariantes.contains(compacto)) return 'SIN TIPO';
  for (final opcion in tipoLiberacionOpciones) {
    final opcionCompacta = opcion.replaceAll(' ', '');
    if (opcionCompacta == 'SINTIPO') continue;
    if (compacto.contains(opcionCompacta)) return opcion;
  }
  if (compacto.contains('SINTIPO')) return 'SIN TIPO';
  return 'SIN TIPO';
}

/// Catálogo vigente de "Estructura" (coincide con el dropdown de
/// `predio_form_screen.dart`).
const List<String> estructuraOpciones = [
  'Estacion',
  'Edificio auxiliar',
  'Viaducto',
  'DDV Troncal',
  'Carretera',
  'SICA',
];

/// Normaliza "estructura" contra el catálogo vigente, sin importar
/// acentos/mayúsculas ("estacion", "ESTACIÓN", "Estación" -> "Estacion").
/// Si no coincide con ninguna opción conocida, se conserva el texto tal
/// cual (con capitalización de título) para no perder datos reales que aún
/// no estén en el catálogo.
String? normalizeEstructura(String? value) {
  if (value == null) return null;
  final limpio = _limpiarBase(value);
  if (limpio.isEmpty) return null;
  final limpioUpper = limpio.toUpperCase();
  for (final opcion in estructuraOpciones) {
    if (stripAccents(opcion).toUpperCase() == limpioUpper) return opcion;
  }
  return normalizeTitleCase(value);
}

/// Variantes de "no aplica" que aparecen en la columna "ejido" cuando el
/// predio no pertenece a ningún ejido (no todos los predios lo hacen).
const Set<String> _noAplicaVariantes = {
  'NA', 'NOAPLICA', 'NOAPLICABLE', 'SINEJIDO', 'NINGUNO', 'NINGUNA',
};

/// Normaliza "ejido" como texto libre (ver [normalizeTitleCase]), salvo que
/// el valor sea una variante de "no aplica" (N/A, NO APLICA, SIN EJIDO,
/// NINGUNO...), en cuyo caso se devuelve el marcador canónico "N/A" en vez
/// de mancharlo con capitalización de título (que dejaría "N/A" como
/// "N/a") o de perderlo.
String? normalizeEjido(String? value) {
  if (value == null) return null;
  final compacto = stripAccents(value.toUpperCase()).replaceAll(RegExp(r'[^A-Z]'), '');
  if (_noAplicaVariantes.contains(compacto)) return 'N/A';
  return normalizeTitleCase(value);
}

/// Convierte un valor de kilometraje/cadenamiento a `double`, aceptando
/// formato PK ("12+359"), decimal ("12.359") o cadenamiento acumulado en
/// metros sin separador ("125352") -las tres representan la misma
/// distancia: 12 km + 359 m = 12.359 km = 12359 m-. Devuelve `null` si no
/// se puede interpretar como número.
double? normalizeKmValue(String? value) {
  if (value == null) return null;
  final texto = value.trim();
  if (texto.isEmpty) return null;
  if (texto.contains('+')) {
    final partes = texto.split('+');
    if (partes.length == 2) {
      final km = double.tryParse(partes[0].trim().replaceAll(',', ''));
      final metros = double.tryParse(partes[1].trim().replaceAll(',', ''));
      if (km == null && metros == null) return null;
      return (km ?? 0) + ((metros ?? 0) / 1000);
    }
  }
  final limpio = texto.replaceAll(',', '');
  final valor = double.tryParse(limpio);
  if (valor == null) return null;
  // Si el texto no trae separador decimal ("." ni "+"), es un cadenamiento
  // acumulado en metros sin separador (p.ej. "125352" -> 125.352 km, igual
  // que si viniera como "125+352"). Un "km inicio"/"km fin" real nunca
  // llega a esa magnitud en km, así que un entero así de grande solo puede
  // significar metros.
  if (!limpio.contains('.') && valor.abs() >= 1000) {
    return valor / 1000;
  }
  return valor;
}

/// Formatea un kilometraje/cadenamiento en formato PK (placa kilométrica)
/// "KM+M", p.ej. `12.359` -> `"12+359"`. Es el formato en el que "km
/// inicio"/"km fin" siempre se inyectan y muestran en Gestión,
/// independientemente de si el archivo de origen lo traía como "12+359" o
/// como "12.359".
String formatKmPk(double km) {
  final enteros = km.truncate();
  final metros = ((km - enteros) * 1000).round().abs();
  return '$enteros+${metros.toString().padLeft(3, '0')}';
}

/// Catálogo vigente de "Rango de estatus" (coincide con
/// `Predio.rangoEstatusOpciones` en `predio.dart`; se duplica aquí -igual
/// que el resto de catálogos de este archivo- para no crear una
/// dependencia de `core` hacia `features/predios`).
const List<String> rangoEstatusOpciones = [
  'Liberado',
  'Negociacion',
  'Posible DOT',
  'Instruccion UVSR',
  'Con ingreso',
  'No liberado',
  'L nueva',
];

/// Normaliza "estatus"/"rango de estatus" contra el catálogo vigente.
/// Reconoce tanto el estatus simple (Liberado/No liberado) como el rango
/// detallado (Negociacion, Posible DOT, Instruccion UVSR, Con ingreso, L
/// nueva). Si no coincide con nada conocido, devuelve 'No liberado' (el
/// default histórico del modelo).
String normalizeRangoEstatus(String? value) {
  if (value == null) return 'No liberado';
  final compacto = stripAccents(value.toUpperCase()).replaceAll(RegExp(r'[^A-Z]'), '');
  if (compacto.isEmpty) return 'No liberado';
  final esNegativo = compacto.startsWith('NO');
  if (compacto.contains('LNUEVA')) return 'L nueva';
  if (compacto.contains('POSIBLE') && compacto.contains('DOT')) return 'Posible DOT';
  if (compacto.contains('UVSR') || compacto.contains('INSTRUCCION')) return 'Instruccion UVSR';
  if (compacto.contains('INGRESO')) return 'Con ingreso';
  if (compacto.contains('NEGOCIACIO')) return 'Negociacion';
  if (compacto.contains('LIBERAD')) return esNegativo ? 'No liberado' : 'Liberado';
  return 'No liberado';
}

/// Normaliza la "Fecha de liberación" (COP/DOT) proveniente de un archivo
/// importado a ISO 8601, aceptando ISO ("2026-03-15"), "dd/mm/aaaa" y
/// "dd-mm-aaaa" -los formatos más comunes en archivos de origen-. Devuelve
/// `null` si el valor está vacío o no se puede interpretar como fecha.
String? normalizeFechaLiberacion(String? value) {
  if (value == null) return null;
  final texto = value.trim();
  if (texto.isEmpty) return null;

  final iso = DateTime.tryParse(texto);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day).toIso8601String();

  final match = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(texto);
  if (match != null) {
    final dia = int.tryParse(match.group(1)!);
    final mes = int.tryParse(match.group(2)!);
    final anio = int.tryParse(match.group(3)!);
    if (dia != null && mes != null && anio != null && mes >= 1 && mes <= 12 && dia >= 1 && dia <= 31) {
      return DateTime(anio, mes, dia).toIso8601String();
    }
  }
  return null;
}
