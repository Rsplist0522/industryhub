

import 'package:flutter/widgets.dart';

import '../utils/color_utils.dart';
import 'theme.dart';

export '_ide_theme_desktop.dart'
    if (dart.library.js_interop) '_ide_theme_web.dart';

final class IdeTheme {
  const IdeTheme({this.backgroundColor, this.foregroundColor, bool? isDarkMode})
    : _isDarkMode = isDarkMode;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? _isDarkMode;

  bool get isDarkMode => _isDarkMode ?? useDarkThemeAsDefault;

  bool get ideSpecifiedTheme => _isDarkMode != null;
}

extension type IdeThemeQueryParams(Map<String, String?> params) {
  Color? get backgroundColor => tryParseColor(params[backgroundColorKey]);

  Color? get foregroundColor => tryParseColor(params[foregroundColorKey]);

  bool get darkMode => params[devToolsThemeKey] != lightThemeValue;

  static const backgroundColorKey = 'backgroundColor';
  static const foregroundColorKey = 'foregroundColor';
  static const devToolsThemeKey = 'theme';
  static const lightThemeValue = 'light';
  static const darkThemeValue = 'dark';
}
