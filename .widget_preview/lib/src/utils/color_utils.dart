
import 'dart:ui';

Color? tryParseColor(String? input) {
  if (input == null) return null;

  try {
    return parseCssHexColor(input);
  } catch (e) {
    return null;
  }
}

Color parseCssHexColor(String input) {
  input = input.replaceAll('#', '').replaceAll('%23', '');

  if (input.length == 3 || input.length == 4) {
    input = input.split('').map((c) => '$c$c').join();
  }

  if (input.length == 6) {
    input = '${input}ff';
  }

  if (input.length == 8) {
    input = '${input.substring(6)}${input.substring(0, 6)}';
  }
  final value = int.parse(input, radix: 16);

  return Color(value);
}

extension ColorExtension on Color {
  Color darken([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);
    percent = 1.0 - percent;

    final c = this;
    return Color.from(
      alpha: c.a,
      red: c.r * percent,
      green: c.g * percent,
      blue: c.b * percent,
    );
  }

  Color brighten([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);

    final c = this;
    return Color.from(
      alpha: c.a,
      red: c.r + ((1.0 - c.r) * percent),
      green: c.g + ((1.0 - c.g) * percent),
      blue: c.b + ((1.0 - c.b) * percent),
    );
  }
}
