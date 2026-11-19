import 'theme_color_stub.dart'
    if (dart.library.js_interop) 'theme_color_web.dart' as impl;

/// Sets the browser's theme colour, which an installed web app uses for the
/// status bar and the bottom navigation strip. [argb] is 0xAARRGGBB.
void setThemeColor(int argb) => impl.setThemeColor(argb);
