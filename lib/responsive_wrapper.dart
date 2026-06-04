import 'package:flutter/material.dart';

/// Un widget che centra il contenuto e lo limita a una larghezza massima
/// su schermi grandi (tablet, iPad, desktop), lasciandolo invariato su telefoni.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600, // Larghezza ideale per leggere (come un telefono grande)
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Breakpoints utili per decidere il layout in base alla dimensione dello schermo
class ScreenSize {
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  /// Restituisce la larghezza dello schermo
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Restituisce l'altezza dello schermo
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;
}
