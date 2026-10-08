import 'package:flutter/material.dart';

/// Scroll horizontal con una barra persistente en pantallas móviles.
class MobileHorizontalScroll extends StatefulWidget {
  const MobileHorizontalScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<MobileHorizontalScroll> createState() => _MobileHorizontalScrollState();
}

class _MobileHorizontalScrollState extends State<MobileHorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final scroll = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: widget.child,
    );
    if (!mobile) return scroll;
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 6,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: scroll,
      ),
    );
  }
}
