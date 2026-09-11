
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:widget_preview_scaffold/src/widget_preview_rendering.dart';
import 'dtd/dtd_services.dart';
import 'widget_preview.dart';

enum LayoutType { gridView, listView }

typedef WidgetPreviews = Iterable<WidgetPreview>;
typedef WidgetPreviewGroups = Iterable<WidgetPreviewGroup>;
typedef PreviewsCallback = WidgetPreviews Function();

class WidgetPreviewScaffoldController {
  WidgetPreviewScaffoldController({
    required PreviewsCallback previews,
    @visibleForTesting WidgetPreviewScaffoldDtdServices? dtdServicesOverride,
  }) : _previews = previews,
       dtdServices = dtdServicesOverride ?? WidgetPreviewScaffoldDtdServices();

  @visibleForTesting
  static const kFilterBySelectedFilePreference = 'filterBySelectedFile';

  Future<void> initialize() async {
    await dtdServices.connect();
    context = path.Context(
      style: dtdServices.isWindows ? path.Style.windows : path.Style.posix,
    );
    _registerListeners();
    await Future.wait<void>([
      dtdServices
          .getFlag(kFilterBySelectedFilePreference, defaultValue: true)
          .then((value) => _filterBySelectedFile.value = value),
      dtdServices.getDevToolsUri().then((uri) {
        devToolsUri = uri;
      }),
    ]);
  }

  Future<void> dispose() async {
    await dtdServices.dispose();

    _layoutType.dispose();
    _filterBySelectedFile.dispose();
    _searchQuery.dispose();
    for (final searchField in _searchFields) {
      searchField.dispose();
    }
  }

  void onHotReload() => _updateFilteredPreviewSet();

  final WidgetPreviewScaffoldDtdServices dtdServices;

  final PreviewsCallback _previews;

  late final path.Context context;

  ValueListenable<LayoutType> get layoutTypeListenable => _layoutType;
  final _layoutType = ValueNotifier<LayoutType>(LayoutType.gridView);

  LayoutType get layoutType => _layoutType.value;
  set layoutType(LayoutType type) => _layoutType.value = type;

  ValueListenable<bool> get editorServiceAvailable =>
      dtdServices.editorServiceAvailable;

  late final Uri devToolsUri;

  ValueListenable<bool> get filterBySelectedFileListenable =>
      _filterBySelectedFile;
  final _filterBySelectedFile = ValueNotifier<bool>(true);

  Future<void> toggleFilterBySelectedFile() async {
    final updated = !_filterBySelectedFile.value;
    await dtdServices.setPreference(kFilterBySelectedFilePreference, updated);
    _filterBySelectedFile.value = updated;
  }

  ValueListenable<String> get searchQueryListenable => _searchQuery;
  final _searchQuery = ValueNotifier<String>('');

  void updateSearchQuery(String query) => _searchQuery.value = query;

  ValueListenable<bool> get searchByGroupNameListenable => _searchByGroupName;
  final _searchByGroupName = ValueNotifier<bool>(true);

  ValueListenable<bool> get searchByPreviewNameListenable =>
      _searchByPreviewName;
  final _searchByPreviewName = ValueNotifier<bool>(true);

  ValueListenable<bool> get searchByContainingScriptListenable =>
      _searchByContainingScript;
  final _searchByContainingScript = ValueNotifier<bool>(true);

  ValueListenable<bool> get searchByContainingPackageListenable =>
      _searchByContainingPackage;
  final _searchByContainingPackage = ValueNotifier<bool>(true);

  bool toggleSearchByGroupName() => _toggleSearchField(_searchByGroupName);

  bool toggleSearchByPreviewName() => _toggleSearchField(_searchByPreviewName);

  bool toggleSearchByContainingScript() =>
      _toggleSearchField(_searchByContainingScript);

  bool toggleSearchByContainingPackage() =>
      _toggleSearchField(_searchByContainingPackage);

  ValueListenable<bool> get widgetInspectorVisible => _widgetInspectorVisible;
  final _widgetInspectorVisible = ValueNotifier<bool>(false);

  void toggleWidgetInspectorVisible() =>
      _widgetInspectorVisible.value = !_widgetInspectorVisible.value;

  ValueListenable<WidgetPreviewGroups> get filteredPreviewSetListenable =>
      _filteredPreviewSet;
  final _filteredPreviewSet = ValueNotifier<WidgetPreviewGroups>([]);

  void _registerListeners() {
    dtdServices.selectedSourceFile.addListener(_updateFilteredPreviewSet);
    editorServiceAvailable.addListener(
      () => _updateFilteredPreviewSet(editorServiceAvailabilityUpdated: true),
    );
    filterBySelectedFileListenable.addListener(_updateFilteredPreviewSet);
    searchQueryListenable.addListener(_updateFilteredPreviewSet);
    for (final searchField in _searchFields) {
      searchField.addListener(_updateFilteredPreviewSet);
    }
    _updateFilteredPreviewSet();
  }

  late final _searchFields = <ValueNotifier<bool>>[
    _searchByGroupName,
    _searchByPreviewName,
    _searchByContainingScript,
    _searchByContainingPackage,
  ];

  String _getSearchableValue(
    WidgetPreview preview,
    ValueNotifier<bool> searchField,
  ) {
    if (identical(searchField, _searchByGroupName)) {
      return preview.previewData.group.toLowerCase();
    }
    if (identical(searchField, _searchByPreviewName)) {
      return (preview.name ?? '').toLowerCase();
    }
    if (identical(searchField, _searchByContainingScript)) {
      return preview.scriptUri.toLowerCase();
    }
    if (identical(searchField, _searchByContainingPackage)) {
      return preview.packageName.toLowerCase();
    }

    throw StateError('Unknown search field');
  }

  bool _toggleSearchField(ValueNotifier<bool> searchField) {
    if (searchField.value && !_hasAnotherActiveSearchField(searchField)) {
      return false;
    }
    searchField.value = !searchField.value;
    return true;
  }

  bool _hasAnotherActiveSearchField(ValueNotifier<bool> activeSearchField) =>
      _searchFields.any(
        (field) => !identical(field, activeSearchField) && field.value,
      );

  bool _matchesSearchFilter(WidgetPreview preview, String searchQuery) {
    if (searchQuery.isEmpty) {
      return true;
    }

    for (final searchField in _searchFields) {
      if (!searchField.value) {
        continue;
      }
      if (_getSearchableValue(preview, searchField).contains(searchQuery)) {
        return true;
      }
    }

    return false;
  }

  void _updateFilteredPreviewSet({
    bool editorServiceAvailabilityUpdated = false,
  }) {
    final previews = _previews();

    final normalizedSearchQuery = _searchQuery.value.trim().toLowerCase();
    String? selectedSourcePath;

    if (editorServiceAvailable.value && _filterBySelectedFile.value) {
      final selectedSourceFile = dtdServices.selectedSourceFile.value;
      if (editorServiceAvailabilityUpdated && selectedSourceFile == null) {
        _filteredPreviewSet.value = [];
        return;
      }
      if (selectedSourceFile == null) {
        return;
      }
      selectedSourcePath = context.fromUri(selectedSourceFile.uriAsString);
    }

    final previewGroups = <String, WidgetPreviewGroup>{};
    for (final preview in previews) {
      if (selectedSourcePath != null &&
          !context.equals(
            context.fromUri(preview.scriptUri),
            selectedSourcePath,
          )) {
        continue;
      }
      if (!_matchesSearchFilter(preview, normalizedSearchQuery)) {
        continue;
      }

      final group = preview.previewData.group;
      previewGroups
          .putIfAbsent(
            group,
            () => WidgetPreviewGroup(name: group, previews: []),
          )
          .previews
          .add(preview);
    }
    _filteredPreviewSet.value = previewGroups.values.toList();
  }
}
