
import 'dart:async';

import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:widget_preview_scaffold/src/dtd/dtd_services.dart';
import 'package:widget_preview_scaffold/src/dtd/utils.dart';

mixin DtdEditorService {
  DartToolingDaemon get dtd;

  static const String kEditorService = 'Editor';

  static const String kGetActiveLocation = 'getActiveLocation';

  static const String kNavigateToCode = 'navigateToCode';

  static const String kServiceStream = 'Service';

  static const kServiceRegistered = 'ServiceRegistered';

  static const kServiceUnregistered = 'ServiceUnregistered';

  ValueListenable<bool> get editorServiceAvailable => _editorServiceAvailable;
  static final _editorServiceAvailable = ValueNotifier<bool>(false);

  ValueListenable<TextDocument?> get selectedSourceFile => _selectedSourceFile;
  static final _selectedSourceFile = ValueNotifier<TextDocument?>(null);

  ValueListenable<EditorTheme?> get editorTheme => _editorTheme;
  static final _editorTheme = ValueNotifier<EditorTheme?>(null);

  Future<void> initializeEditorService(
    WidgetPreviewScaffoldDtdServices dtdServices,
  ) async {
    final editorKindMap = EditorEventKind.values.asNameMap();
    dtd.onEvent(kEditorService).listen((data) {
      final kind = editorKindMap[data.kind];
      switch (kind) {
        case null:
          break;
        case EditorEventKind.themeChanged:
          _editorTheme.value = ThemeChangedEvent.fromJson(data.data).theme;
        case EditorEventKind.activeLocationChanged:
          _selectedSourceFile.value = ActiveLocationChangedEvent.fromJson(
            data.data,
          ).textDocument;
      }
    });
    await dtd.safeStreamListen(kEditorService);

    dtd.onEvent(kServiceStream).listen((data) async {
      switch (data) {
        case DTDEvent(
          kind: kServiceRegistered,
          data: {
            DtdParameters.service: kEditorService,
            DtdParameters.method: kGetActiveLocation,
          },
        ):
          unawaited(_updateSelectedSourceFile());
          _editorServiceAvailable.value = true;
        case DTDEvent(
          kind: kServiceRegistered,
          data: {DtdParameters.service: kEditorService},
        ):
          _editorServiceAvailable.value = true;
        case DTDEvent(
          kind: kServiceUnregistered,
          data: {DtdParameters.service: kEditorService},
        ):
          _editorServiceAvailable.value = false;
      }
    });
    await dtd.safeStreamListen(kServiceStream);
  }

  @mustCallSuper
  void dispose() {
    _selectedSourceFile.dispose();
    _editorServiceAvailable.dispose();
    _editorTheme.dispose();
  }

  Future<void> _updateSelectedSourceFile() async {
    final response = await dtd.safeCall(kEditorService, kGetActiveLocation);
    if (response != null) {
      _selectedSourceFile.value = ActiveLocation.fromJson(
        response.result,
      ).textDocument;
    }
  }

  Future<void> navigateToCode(CodeLocation location) async {
    await dtd.safeCall(
      kEditorService,
      kNavigateToCode,
      params: location.toJson(),
    );
  }
}


enum EditorEventKind {
  themeChanged,

  activeLocationChanged,
}

sealed class EditorEvent {
  EditorEventKind get kind;
}

class EditorTheme {
  EditorTheme({
    required this.isDarkMode,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fontSize,
  });

  EditorTheme.fromJson(Map<String, Object?> map)
    : this(
        isDarkMode: map[Field.isDarkMode] as bool,
        backgroundColor: map[Field.backgroundColor] as String?,
        foregroundColor: map[Field.foregroundColor] as String?,
        fontSize: map[Field.fontSize] as int?,
      );

  final bool isDarkMode;
  final String? backgroundColor;
  final String? foregroundColor;
  final int? fontSize;

  Map<String, Object?> toJson() => {
    Field.isDarkMode: isDarkMode,
    Field.backgroundColor: backgroundColor,
    Field.foregroundColor: foregroundColor,
    Field.fontSize: fontSize,
  };
}

class ThemeChangedEvent extends EditorEvent {
  ThemeChangedEvent({required this.theme});

  ThemeChangedEvent.fromJson(Map<String, Object?> map)
    : this(
        theme: EditorTheme.fromJson(map[Field.theme] as Map<String, Object?>),
      );

  final EditorTheme theme;

  @override
  EditorEventKind get kind => EditorEventKind.themeChanged;

  Map<String, Object?> toJson() => {Field.theme: theme};
}

class ActiveLocationChangedEvent extends ActiveLocation implements EditorEvent {
  ActiveLocationChangedEvent({required ActiveLocation activeLocation})
    : super(
        selections: activeLocation.selections,
        textDocument: activeLocation.textDocument,
      );

  ActiveLocationChangedEvent.fromJson(Map<String, Object?> map)
    : this(activeLocation: ActiveLocation.fromJson(map));

  @override
  EditorEventKind get kind => EditorEventKind.activeLocationChanged;
}

class ActiveLocation {
  ActiveLocation({required this.selections, required this.textDocument});

  ActiveLocation.fromJson(Map<String, Object?> map)
    : this(
        textDocument: map.containsKey(Field.textDocument)
            ? TextDocument.fromJson(
                map[Field.textDocument] as Map<String, Object?>,
              )
            : null,
        selections: (map[Field.selections] as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(EditorSelection.fromJson)
            .toList(),
      );

  final List<EditorSelection> selections;
  final TextDocument? textDocument;

  Map<String, Object?> toJson() => {
    Field.selections: selections,
    Field.textDocument: textDocument,
  };
}

class TextDocument {
  TextDocument({required this.uriAsString, required this.version});

  TextDocument.fromJson(Map<String, Object?> map)
    : this(
        uriAsString: map[Field.uri] as String,
        version: map[Field.version] as int?,
      );

  final String uriAsString;
  final int? version;

  Map<String, Object?> toJson() => {
    Field.uri: uriAsString,
    Field.version: version,
  };

  @override
  bool operator ==(Object other) {
    return other is TextDocument &&
        other.uriAsString == uriAsString &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(uriAsString, version);
}

class EditorSelection {
  EditorSelection({required this.active, required this.anchor});

  EditorSelection.fromJson(Map<String, Object?> map)
    : this(
        active: CursorPosition.fromJson(
          map[Field.active] as Map<String, Object?>,
        ),
        anchor: CursorPosition.fromJson(
          map[Field.anchor] as Map<String, Object?>,
        ),
      );

  final CursorPosition active;
  final CursorPosition anchor;

  Map<String, Object?> toJson() => {
    Field.active: active.toJson(),
    Field.anchor: anchor.toJson(),
  };
}

class EditorRange {
  EditorRange({required this.start, required this.end});

  EditorRange.fromJson(Map<String, Object?> map)
    : this(
        start: CursorPosition.fromJson(
          map[Field.start] as Map<String, Object?>,
        ),
        end: CursorPosition.fromJson(map[Field.end] as Map<String, Object?>),
      );

  final CursorPosition start;

  final CursorPosition end;

  Map<String, Object?> toJson() => {
    Field.start: start.toJson(),
    Field.end: end.toJson(),
  };
}

class CursorPosition {
  CursorPosition({required this.character, required this.line});

  CursorPosition.fromJson(Map<String, Object?> map)
    : this(
        character: map[Field.character] as int,
        line: map[Field.line] as int,
      );

  final int character;

  final int line;

  Map<String, Object?> toJson() => {
    Field.character: character,
    Field.line: line,
  };

  @override
  bool operator ==(Object other) {
    return other is CursorPosition &&
        other.character == character &&
        other.line == line;
  }

  @override
  int get hashCode => Object.hash(character, line);
}

class CodeLocation {
  const CodeLocation({required this.uri, this.line, this.column});

  final String uri;

  final int? line;

  final int? column;

  Map<String, Object?> toJson() => {
    Field.uri: uri,
    Field.line: ?line,
    Field.column: ?column,
  };
}

abstract class Field {
  static const active = 'active';
  static const anchor = 'anchor';
  static const backgroundColor = 'backgroundColor';
  static const character = 'character';
  static const column = 'column';
  static const end = 'end';
  static const fontSize = 'fontSize';
  static const foregroundColor = 'foregroundColor';
  static const isDarkMode = 'isDarkMode';
  static const line = 'line';
  static const selections = 'selections';
  static const start = 'start';
  static const textDocument = 'textDocument';
  static const theme = 'theme';
  static const uri = 'uri';
  static const version = 'version';
}
