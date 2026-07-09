import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _webPdfPreviewCounter = 0;

Widget buildWebPdfPreview(Uint8List bytes, {Key? key}) {
  return _WebPdfPreview(key: key, bytes: bytes);
}

class _WebPdfPreview extends StatefulWidget {
  const _WebPdfPreview({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<_WebPdfPreview> createState() => _WebPdfPreviewState();
}

class _WebPdfPreviewState extends State<_WebPdfPreview> {
  late final String _viewType;
  late final html.EmbedElement _embed;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}-${_webPdfPreviewCounter++}';
    _embed = html.EmbedElement()
      ..type = 'application/pdf'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _setPdfSource(widget.bytes);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _embed);
  }

  @override
  void didUpdateWidget(covariant _WebPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes.length != widget.bytes.length) {
      _setPdfSource(widget.bytes);
      return;
    }
    for (int i = 0; i < widget.bytes.length; i++) {
      if (oldWidget.bytes[i] != widget.bytes[i]) {
        _setPdfSource(widget.bytes);
        return;
      }
    }
  }

  void _setPdfSource(Uint8List bytes) {
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
    }
    _objectUrl = html.Url.createObjectUrlFromBlob(
      html.Blob(<dynamic>[bytes], 'application/pdf'),
    );
    _embed.src = _objectUrl!;
  }

  @override
  void dispose() {
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}