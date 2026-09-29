/// Alias de los campos que pueden contener la etiqueta de un punto PKS.
/// El nombre se normaliza, así que mayúsculas, acentos y separadores no
/// afectan la detección (por ejemplo, `PKs`, `P.K.S.` o `Número PK`).
const pksLabelFieldAliases = <String>[
  'pks_label',
  'pks',
  'pks_num',
  'pks_numero',
  'numero_pk',
  'numero_pks',
  'cadenamiento',
  // Los campos DBF de shapefile suelen truncarse a diez caracteres.
  'cadenamien',
  'propiedad',
  'etiqueta',
  'label',
  'nombre',
  'name',
  'descripcion',
  'pk',
  'id',
  'clave',
];

String _normalizePksFieldKey(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  var normalized = value.trim().toLowerCase();
  replacements.forEach((accented, plain) {
    normalized = normalized.replaceAll(accented, plain);
  });
  return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Busca el valor de etiqueta en las propiedades de un feature PKS.
String? extractPksLabel(Map<String, dynamic> properties) {
  final valuesByNormalizedKey = <String, List<dynamic>>{};
  for (final entry in properties.entries) {
    valuesByNormalizedKey
        .putIfAbsent(_normalizePksFieldKey(entry.key), () => <dynamic>[])
        .add(entry.value);
  }

  for (final alias in pksLabelFieldAliases) {
    final values = valuesByNormalizedKey[_normalizePksFieldKey(alias)];
    if (values == null) continue;
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
  }
  return null;
}
