
import 'package:flutter/foundation.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';

class WidgetPreviewGroup {
  const WidgetPreviewGroup({required this.name, required this.previews});

  bool get hasPreviews => previews.isNotEmpty;

  final String name;

  final List<WidgetPreview> previews;
}

class WidgetPreview {
  const WidgetPreview({
    required this.builder,
    required this.scriptUri,
    required this.line,
    required this.column,
    required this.previewData,
    required this.packageName,
  });

  @visibleForTesting
  const WidgetPreview.test({
    required this.builder,
    required this.previewData,
    this.scriptUri = '',
    this.line = -1,
    this.column = -1,
    this.packageName = '',
  });

  final String scriptUri;

  final int line;

  final int column;

  final String packageName;

  String? get name => previewData.name;

  final Widget Function() builder;

  Widget Function() get previewBuilder {
    if (previewData.wrapper == null) {
      return builder;
    }
    return switch (previewData) {
      Preview(:final Widget Function(Widget) wrapper) => () => wrapper(
        builder(),
      ),
      _ => builder,
    };
  }

  Size? get size => previewData.size;

  double? get textScaleFactor => previewData.textScaleFactor;

  PreviewThemeData? get theme => previewData.theme?.call();

  Brightness? get brightness => previewData.brightness;

  PreviewLocalizationsData? get localizations =>
      previewData.localizations?.call();

  final Preview previewData;

  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty<String>('name', name, ifNull: 'not set'))
      ..add(DiagnosticsProperty<String>('group', previewData.group))
      ..add(DiagnosticsProperty<Size>('size', size))
      ..add(DiagnosticsProperty<double>('textScaleFactor', textScaleFactor))
      ..add(DiagnosticsProperty<PreviewThemeData>('theme', theme))
      ..add(DiagnosticsProperty<Brightness>('brightness', brightness))
      ..add(
        DiagnosticsProperty<PreviewLocalizationsData>(
          'localizations',
          localizations,
        ),
      );
  }
}
