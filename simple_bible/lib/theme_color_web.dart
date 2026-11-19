import 'package:web/web.dart' as web;

/// Writes the colour into the page's own <meta name="theme-color"> (the first
/// one in index.html). Flutter adds a second tag of its own later, but the
/// browser reads the first, so this is the one that has to change.
void setThemeColor(int argb) {
  final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final meta = web.document.querySelector('meta[name="theme-color"]');
  meta?.setAttribute('content', '#$hex');
}
