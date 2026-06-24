import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Controlador para la captura de pantalla con funcionalidad de recorte interactivo
class GeoportalScreenshotController {
  /// Inicia el proceso de captura con selección de región (modo imagen estática)
  /// [context] - Contexto de Build
  /// [captureFunction] - Función asíncrona que retorna Uint8List con la captura
  /// [onCaptured] - Callback que recibe los bytes de la imagen recortada
  /// [onCancel] - Callback opcional cuando el usuario cancela la captura
  Future<void> startSelectionCapture({
    required BuildContext context,
    required Future<Uint8List> Function() captureFunction,
    required Function(Uint8List) onCaptured,
    VoidCallback? onCancel,
  }) async {
    // Primero capturar la pantalla
    try {
      final fullImageBytes = await captureFunction();
      
      if (!context.mounted) return;
      
      // Luego mostrar el overlay con la imagen capturada
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => CropOverlay(
            fullImageBytes: fullImageBytes,
            onCropped: (bytes) {
              onCaptured(bytes);
              Navigator.of(context).pop();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error al capturar pantalla: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
      }
    }
  }

  /// Inicia el modo de selección en vivo sobre un widget (ej: el mapa)
  /// El usuario puede arrastrar para seleccionar el área mientras ve el contenido en vivo
  /// [context] - Contexto de Build
  /// [child] - Widget sobre el cual se hará la selección (ej: el mapa)
  /// [captureFunction] - Función que captura el widget completo
  /// [onCaptured] - Callback que recibe los bytes de la imagen recortada
  /// [onCancel] - Callback opcional cuando el usuario cancela la selección
  Future<void> startLiveSelectionCapture({
    required BuildContext context,
    required Widget child,
    required Future<Uint8List> Function() captureFunction,
    required Function(Uint8List) onCaptured,
    VoidCallback? onCancel,
  }) async {
    if (!context.mounted) return;
    
    // Mostrar overlay de selección en vivo
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, _, __) => LiveCropOverlay(
          child: child,
          captureFunction: captureFunction,
          onCropped: (bytes) {
            onCaptured(bytes);
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
        ),
      ),
    );
  }
}

/// Widget de superposición para seleccionar la región a recortar
class CropOverlay extends StatefulWidget {
  final Uint8List fullImageBytes;
  final Function(Uint8List) onCropped;
  final VoidCallback onCancel;

  const CropOverlay({
    super.key,
    required this.fullImageBytes,
    required this.onCropped,
    required this.onCancel,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  Offset? startPoint;
  Offset? currentPoint;
  bool isProcessing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Procesa el recorte de la imagen
  Future<void> _processCrop() async {
    if (startPoint == null || currentPoint == null || isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Calcular los límites del rectángulo
      final double left = startPoint!.dx < currentPoint!.dx ? startPoint!.dx : currentPoint!.dx;
      final double top = startPoint!.dy < currentPoint!.dy ? startPoint!.dy : currentPoint!.dy;
      final double width = (startPoint!.dx - currentPoint!.dx).abs();
      final double height = (startPoint!.dy - currentPoint!.dy).abs();

      // Evitar recortes de 0 píxeles
      if (width <= 0 || height <= 0) {
        setState(() => isProcessing = false);
        return;
      }

      // Obtener el pixel ratio
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Convertir coordenadas
      final int x = (left * pixelRatio).round();
      final int y = (top * pixelRatio).round();
      final int w = (width * pixelRatio).round();
      final int h = (height * pixelRatio).round();

      // Recortar usando la librería 'image'
      final img.Image? decodedImage = img.decodePng(widget.fullImageBytes);
      if (decodedImage != null) {
        // Verificar que las coordenadas estén dentro de los límites
        final int cropX = x.clamp(0, decodedImage.width - 1);
        final int cropY = y.clamp(0, decodedImage.height - 1);
        final int cropW = w.clamp(1, decodedImage.width - cropX);
        final int cropH = h.clamp(1, decodedImage.height - cropY);

        final img.Image croppedImage = img.copyCrop(
          decodedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH
        );
        final Uint8List croppedBytes = Uint8List.fromList(img.encodePng(croppedImage));

        widget.onCropped(croppedBytes);
      }
    } catch (e) {
      debugPrint("Error al recortar la pantalla: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
      }
      setState(() {
        isProcessing = false;
      });
    }
  }

  /// Cancela la captura
  void _cancelCapture() {
    widget.onCancel();
  }

  /// Maneja la presión de teclas
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _processCrop();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelCapture();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Rect? selectionRect;
    if (startPoint != null && currentPoint != null) {
      selectionRect = Rect.fromPoints(startPoint!, currentPoint!);
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Container transparente para capturar gestos en toda la pantalla
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // Capa de gestos para dibujar la selección con GestureDetector
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    startPoint = details.localPosition;
                    currentPoint = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  if (startPoint == null) return;
                  setState(() {
                    currentPoint = details.localPosition;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: RegionPainter(selectionRect: selectionRect),
                  ),
                ),
              ),
            ),
            if (isProcessing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: const Text(
                  "Arrastra para seleccionar el área. Presiona Enter o Aceptar para guardar, Escape para cancelar.",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: isProcessing ? null : _cancelCapture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: isProcessing ? null : _processCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Aceptar",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintor personalizado para oscurecer la pantalla excepto el área seleccionada
class RegionPainter extends CustomPainter {
  final Rect? selectionRect;

  RegionPainter({required this.selectionRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar un fondo semitransparente solo si no hay selección
    if (selectionRect == null) {
      final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.3);
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      return;
    }

    // Efecto de máscara: dibuja el fondo oscuro restando el rectángulo del área
    canvas.saveLayer(Offset.zero & size, Paint());
    
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.3);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final cropPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;
    canvas.drawRect(selectionRect!, cropPaint);
    canvas.restore();

    // Dibujar el borde del área seleccionada
    final borderPaint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(selectionRect!, borderPaint);

    // Dibujar esquinas
    final cornerPaint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.fill;

    const cornerSize = 10.0;
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.left - cornerSize / 2, selectionRect!.top - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.right - cornerSize / 2, selectionRect!.top - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.left - cornerSize / 2, selectionRect!.bottom - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.right - cornerSize / 2, selectionRect!.bottom - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
  }

  @override
  bool shouldRepaint(covariant RegionPainter oldDelegate) =>
      oldDelegate.selectionRect != selectionRect;
}

/// Widget de superposición para selección en vivo sobre el contenido
/// Permite arrastrar para seleccionar el área mientras el contenido está visible
class LiveCropOverlay extends StatefulWidget {
  final Widget child;
  final Future<Uint8List> Function() captureFunction;
  final Function(Uint8List) onCropped;
  final VoidCallback onCancel;

  const LiveCropOverlay({
    super.key,
    required this.child,
    required this.captureFunction,
    required this.onCropped,
    required this.onCancel,
  });

  @override
  State<LiveCropOverlay> createState() => _LiveCropOverlayState();
}

class _LiveCropOverlayState extends State<LiveCropOverlay> {
  Offset? startPoint;
  Offset? currentPoint;
  bool isProcessing = false;
  final FocusNode _focusNode = FocusNode();
  GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Procesa el recorte de la imagen
  Future<void> _processCrop() async {
    if (startPoint == null || currentPoint == null || isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Primero capturar la pantalla completa
      final fullImageBytes = await widget.captureFunction();
      
      if (!mounted) return;

      // Calcular los límites del rectángulo
      final double left = startPoint!.dx < currentPoint!.dx ? startPoint!.dx : currentPoint!.dx;
      final double top = startPoint!.dy < currentPoint!.dy ? startPoint!.dy : currentPoint!.dy;
      final double width = (startPoint!.dx - currentPoint!.dx).abs();
      final double height = (startPoint!.dy - currentPoint!.dy).abs();

      // Evitar recortes de 0 píxeles
      if (width <= 0 || height <= 0) {
        setState(() => isProcessing = false);
        return;
      }

      // Obtener el pixel ratio
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Convertir coordenadas
      final int x = (left * pixelRatio).round();
      final int y = (top * pixelRatio).round();
      final int w = (width * pixelRatio).round();
      final int h = (height * pixelRatio).round();

      // Recortar usando la librería 'image'
      final img.Image? decodedImage = img.decodePng(fullImageBytes);
      if (decodedImage != null) {
        // Verificar que las coordenadas estén dentro de los límites
        final int cropX = x.clamp(0, decodedImage.width - 1);
        final int cropY = y.clamp(0, decodedImage.height - 1);
        final int cropW = w.clamp(1, decodedImage.width - cropX);
        final int cropH = h.clamp(1, decodedImage.height - cropY);

        final img.Image croppedImage = img.copyCrop(
          decodedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH
        );
        final Uint8List croppedBytes = Uint8List.fromList(img.encodePng(croppedImage));

        widget.onCropped(croppedBytes);
      }
    } catch (e) {
      debugPrint("Error al recortar la pantalla: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
      }
      setState(() {
        isProcessing = false;
      });
    }
  }

  /// Cancela la captura
  void _cancelCapture() {
    widget.onCancel();
  }

  /// Maneja la presión de teclas
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _processCrop();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelCapture();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Rect? selectionRect;
    if (startPoint != null && currentPoint != null) {
      selectionRect = Rect.fromPoints(startPoint!, currentPoint!);
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // El widget hijo (mapa) - debe ser interactivo
            Positioned.fill(
              child: KeyedSubtree(
                key: _childKey,
                child: widget.child,
              ),
            ),
            // Capa semitransparente sobre el contenido
            Positioned.fill(
              child: Container(
                color: selectionRect == null 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            // Si hay selección, mostrar el área seleccionada sin oscurecer
            if (selectionRect != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: LiveRegionPainter(selectionRect: selectionRect),
                ),
              ),
            // Capa de gestos para dibujar la selección
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  setState(() {
                    startPoint = details.localPosition;
                    currentPoint = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  if (startPoint == null) return;
                  setState(() {
                    currentPoint = details.localPosition;
                  });
                },
                onPanEnd: (details) {
                  // No hacer nada automáticamente, esperar a que el usuario confirme
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                ),
              ),
            ),
            if (isProcessing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            // Instrucciones
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: const Text(
                  "Arrastra para seleccionar el área del mapa.\nPresiona Enter o Aceptar para capturar, Escape para cancelar.",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Botones
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: isProcessing || startPoint == null ? null : _cancelCapture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: isProcessing || startPoint == null ? null : _processCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Capturar",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintor personalizado para el modo vivo - oscurece todo excepto el área seleccionada
class LiveRegionPainter extends CustomPainter {
  final Rect? selectionRect;

  LiveRegionPainter({required this.selectionRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect == null) return;

    // Crear una capa para el efecto de máscara
    canvas.saveLayer(Offset.zero & size, Paint());
    
    // Dibujar fondo semitransparente
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.3);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // "Cortar" el área seleccionada (hacerla transparente para ver el contenido debajo)
    final cropPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;
    canvas.drawRect(selectionRect!, cropPaint);
    canvas.restore();

    // Dibujar borde del área seleccionada
    final borderPaint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(selectionRect!, borderPaint);

    // Dibujar esquinas decorativas
    final cornerPaint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.fill;

    const cornerSize = 12.0;
    // Esquina superior izquierda
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.left - cornerSize / 2, selectionRect!.top - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    // Esquina superior derecha
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.right - cornerSize / 2, selectionRect!.top - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    // Esquina inferior izquierda
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.left - cornerSize / 2, selectionRect!.bottom - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
    // Esquina inferior derecha
    canvas.drawRect(
      Rect.fromLTWH(selectionRect!.right - cornerSize / 2, selectionRect!.bottom - cornerSize / 2, cornerSize, cornerSize),
      cornerPaint
    );
  }

  @override
  bool shouldRepaint(covariant LiveRegionPainter oldDelegate) =>
      oldDelegate.selectionRect != selectionRect;
}
