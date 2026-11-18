import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Scroll horizontal con una barra persistente y bien visible en pantallas
/// móviles. Si el contenido no cabe, muestra además el aviso "Desliza para
/// ver más" para que el usuario sepa que puede desplazarse.
class MobileHorizontalScroll extends StatefulWidget {
  const MobileHorizontalScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<MobileHorizontalScroll> createState() => _MobileHorizontalScrollState();
}

class _MobileHorizontalScrollState extends State<MobileHorizontalScroll> {
  final _controller = ScrollController();
  bool _desborda = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _actualizarDesborde(ScrollMetricsNotification n) {
    final desborda = n.metrics.maxScrollExtent > 0;
    if (desborda != _desborda) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _desborda = desborda);
      });
    }
    return false;
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
    final color = AppColors.primary;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _actualizarDesborde,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStatePropertyAll(color),
              trackColor: WidgetStatePropertyAll(color.withValues(alpha: 0.15)),
              trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
              radius: const Radius.circular(6),
            ),
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 9,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: scroll,
              ),
            ),
          ),
          if (_desborda)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.swipe_left_outlined, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'Desliza para ver más',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
