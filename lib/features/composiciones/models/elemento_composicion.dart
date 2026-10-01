import 'package:uuid/uuid.dart';

/// Tipos de elemento soportados dentro de una [Hoja]. Fase 1 solo crea
/// [forma] y [texto] desde la UI; el resto ya están contemplados en el
/// esquema para no tener que migrar documentos existentes más adelante.
enum TipoElemento { forma, texto, mapa, norte, escala, simbologia, grafica, imagen }

TipoElemento tipoElementoFromString(String value) {
  return TipoElemento.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoElemento.forma,
  );
}

/// Tipos de figura para elementos [TipoElemento.forma].
enum TipoFigura { rectangulo, cuadrado, triangulo, hexagono, pentagono, linea }

/// `'lineaPunteada'` era, antes, un [TipoFigura] separado -ahora es
/// [TipoFigura.linea] con [EstiloLinea.punteada]- se traduce aquí para no
/// perder la forma de documentos ya guardados.
TipoFigura tipoFiguraFromString(String value) {
  if (value == 'lineaPunteada') return TipoFigura.linea;
  return TipoFigura.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoFigura.rectangulo,
  );
}

/// Estilo de trazo del contorno de una figura ([TipoElemento.forma]).
enum EstiloLinea { continua, segmentada, punteada, lineaPunto }

EstiloLinea estiloLineaFromString(String value) {
  return EstiloLinea.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstiloLinea.continua,
  );
}

/// Punta decorativa en los extremos de una figura [TipoFigura.linea].
enum TipoPuntaLinea { ninguna, flecha, punto }

TipoPuntaLinea tipoPuntaLineaFromString(String value) {
  return TipoPuntaLinea.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoPuntaLinea.ninguna,
  );
}

/// Forma del marco de una ventana de mapa ([TipoElemento.mapa]). Distinta
/// de [TipoFigura] (usada por elementos [TipoElemento.forma]) porque acá
/// solo se necesita un recorte (clip) del contenido del mapa, no
/// trazo/relleno propios.
enum FormaMarco { cuadrada, circular, triangular, hexagonal }

FormaMarco formaMarcoFromString(String value) {
  return FormaMarco.values.firstWhere(
    (f) => f.name == value,
    orElse: () => FormaMarco.cuadrada,
  );
}

/// Alineación horizontal del texto en elementos [TipoElemento.texto].
enum AlineacionTexto { izquierda, centro, derecha, justificado }

AlineacionTexto alineacionTextoFromString(String value) {
  return AlineacionTexto.values.firstWhere(
    (a) => a.name == value,
    orElse: () => AlineacionTexto.izquierda,
  );
}

/// Modos de simbología para elementos [TipoElemento.simbologia].
enum TipoSimbologia { estatus, rangoEstatus, tipoPropiedad }

TipoSimbologia tipoSimbologiaFromString(String value) {
  return TipoSimbologia.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoSimbologia.estatus,
  );
}

/// Tipos de gráfica de "Balance" disponibles para elementos
/// [TipoElemento.grafica] (ver `GraficaWidget`).
enum TipoGrafica {
  kpiPanel,
  avanceDdv,
  rangoEstatus,
  tipoLiberacion,
  tipoPropiedad,
  segmentoTramoFrente,
  cadenamiento,
  avanceMensual,
  avanceSemanal,
}

TipoGrafica tipoGraficaFromString(String value) {
  return TipoGrafica.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoGrafica.kpiPanel,
  );
}

/// Un elemento dentro de una [Hoja] (forma, texto, y en fases futuras:
/// mapa, norte, escala, simbología, gráfica, imagen). Se modela como una
/// sola clase concreta con campos específicos por tipo en vez de una
/// jerarquía sellada, para simplificar la serialización a/desde Firestore
/// (un solo `toMap`/`fromMap`, sin necesidad de un registro de
/// subtipos). El orden dentro de `Hoja.elementos` determina el z-index
/// (índice 0 = fondo).
class ElementoComposicion {
  final String id;
  final TipoElemento tipo;
  final String nombreCapa;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotacion; // grados
  final bool visible;
  final bool bloqueado;

  // --- Forma ---
  final TipoFigura? figuraTipo;
  final String? colorTrazoHex;
  final double? grosorTrazo;
  final String? colorRellenoHex; // null = sin relleno
  final EstiloLinea? estiloLinea; // null = continua
  // Escala del patrón de segmentos/espacios de [estiloLinea] (1 = tamaño
  // por defecto; >1 separa más los trazos/puntos, <1 los junta).
  final double? estiloLineaEspaciado;
  // --- Punta de línea (solo TipoFigura.linea) ---
  final TipoPuntaLinea? lineaPuntaTipo; // null = ninguna
  final double? lineaPuntaTamano;
  final bool? lineaPuntaIzquierda; // extremo inicial (x=0)
  final bool? lineaPuntaDerecha; // extremo final (x=width)

  // --- Texto ---
  final String? textoContenido;
  final String? textoFontFamily;
  final double? textoFontSize;
  final bool? textoBold;
  final bool? textoItalic;
  final String? textoColorHex;
  final String? textoColorFondoHex; // null = sin fondo
  // Buffer: halo/contorno alrededor del texto (típico de rotulación
  // cartográfica, para legibilidad sobre fondos variables).
  final bool? textoBufferActivo;
  final String? textoBufferColorHex; // null = blanco (ver panel)
  final double? textoBufferAncho;
  final AlineacionTexto? textoAlineacion;
  final double? textoInterlineado; // multiplicador de alto de línea
  final bool? textoSubrayado;
  final bool? textoTachado;
  final double? textoTracking; // espaciado entre letras, en px lógicos

  // --- Imagen ---
  // Base64 de un JPEG ya comprimido/redimensionado en el cliente antes de
  // guardarse (no hay Storage habilitado en este proyecto -ver
  // storage.rules-, así que la imagen se embebe directo en el documento).
  final String? imagenBase64;

  // --- Mapa ---
  final double? mapaLat;
  final double? mapaLng;
  final double? mapaZoom;
  final String? mapaProyecto; // codigo de proyecto cuyos predios se muestran
  // Tipo de mapa base ('estandar'/'satelital'/'satelitalSinEtiquetas'/
  // 'sinMapa', ver MapaBaseLayer en mapa_provider.dart, duplicado aquí como
  // String para no acoplar Composiciones al enum de la pantalla Mapa) y si
  // se muestran las etiquetas de clave catastral sobre los polígonos.
  final String? mapaBaseLayer;
  final bool? mapaMostrarClaves;
  // Etiquetas de PKS (puntos kilométricos) importados en la sesión (ver
  // `pksPointFeaturesProvider`) — igual que `mapaMostrarClaves`, pero para
  // esa capa de puntos en vez de los predios.
  final bool? mapaMostrarPks;
  // Rotación (grados) del contenido del mapa (el mosaico/tiles), distinta
  // de [rotacion] que gira la ventana completa como caja.
  final double? mapaRotacion;
  // Forma del marco de la ventana; null = cuadrada (rectángulo, sin recorte).
  final FormaMarco? mapaFigura;
  // Opacidad (0-1) de la capa de mosaico del mapa base.
  final double? mapaOpacidad;
  // Opacidad (0-1) del relleno/trazo de los polígonos de predios.
  final double? prediosOpacidad;

  // --- Estilo del marco (mapa) ---
  // Si se dibuja un borde alrededor de la forma del marco (ver mapaFigura).
  final bool? mapaBordeActivo;
  final double? mapaBordeGrosor;
  final String? mapaBordeColorHex; // null = negro (ver panel)
  final double? mapaBordeOpacidad;

  // --- Escala gráfica ---
  // Id de un elemento de tipo mapa en la misma hoja del que se deriva la
  // relación px/metros (zoom + latitud); null = sin mapa asociado.
  final String? escalaMapaId;

  // --- Simbología ---
  final TipoSimbologia? simbologiaTipo;

  // --- Gráfica (Balance) ---
  final TipoGrafica? graficaTipo;
  final String? graficaProyecto; // codigo de proyecto a graficar

  const ElementoComposicion({
    required this.id,
    required this.tipo,
    required this.nombreCapa,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotacion = 0,
    this.visible = true,
    this.bloqueado = false,
    this.figuraTipo,
    this.colorTrazoHex,
    this.grosorTrazo,
    this.colorRellenoHex,
    this.estiloLinea,
    this.estiloLineaEspaciado,
    this.lineaPuntaTipo,
    this.lineaPuntaTamano,
    this.lineaPuntaIzquierda,
    this.lineaPuntaDerecha,
    this.textoContenido,
    this.textoFontFamily,
    this.textoFontSize,
    this.textoBold,
    this.textoItalic,
    this.textoColorHex,
    this.textoColorFondoHex,
    this.textoBufferActivo,
    this.textoBufferColorHex,
    this.textoBufferAncho,
    this.textoAlineacion,
    this.textoInterlineado,
    this.textoSubrayado,
    this.textoTachado,
    this.textoTracking,
    this.mapaBaseLayer,
    this.mapaMostrarClaves,
    this.mapaMostrarPks,
    this.mapaRotacion,
    this.mapaFigura,
    this.mapaOpacidad,
    this.prediosOpacidad,
    this.mapaBordeActivo,
    this.mapaBordeGrosor,
    this.mapaBordeColorHex,
    this.mapaBordeOpacidad,
    this.imagenBase64,
    this.mapaLat,
    this.mapaLng,
    this.mapaZoom,
    this.mapaProyecto,
    this.escalaMapaId,
    this.simbologiaTipo,
    this.graficaTipo,
    this.graficaProyecto,
  });

  factory ElementoComposicion.forma({
    required TipoFigura figuraTipo,
    required double x,
    required double y,
    double width = 160,
    double height = 120,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.forma,
      nombreCapa: _nombreFigura(figuraTipo),
      x: x,
      y: y,
      width: width,
      height: height,
      figuraTipo: figuraTipo,
      colorTrazoHex: '#1B6CA8',
      grosorTrazo: 2,
      colorRellenoHex: figuraTipo == TipoFigura.linea
          ? null
          : '#1B6CA81F',
    );
  }

  factory ElementoComposicion.texto({
    required double x,
    required double y,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.texto,
      nombreCapa: 'Texto',
      x: x,
      y: y,
      width: 60,
      height: 18,
      textoContenido: 'Texto',
      textoFontFamily: 'Inter',
      textoFontSize: 16,
      textoBold: false,
      textoItalic: false,
      textoColorHex: '#1A2332',
      textoColorFondoHex: null,
    );
  }

  factory ElementoComposicion.imagen({
    required String base64,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.imagen,
      nombreCapa: 'Imagen',
      x: x,
      y: y,
      width: width,
      height: height,
      imagenBase64: base64,
    );
  }

  factory ElementoComposicion.mapa({
    required double lat,
    required double lng,
    required double zoom,
    required String proyecto,
    required double x,
    required double y,
    String baseLayer = 'estandar',
    bool mostrarClaves = false,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.mapa,
      nombreCapa: 'Mapa',
      x: x,
      y: y,
      width: 200,
      height: 150,
      mapaLat: lat,
      mapaLng: lng,
      mapaZoom: zoom,
      mapaProyecto: proyecto,
      mapaBaseLayer: baseLayer,
      mapaMostrarClaves: mostrarClaves,
    );
  }

  factory ElementoComposicion.norte({
    required double x,
    required double y,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.norte,
      nombreCapa: 'Norte',
      x: x,
      y: y,
      width: 40,
      height: 50,
    );
  }

  factory ElementoComposicion.escala({
    required double x,
    required double y,
    String? mapaId,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.escala,
      nombreCapa: 'Escala',
      x: x,
      y: y,
      width: 120,
      height: 30,
      escalaMapaId: mapaId,
    );
  }

  factory ElementoComposicion.simbologia({
    required TipoSimbologia tipo,
    required double x,
    required double y,
  }) {
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.simbologia,
      nombreCapa: 'Simbología',
      x: x,
      y: y,
      width: 130,
      height: tipo == TipoSimbologia.estatus ? 60 : 170,
      simbologiaTipo: tipo,
    );
  }

  factory ElementoComposicion.grafica({
    required TipoGrafica tipo,
    required String proyecto,
    required double x,
    required double y,
  }) {
    final (width, height) = _tamanoGrafica(tipo);
    return ElementoComposicion(
      id: const Uuid().v4(),
      tipo: TipoElemento.grafica,
      nombreCapa: _nombreGrafica(tipo),
      x: x,
      y: y,
      width: width,
      height: height,
      graficaTipo: tipo,
      graficaProyecto: proyecto,
    );
  }

  static (double, double) _tamanoGrafica(TipoGrafica tipo) {
    switch (tipo) {
      case TipoGrafica.kpiPanel:
        return (220, 110);
      case TipoGrafica.avanceDdv:
        return (240, 140);
      case TipoGrafica.rangoEstatus:
      case TipoGrafica.tipoLiberacion:
        return (260, 200);
      case TipoGrafica.tipoPropiedad:
        return (260, 260);
      case TipoGrafica.segmentoTramoFrente:
      case TipoGrafica.avanceMensual:
      case TipoGrafica.avanceSemanal:
        return (280, 220);
      case TipoGrafica.cadenamiento:
        return (320, 240);
    }
  }

  static String _nombreGrafica(TipoGrafica tipo) {
    switch (tipo) {
      case TipoGrafica.kpiPanel:
        return 'Gráfica: KPIs';
      case TipoGrafica.avanceDdv:
        return 'Gráfica: Avance DDV';
      case TipoGrafica.rangoEstatus:
        return 'Gráfica: Rango de estatus';
      case TipoGrafica.tipoLiberacion:
        return 'Gráfica: Tipo de liberación';
      case TipoGrafica.tipoPropiedad:
        return 'Gráfica: Avance por tipo de propiedad';
      case TipoGrafica.segmentoTramoFrente:
        return 'Gráfica: Avance por segmento/tramo/frente';
      case TipoGrafica.cadenamiento:
        return 'Gráfica: Diagrama por cadenamiento';
      case TipoGrafica.avanceMensual:
        return 'Gráfica: Avance mensual';
      case TipoGrafica.avanceSemanal:
        return 'Gráfica: Avance semanal';
    }
  }

  static String _nombreFigura(TipoFigura tipo) {
    switch (tipo) {
      case TipoFigura.rectangulo:
        return 'Rectángulo';
      case TipoFigura.cuadrado:
        return 'Cuadrado';
      case TipoFigura.triangulo:
        return 'Triángulo';
      case TipoFigura.hexagono:
        return 'Hexágono';
      case TipoFigura.pentagono:
        return 'Pentágono';
      case TipoFigura.linea:
        return 'Línea';
    }
  }

  ElementoComposicion copyWith({
    String? nombreCapa,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotacion,
    bool? visible,
    bool? bloqueado,
    String? colorTrazoHex,
    double? grosorTrazo,
    bool clearColorRelleno = false,
    String? colorRellenoHex,
    EstiloLinea? estiloLinea,
    double? estiloLineaEspaciado,
    TipoPuntaLinea? lineaPuntaTipo,
    double? lineaPuntaTamano,
    bool? lineaPuntaIzquierda,
    bool? lineaPuntaDerecha,
    String? textoContenido,
    String? textoFontFamily,
    double? textoFontSize,
    bool? textoBold,
    bool? textoItalic,
    String? textoColorHex,
    bool clearTextoColorFondo = false,
    String? textoColorFondoHex,
    bool? textoBufferActivo,
    String? textoBufferColorHex,
    double? textoBufferAncho,
    AlineacionTexto? textoAlineacion,
    double? textoInterlineado,
    bool? textoSubrayado,
    bool? textoTachado,
    double? textoTracking,
    double? mapaLat,
    double? mapaLng,
    double? mapaZoom,
    String? mapaBaseLayer,
    bool? mapaMostrarClaves,
    bool? mapaMostrarPks,
    double? mapaRotacion,
    FormaMarco? mapaFigura,
    double? mapaOpacidad,
    double? prediosOpacidad,
    bool? mapaBordeActivo,
    double? mapaBordeGrosor,
    String? mapaBordeColorHex,
    double? mapaBordeOpacidad,
    bool clearEscalaMapaId = false,
    String? escalaMapaId,
    TipoSimbologia? simbologiaTipo,
    TipoGrafica? graficaTipo,
    String? graficaProyecto,
  }) {
    return ElementoComposicion(
      id: id,
      tipo: tipo,
      nombreCapa: nombreCapa ?? this.nombreCapa,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotacion: rotacion ?? this.rotacion,
      visible: visible ?? this.visible,
      bloqueado: bloqueado ?? this.bloqueado,
      figuraTipo: figuraTipo,
      colorTrazoHex: colorTrazoHex ?? this.colorTrazoHex,
      grosorTrazo: grosorTrazo ?? this.grosorTrazo,
      colorRellenoHex: clearColorRelleno ? null : (colorRellenoHex ?? this.colorRellenoHex),
      estiloLinea: estiloLinea ?? this.estiloLinea,
      estiloLineaEspaciado: estiloLineaEspaciado ?? this.estiloLineaEspaciado,
      lineaPuntaTipo: lineaPuntaTipo ?? this.lineaPuntaTipo,
      lineaPuntaTamano: lineaPuntaTamano ?? this.lineaPuntaTamano,
      lineaPuntaIzquierda: lineaPuntaIzquierda ?? this.lineaPuntaIzquierda,
      lineaPuntaDerecha: lineaPuntaDerecha ?? this.lineaPuntaDerecha,
      textoContenido: textoContenido ?? this.textoContenido,
      textoFontFamily: textoFontFamily ?? this.textoFontFamily,
      textoFontSize: textoFontSize ?? this.textoFontSize,
      textoBold: textoBold ?? this.textoBold,
      textoItalic: textoItalic ?? this.textoItalic,
      textoColorHex: textoColorHex ?? this.textoColorHex,
      textoColorFondoHex: clearTextoColorFondo ? null : (textoColorFondoHex ?? this.textoColorFondoHex),
      textoBufferActivo: textoBufferActivo ?? this.textoBufferActivo,
      textoBufferColorHex: textoBufferColorHex ?? this.textoBufferColorHex,
      textoBufferAncho: textoBufferAncho ?? this.textoBufferAncho,
      textoAlineacion: textoAlineacion ?? this.textoAlineacion,
      textoInterlineado: textoInterlineado ?? this.textoInterlineado,
      textoSubrayado: textoSubrayado ?? this.textoSubrayado,
      textoTachado: textoTachado ?? this.textoTachado,
      textoTracking: textoTracking ?? this.textoTracking,
      imagenBase64: imagenBase64,
      mapaLat: mapaLat ?? this.mapaLat,
      mapaLng: mapaLng ?? this.mapaLng,
      mapaZoom: mapaZoom ?? this.mapaZoom,
      mapaProyecto: mapaProyecto,
      mapaBaseLayer: mapaBaseLayer ?? this.mapaBaseLayer,
      mapaMostrarClaves: mapaMostrarClaves ?? this.mapaMostrarClaves,
      mapaMostrarPks: mapaMostrarPks ?? this.mapaMostrarPks,
      mapaRotacion: mapaRotacion ?? this.mapaRotacion,
      mapaFigura: mapaFigura ?? this.mapaFigura,
      mapaOpacidad: mapaOpacidad ?? this.mapaOpacidad,
      prediosOpacidad: prediosOpacidad ?? this.prediosOpacidad,
      mapaBordeActivo: mapaBordeActivo ?? this.mapaBordeActivo,
      mapaBordeGrosor: mapaBordeGrosor ?? this.mapaBordeGrosor,
      mapaBordeColorHex: mapaBordeColorHex ?? this.mapaBordeColorHex,
      mapaBordeOpacidad: mapaBordeOpacidad ?? this.mapaBordeOpacidad,
      escalaMapaId: clearEscalaMapaId ? null : (escalaMapaId ?? this.escalaMapaId),
      simbologiaTipo: simbologiaTipo ?? this.simbologiaTipo,
      graficaTipo: graficaTipo ?? this.graficaTipo,
      graficaProyecto: graficaProyecto ?? this.graficaProyecto,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo.name,
        'nombre_capa': nombreCapa,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotacion': rotacion,
        'visible': visible,
        'bloqueado': bloqueado,
        'figura_tipo': figuraTipo?.name,
        'color_trazo': colorTrazoHex,
        'grosor_trazo': grosorTrazo,
        'color_relleno': colorRellenoHex,
        'estilo_linea': estiloLinea?.name,
        'estilo_linea_espaciado': estiloLineaEspaciado,
        'linea_punta_tipo': lineaPuntaTipo?.name,
        'linea_punta_tamano': lineaPuntaTamano,
        'linea_punta_izquierda': lineaPuntaIzquierda,
        'linea_punta_derecha': lineaPuntaDerecha,
        'texto_contenido': textoContenido,
        'texto_font_family': textoFontFamily,
        'texto_font_size': textoFontSize,
        'texto_bold': textoBold,
        'texto_italic': textoItalic,
        'texto_color': textoColorHex,
        'texto_color_fondo': textoColorFondoHex,
        'texto_buffer_activo': textoBufferActivo,
        'texto_buffer_color': textoBufferColorHex,
        'texto_buffer_ancho': textoBufferAncho,
        'texto_alineacion': textoAlineacion?.name,
        'texto_interlineado': textoInterlineado,
        'texto_subrayado': textoSubrayado,
        'texto_tachado': textoTachado,
        'texto_tracking': textoTracking,
        'imagen_base64': imagenBase64,
        'mapa_lat': mapaLat,
        'mapa_lng': mapaLng,
        'mapa_zoom': mapaZoom,
        'mapa_proyecto': mapaProyecto,
        'mapa_base_layer': mapaBaseLayer,
        'mapa_mostrar_claves': mapaMostrarClaves,
        'mapa_mostrar_pks': mapaMostrarPks,
        'mapa_rotacion': mapaRotacion,
        'mapa_figura': mapaFigura?.name,
        'mapa_opacidad': mapaOpacidad,
        'predios_opacidad': prediosOpacidad,
        'mapa_borde_activo': mapaBordeActivo,
        'mapa_borde_grosor': mapaBordeGrosor,
        'mapa_borde_color': mapaBordeColorHex,
        'mapa_borde_opacidad': mapaBordeOpacidad,
        'escala_mapa_id': escalaMapaId,
        'simbologia_tipo': simbologiaTipo?.name,
        'grafica_tipo': graficaTipo?.name,
        'grafica_proyecto': graficaProyecto,
      };

  factory ElementoComposicion.fromMap(Map<String, dynamic> map) {
    return ElementoComposicion(
      id: (map['id'] as String?) ?? const Uuid().v4(),
      tipo: tipoElementoFromString((map['tipo'] as String?) ?? 'forma'),
      nombreCapa: (map['nombre_capa'] as String?) ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 100,
      height: (map['height'] as num?)?.toDouble() ?? 100,
      rotacion: (map['rotacion'] as num?)?.toDouble() ?? 0,
      visible: (map['visible'] as bool?) ?? true,
      bloqueado: (map['bloqueado'] as bool?) ?? false,
      figuraTipo: map['figura_tipo'] != null ? tipoFiguraFromString(map['figura_tipo'] as String) : null,
      colorTrazoHex: map['color_trazo'] as String?,
      grosorTrazo: (map['grosor_trazo'] as num?)?.toDouble(),
      colorRellenoHex: map['color_relleno'] as String?,
      estiloLinea: map['estilo_linea'] != null
          ? estiloLineaFromString(map['estilo_linea'] as String)
          // Documentos guardados antes de que 'lineaPunteada' se separara
          // en TipoFigura.linea + EstiloLinea.punteada.
          : (map['figura_tipo'] == 'lineaPunteada' ? EstiloLinea.punteada : null),
      estiloLineaEspaciado: (map['estilo_linea_espaciado'] as num?)?.toDouble(),
      lineaPuntaTipo: map['linea_punta_tipo'] != null
          ? tipoPuntaLineaFromString(map['linea_punta_tipo'] as String)
          : null,
      lineaPuntaTamano: (map['linea_punta_tamano'] as num?)?.toDouble(),
      lineaPuntaIzquierda: map['linea_punta_izquierda'] as bool?,
      lineaPuntaDerecha: map['linea_punta_derecha'] as bool?,
      textoContenido: map['texto_contenido'] as String?,
      textoFontFamily: map['texto_font_family'] as String?,
      textoFontSize: (map['texto_font_size'] as num?)?.toDouble(),
      textoBold: map['texto_bold'] as bool?,
      textoItalic: map['texto_italic'] as bool?,
      textoColorHex: map['texto_color'] as String?,
      textoColorFondoHex: map['texto_color_fondo'] as String?,
      textoBufferActivo: map['texto_buffer_activo'] as bool?,
      textoBufferColorHex: map['texto_buffer_color'] as String?,
      textoBufferAncho: (map['texto_buffer_ancho'] as num?)?.toDouble(),
      textoAlineacion:
          map['texto_alineacion'] != null ? alineacionTextoFromString(map['texto_alineacion'] as String) : null,
      textoInterlineado: (map['texto_interlineado'] as num?)?.toDouble(),
      textoSubrayado: map['texto_subrayado'] as bool?,
      textoTachado: map['texto_tachado'] as bool?,
      textoTracking: (map['texto_tracking'] as num?)?.toDouble(),
      imagenBase64: map['imagen_base64'] as String?,
      mapaLat: (map['mapa_lat'] as num?)?.toDouble(),
      mapaLng: (map['mapa_lng'] as num?)?.toDouble(),
      mapaZoom: (map['mapa_zoom'] as num?)?.toDouble(),
      mapaProyecto: map['mapa_proyecto'] as String?,
      mapaBaseLayer: map['mapa_base_layer'] as String?,
      mapaMostrarClaves: map['mapa_mostrar_claves'] as bool?,
      mapaMostrarPks: map['mapa_mostrar_pks'] as bool?,
      mapaRotacion: (map['mapa_rotacion'] as num?)?.toDouble(),
      mapaFigura: map['mapa_figura'] != null ? formaMarcoFromString(map['mapa_figura'] as String) : null,
      mapaOpacidad: (map['mapa_opacidad'] as num?)?.toDouble(),
      prediosOpacidad: (map['predios_opacidad'] as num?)?.toDouble(),
      mapaBordeActivo: map['mapa_borde_activo'] as bool?,
      mapaBordeGrosor: (map['mapa_borde_grosor'] as num?)?.toDouble(),
      mapaBordeColorHex: map['mapa_borde_color'] as String?,
      mapaBordeOpacidad: (map['mapa_borde_opacidad'] as num?)?.toDouble(),
      escalaMapaId: map['escala_mapa_id'] as String?,
      simbologiaTipo:
          map['simbologia_tipo'] != null ? tipoSimbologiaFromString(map['simbologia_tipo'] as String) : null,
      graficaTipo: map['grafica_tipo'] != null ? tipoGraficaFromString(map['grafica_tipo'] as String) : null,
      graficaProyecto: map['grafica_proyecto'] as String?,
    );
  }
}
