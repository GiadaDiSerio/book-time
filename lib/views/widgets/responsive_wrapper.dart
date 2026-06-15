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
