import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Una diapositiva de salida: el raster PNG de una hoja (mismo usado para
/// PNG/PDF) más sus dimensiones reales en mm.
class PptxSlideImage {
  const PptxSlideImage({
    required this.pngBytes,
    required this.anchoMm,
    required this.altoMm,
  });

  final Uint8List pngBytes;
  final double anchoMm;
  final double altoMm;
}

/// Genera un archivo `.pptx` mínimo (un ZIP de XML, formato OOXML) con una
/// diapositiva por [PptxSlideImage], cada una como una sola imagen a
/// pantalla completa. No hay ningún paquete Dart/Flutter que genere PPTX,
/// así que este es un generador OOXML escrito a mano (solo lo
/// imprescindible para un archivo válido: content types, relaciones,
/// presentation/slideMaster/slideLayout/theme mínimos, y un `<p:pic>` por
/// diapositiva). El tamaño de diapositiva del documento completo se fija
/// al de la primera hoja (OOXML no admite tamaños de página distintos por
/// diapositiva, a diferencia de un PDF); las hojas siguientes con otro
/// tamaño/orientación se centran dentro de esa diapositiva sin
/// deformarse (ajuste "contain").
///
/// Alcance deliberadamente limitado: cada diapositiva es una imagen
/// plana, no formas/texto nativos editables de PowerPoint -eso
/// requeriría traducir cada `ElementoComposicion` a DrawingML, un trabajo
/// mucho mayor fuera de alcance de esta fase-.
class PptxWriter {
  static const double _emuPorMm = 36000;

  static Uint8List build(List<PptxSlideImage> slides, {String titulo = 'Composición'}) {
    if (slides.isEmpty) {
      throw ArgumentError('slides no puede estar vacío');
    }

    final slideWidthEmu = (slides.first.anchoMm * _emuPorMm).round();
    final slideHeightEmu = (slides.first.altoMm * _emuPorMm).round();

    final archive = Archive();
    void addText(String path, String content) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    void addBinary(String path, Uint8List bytes) {
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final slideOverrides = StringBuffer();
    for (var i = 1; i <= slides.length; i++) {
      slideOverrides.write(
        '<Override PartName="/ppt/slides/slide$i.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }

    addText('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
$slideOverrides
</Types>''');

    addText('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''');

    addText('docProps/core.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:title>${_escapeXml(titulo)}</dc:title>
<dc:creator>Geoportal de Gestión</dc:creator>
<cp:revision>1</cp:revision>
</cp:coreProperties>''');

    addText('docProps/app.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Geoportal de Gestión</Application>
<Slides>${slides.length}</Slides>
</Properties>''');

    final sldIdLst = StringBuffer();
    final presRelsSlides = StringBuffer();
    for (var i = 1; i <= slides.length; i++) {
      sldIdLst.write('<p:sldId id="${255 + i}" r:id="rIdSlide$i"/>');
      presRelsSlides.write(
        '<Relationship Id="rIdSlide$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>',
      );
    }

    addText('ppt/presentation.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rIdMaster1"/></p:sldMasterIdLst>
<p:sldIdLst>$sldIdLst</p:sldIdLst>
<p:sldSz cx="$slideWidthEmu" cy="$slideHeightEmu"/>
<p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''');

    addText('ppt/_rels/presentation.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
$presRelsSlides
</Relationships>''');

    addText('ppt/slideMasters/slideMaster1.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld>
<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree>
</p:cSld>
<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rIdLayout1"/></p:sldLayoutIdLst>
</p:sldMaster>''');

    addText('ppt/slideMasters/_rels/slideMaster1.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdLayout1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
<Relationship Id="rIdTheme1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''');

    addText('ppt/slideLayouts/slideLayout1.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
<p:cSld name="Blanco">
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree>
</p:cSld>
<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''');

    addText('ppt/slideLayouts/_rels/slideLayout1.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''');

    addText('ppt/theme/theme1.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Geoportal">
<a:themeElements>
<a:clrScheme name="Geoportal">
<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
<a:dk2><a:srgbClr val="1F497D"/></a:dk2>
<a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
<a:accent1><a:srgbClr val="1B6CA8"/></a:accent1>
<a:accent2><a:srgbClr val="4CAF50"/></a:accent2>
<a:accent3><a:srgbClr val="F2C94C"/></a:accent3>
<a:accent4><a:srgbClr val="EB5757"/></a:accent4>
<a:accent5><a:srgbClr val="9B51E0"/></a:accent5>
<a:accent6><a:srgbClr val="56CCF2"/></a:accent6>
<a:hlink><a:srgbClr val="0563C1"/></a:hlink>
<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
</a:clrScheme>
<a:fontScheme name="Geoportal">
<a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Geoportal">
<a:fillStyleLst>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
</a:fillStyleLst>
<a:lnStyleLst>
<a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
</a:lnStyleLst>
<a:effectStyleLst>
<a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle>
</a:effectStyleLst>
<a:bgFillStyleLst>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
</a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
</a:theme>''');

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final n = i + 1;
      addBinary('ppt/media/image$n.png', slide.pngBytes);

      // Ajuste "contain": la imagen de esta hoja se centra dentro del
      // tamaño de diapositiva del documento (el de la primera hoja) sin
      // deformarse, por si esta hoja tiene otro tamaño/orientación.
      final hojaWidthEmu = slide.anchoMm * _emuPorMm;
      final hojaHeightEmu = slide.altoMm * _emuPorMm;
      final escala = (slideWidthEmu / hojaWidthEmu < slideHeightEmu / hojaHeightEmu)
          ? slideWidthEmu / hojaWidthEmu
          : slideHeightEmu / hojaHeightEmu;
      final picW = (hojaWidthEmu * escala).round();
      final picH = (hojaHeightEmu * escala).round();
      final offX = ((slideWidthEmu - picW) / 2).round();
      final offY = ((slideHeightEmu - picH) / 2).round();

      addText('ppt/slides/slide$n.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld>
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
<p:pic>
<p:nvPicPr><p:cNvPr id="2" name="Hoja $n"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>
<p:blipFill><a:blip r:embed="rIdImage$n"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
<p:spPr>
<a:xfrm><a:off x="$offX" y="$offY"/><a:ext cx="$picW" cy="$picH"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
</p:spPr>
</p:pic>
</p:spTree>
</p:cSld>
<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''');

      addText('ppt/slides/_rels/slide$n.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdImage$n" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$n.png"/>
</Relationships>''');
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('No se pudo generar el archivo PPTX.');
    }
    return Uint8List.fromList(zipBytes);
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
