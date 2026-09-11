
import 'package:flutter/widgets.dart';
import 'package:widget_preview_scaffold/src/dtd/dtd_connection_info.dart';
import 'package:widget_preview_scaffold/src/dtd/dtd_services.dart';
import 'package:widget_preview_scaffold/src/dtd/editor_service.dart';
import 'package:widget_preview_scaffold/src/widget_preview_rendering.dart';

class WidgetPreviewScaffoldInspectorService with WidgetInspectorService {
  WidgetPreviewScaffoldInspectorService({required this.dtdServices}) {
    WidgetInspectorService.instance = this;
    addPubRootDirectories(<String>[kProjectRootPath]);
  }

  final WidgetPreviewScaffoldDtdServices dtdServices;

  static const kFile = 'fileUri';
  static const kLine = 'line';
  static const kColumn = 'column';

  CodeLocation? _nextNavigationLocation;

  @protected
  @override
  bool setSelection(Object? object, [String? groupName]) {
    if (object is PreviewWidgetElement) {
      final previewData = (object.widget as PreviewWidget).preview;
      _nextNavigationLocation = CodeLocation(
        uri: previewData.scriptUri,
        line: previewData.line,
        column: previewData.column,
      );
    }
    final result = super.setSelection(object, groupName);
    _nextNavigationLocation = null;
    return result;
  }

  @override
  void postEvent(
    String eventKind,
    Map<Object, Object?> eventData, {
    String stream = 'Extension',
  }) {
    if (eventKind == 'navigate') {
      CodeLocation? location = _nextNavigationLocation;
      if (eventData case {
        kFile: final String file,
        kLine: final int line,
        kColumn: final int column,
      } when location == null) {
        location = CodeLocation(uri: file, line: line, column: column);
      } else if (location != null) {
        eventData.addAll(<String, Object>{
          kFile: location.uri,
          kLine: location.line!,
          kColumn: location.column!,
        });
      }
      if (location != null) {
        dtdServices.navigateToCode(location);
      }
    }
    super.postEvent(eventKind, eventData, stream: stream);
  }
}
