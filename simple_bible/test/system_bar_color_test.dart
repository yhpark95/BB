import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/widgets/system_bar_color.dart';

void main() {
  Widget app(ThemeMode mode, List<int> sink, {bool enabled = true}) =>
      MaterialApp(
        themeMode: mode,
        theme: ThemeData(colorScheme: const ColorScheme.light()),
        darkTheme: ThemeData(colorScheme: const ColorScheme.dark()),
        builder: (context, child) =>
            SystemBarColor(enabled: enabled, apply: sink.add, child: child!),
        home: const Scaffold(),
      );

  testWidgets('light and dark each paint the bars in the page colour',
      (t) async {
    final sink = <int>[];
    await t.pumpWidget(app(ThemeMode.light, sink));
    expect(sink.last, const ColorScheme.light().surface.toARGB32());

    await t.pumpWidget(app(ThemeMode.dark, sink));
    await t.pumpAndSettle();
    expect(sink.last, const ColorScheme.dark().surface.toARGB32());
  });

  testWidgets('off outside the web: nothing is applied', (t) async {
    final sink = <int>[];
    await t.pumpWidget(app(ThemeMode.light, sink, enabled: false));
    expect(sink, isEmpty);
  });
}
