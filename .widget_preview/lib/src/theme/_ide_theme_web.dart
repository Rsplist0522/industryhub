

import 'dart:ui';

import 'package:web/web.dart';

import '../utils/url/url.dart';
import 'ide_theme.dart';

IdeTheme getIdeTheme() {
  final queryParams = IdeThemeQueryParams(loadQueryParams());

  final overrides = IdeTheme(
    backgroundColor: queryParams.backgroundColor,
    foregroundColor: queryParams.foregroundColor,
    isDarkMode: queryParams.darkMode,
  );

  if (overrides.backgroundColor != null) {
    document.body!.style.backgroundColor = toCssHexColor(
      overrides.backgroundColor!,
    );
  }

  return overrides;
}

String toCssHexColor(Color color) {
  String hex(double channelValue) =>
      (channelValue * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${hex(color.r)}${hex(color.g)}${hex(color.b)}${hex(color.a)}';
}
