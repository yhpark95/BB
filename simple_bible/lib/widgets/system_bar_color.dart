import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme_color.dart';

/// Paints the browser's own bars to match the app. An installed web app lets
/// Android colour its status bar and bottom navigation strip; with the fixed
/// blue from the manifest they showed as blue bands around a dark page.
///
/// Follows the current theme, so it changes with 밝게/어둡게/자동 as well.
class SystemBarColor extends StatelessWidget {
  final Widget child;

  /// Only the web has bars to colour. Tests turn it on.
  final bool enabled;

  /// Where the colour goes. Tests record it.
  final void Function(int argb) apply;

  const SystemBarColor({
    super.key,
    required this.child,
    bool? enabled,
    this.apply = setThemeColor,
  }) : enabled = enabled ?? kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (enabled) apply(Theme.of(context).colorScheme.surface.toARGB32());
    return child;
  }
}
