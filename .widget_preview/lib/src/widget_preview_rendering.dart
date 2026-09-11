
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';

import 'package:stack_trace/stack_trace.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:widget_preview_scaffold/src/dtd/editor_service.dart';
import 'package:widget_preview_scaffold/src/split.dart';
import 'package:widget_preview_scaffold/src/theme/ide_theme.dart';
import 'package:widget_preview_scaffold/src/theme/theme.dart';

import 'package:widget_preview_scaffold/src/controls.dart';
import 'package:widget_preview_scaffold/src/generated_preview.dart';
import 'package:widget_preview_scaffold/src/utils.dart';
import 'package:widget_preview_scaffold/src/widget_preview.dart';
import 'package:widget_preview_scaffold/src/widget_preview_inspector_service.dart';
import 'package:widget_preview_scaffold/src/widget_preview_scaffold_controller.dart';

class WidgetPreviewErrorWidget extends StatelessWidget {
  WidgetPreviewErrorWidget({
    super.key,
    required this.controller,
    required this.error,
    required StackTrace stackTrace,
    required this.size,
  }) : trace = Trace.from(stackTrace).terse;

  final WidgetPreviewScaffoldController controller;

  final Object error;

  final Trace trace;

  final Size size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: size.height,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Failed to initialize widget tree: ',
                    style: theme.boldTextStyle,
                  ),
                  TextSpan(text: error.toString(), style: theme.fixedFontStyle),
                ],
              ),
            ),
            Text('Stacktrace:', style: theme.boldTextStyle),
            ValueListenableBuilder(
              valueListenable: controller.editorServiceAvailable,
              builder: (context, editorServiceAvailable, child) {
                return SelectableText.rich(
                  TextSpan(
                    children: _formatFrames(
                      theme,
                      trace.frames,
                      editorServiceAvailable,
                    ),
                    style: theme.fixedFontStyle,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _formatFrames(
    ThemeData theme,
    List<Frame> frames,
    bool editorServiceAvailable,
  ) {
    final int longest = frames
        .map((frame) => frame.location.length)
        .fold(0, math.max);

    return frames.map<TextSpan>((frame) {
      if (frame is UnparsedFrame) return TextSpan(text: '$frame\n');
      final isLinkable =
          (frame.uri.isScheme('file') || frame.uri.isScheme('package')) &&
          editorServiceAvailable;
      final style = isLinkable
          ? theme.fixedFontLinkStyle
          : theme.fixedFontStyle;
      return TextSpan(
        children: [
          TextSpan(
            text: frame.location,
            style: style,
            recognizer: isLinkable
                ? (TapGestureRecognizer()
                    ..onTap = () async {
                      final resolvedUri = await controller.dtdServices
                          .resolveUri(frame.uri);
                      controller.dtdServices.navigateToCode(
                        CodeLocation(
                          uri: resolvedUri.toString(),
                          line: frame.line,
                          column: frame.column,
                        ),
                      );
                    })
                : null,
          ),
          TextSpan(text: ' ' * (longest - frame.location.length)),
          const TextSpan(text: '  '),
          TextSpan(text: '${frame.member}\n', style: style),
        ],
      );
    }).toList();
  }
}

class NoPreviewsDetectedWidget extends StatelessWidget {
  const NoPreviewsDetectedWidget({super.key});

  static Uri documentationUrl = Uri.https('flutter.dev', 'to/widget-previews');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Text('No previews detected', style: theme.boldTextStyle),
          const VerticalSpacer(),
          Text('Read more about getting started with widget previews at:'),
          Text.rich(
            TextSpan(
              text: documentationUrl.toString(),
              style: theme.linkTextStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  launchUrl(documentationUrl);
                },
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewWidget extends StatelessWidget {
  const PreviewWidget({super.key, required this.preview, required this.child});

  final WidgetPreview preview;
  final Widget child;

  @override
  StatelessElement createElement() => PreviewWidgetElement(this);

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  String toStringShort() {
    final StringBuffer buffer = StringBuffer(
      '@${preview.previewData.runtimeType}',
    );
    if (preview.name != null) {
      buffer.write('(name: "${preview.name}")');
    }
    return buffer.toString();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    preview.debugFillProperties(properties);
  }
}

class PreviewWidgetElement extends StatelessElement {
  PreviewWidgetElement(super.widget);
}

class WidgetPreviewGroupWidget extends StatelessWidget {
  const WidgetPreviewGroupWidget({
    super.key,
    required this.controller,
    required this.group,
  });

  final WidgetPreviewScaffoldController controller;
  final WidgetPreviewGroup group;

  static const _gridSpacing = 8.0;
  static const _gridRunSpacing = 8.0;

  static const _kCardRadius = Radius.circular(12);

  Widget _buildGridViewFlex(List<WidgetPreview> previews) {
    return Wrap(
      spacing: WidgetPreviewGroupWidget._gridSpacing,
      runSpacing: WidgetPreviewGroupWidget._gridRunSpacing,
      alignment: WrapAlignment.start,
      children: [
        for (final WidgetPreview preview in previews)
          WidgetPreviewWidget(controller: controller, preview: preview),
      ],
    );
  }

  Widget _buildVerticalListView(List<WidgetPreview> previews) {
    return Column(
      children: [
        for (final preview in previews)
          Center(
            child: WidgetPreviewWidget(
              controller: controller,
              preview: preview,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_kCardRadius),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey(group.name),
            title: Text(group.name),
            initiallyExpanded: true,
            children: [
              ValueListenableBuilder<LayoutType>(
                valueListenable: controller.layoutTypeListenable,
                builder: (context, selectedLayout, _) {
                  return switch (selectedLayout) {
                    LayoutType.gridView => _buildGridViewFlex(group.previews),
                    LayoutType.listView => _buildVerticalListView(
                      group.previews,
                    ),
                  };
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WidgetPreviewWidget extends StatefulWidget {
  const WidgetPreviewWidget({
    super.key,
    required this.preview,
    required this.controller,
  });

  final WidgetPreview preview;

  final WidgetPreviewScaffoldController controller;

  @override
  State<WidgetPreviewWidget> createState() => WidgetPreviewWidgetState();
}

class WidgetPreviewWidgetState extends State<WidgetPreviewWidget> {
  final transformationController = TransformationController();

  late final brightnessListenable = ValueNotifier<Brightness>(
    widget.preview.brightness ?? MediaQuery.platformBrightnessOf(context),
  );

  final softRestartListenable = ValueNotifier<bool>(false);
  final key = GlobalKey();

  Size get lastChildSize =>
      (key.currentContext!.findRenderObject() as RenderBox).size;

  @override
  void didUpdateWidget(WidgetPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousBrightness = oldWidget.preview.brightness;
    final newBrightness = widget.preview.brightness;
    final currentBrightness = brightnessListenable.value;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);

    if (previousBrightness == null && newBrightness != null) {
      if (currentBrightness == systemBrightness) {
        brightnessListenable.value = newBrightness;
      }
    }
    else if (previousBrightness != null) {
      if (currentBrightness == previousBrightness) {
        brightnessListenable.value = newBrightness ?? systemBrightness;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewerConstraints =
        WidgetPreviewerWindowConstraints.getRootConstraints(context);

    final maxSizeConstraints = previewerConstraints.copyWith(
      minHeight: previewerConstraints.maxHeight / 2.0,
      maxHeight: previewerConstraints.maxHeight / 2.0,
    );

    bool errorThrownDuringTreeConstruction = false;

    Widget preview = ValueListenableBuilder<bool>(
      valueListenable: softRestartListenable,
      builder: (context, performRestart, _) {
        try {
          final previewWidget = Container(
            key: key,
            child: WidgetPreviewTheming(
              theme: widget.preview.theme,
              child: EnableWidgetInspectorScope(
                child: PreviewWidget(
                  preview: widget.preview,
                  child: widget.preview.previewBuilder(),
                ),
              ),
            ),
          );
          if (performRestart) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              softRestartListenable.value = false;
            }, debugLabel: 'Soft Restart');
            return SizedBox.fromSize(size: lastChildSize);
          }
          return previewWidget;
        } on Object catch (error, stackTrace) {
          errorThrownDuringTreeConstruction = true;
          return WidgetPreviewErrorWidget(
            controller: widget.controller,
            error: error,
            stackTrace: stackTrace,
            size: maxSizeConstraints.biggest,
          );
        }
      },
    );

    final Size? size = widget.preview.size;

    preview = ValueListenableBuilder(
      valueListenable:
          WidgetsBinding.instance.debugShowWidgetInspectorOverrideNotifier,
      builder: (context, enableWidgetInspector, child) {
        if (child is WidgetPreviewErrorWidget) {
          return child;
        }
        if (enableWidgetInspector) {
          return WidgetInspector(

            exitWidgetSelectionButtonBuilder: null,
            moveExitWidgetSelectionButtonBuilder: null,
            tapBehaviorButtonBuilder: null,
            child: child!,
          );
        }
        return child!;
      },
      child: _WidgetPreviewWrapper(
        previewerConstraints: maxSizeConstraints,
        child: SizedBox(
          width: size?.width == double.infinity ? null : size?.width,
          height: size?.height == double.infinity ? null : size?.height,
          child: preview,
        ),
      ),
    );

    preview = WidgetPreviewMediaQueryOverride(
      preview: widget.preview,
      brightnessListenable: brightnessListenable,
      child: preview,
    );

    preview = WidgetPreviewLocalizations(
      localizationsData: widget.preview.localizations,
      child: preview,
    );

    preview = DefaultAssetBundle(
      bundle: PreviewAssetBundle(packageName: widget.preview.packageName),
      child: preview,
    );

    final hasName = widget.preview.name != null;
    preview = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasName)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.preview.name!,
              style: fixBlurryText(
                TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ).add(hasName ? const EdgeInsets.only(top: 8.0) : EdgeInsets.zero),
          decoration: hasName
              ? BoxDecoration(
                  border: Border(top: Divider.createBorderSide(context)),
                )
              : null,
          child: Column(
            children: [
              ZoomablePreviewArea(
                transformationController: transformationController,
                errorThrownDuringTreeConstruction:
                    errorThrownDuringTreeConstruction,
                child: preview,
              ),
              const VerticalSpacer(),
              Builder(
                builder: (context) {
                  return _WidgetPreviewControlRow(
                    transformationController: transformationController,
                    errorThrownDuringTreeConstruction:
                        errorThrownDuringTreeConstruction,
                    brightnessListenable: brightnessListenable,
                    softRestartListenable: softRestartListenable,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: preview,
        ),
      ),
    );
  }
}

class _WidgetPreviewControlRow extends StatelessWidget {
  const _WidgetPreviewControlRow({
    required this.transformationController,
    required this.errorThrownDuringTreeConstruction,
    required this.brightnessListenable,
    required this.softRestartListenable,
  });

  final TransformationController transformationController;
  final bool errorThrownDuringTreeConstruction;
  final ValueNotifier<Brightness> brightnessListenable;
  final ValueNotifier<bool> softRestartListenable;

  @override
  Widget build(BuildContext context) {
    if (errorThrownDuringTreeConstruction) {
      return Container();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZoomControls(transformationController: transformationController),
        const SizedBox(width: 30),
        BrightnessToggleButton(brightnessListenable: brightnessListenable),
        const SizedBox(width: 10),
        SoftRestartButton(softRestartListenable: softRestartListenable),
      ],
    );
  }
}

class WidgetPreviewTheming extends StatelessWidget {
  const WidgetPreviewTheming({
    super.key,
    required this.theme,
    required this.child,
  });

  final Widget child;

  final PreviewThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final themeData = theme;
    if (themeData == null) {
      return child;
    }
    return themeData.apply(context, child);
  }
}

class WidgetPreviewMediaQueryOverride extends StatelessWidget {
  const WidgetPreviewMediaQueryOverride({
    super.key,
    required this.preview,
    required this.brightnessListenable,
    required this.child,
  });

  final WidgetPreview preview;

  final ValueListenable<Brightness> brightnessListenable;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness>(
      valueListenable: brightnessListenable,
      builder: (context, brightness, _) {
        return MediaQuery(
          data: _buildMediaQueryOverride(
            context: context,
            brightness: brightness,
          ),
          child: child,
        );
      },
    );
  }

  MediaQueryData _buildMediaQueryOverride({
    required BuildContext context,
    required Brightness brightness,
  }) {
    var mediaQueryData = MediaQuery.of(
      context,
    ).copyWith(platformBrightness: brightness);

    if (preview.textScaleFactor != null) {
      mediaQueryData = mediaQueryData.copyWith(
        textScaler: TextScaler.linear(preview.textScaleFactor!),
      );
    }

    var size = Size(
      preview.size?.width ?? mediaQueryData.size.width,
      preview.size?.height ?? mediaQueryData.size.height,
    );

    if (preview.size != null) {
      mediaQueryData = mediaQueryData.copyWith(size: size);
    }

    return mediaQueryData;
  }
}

class WidgetPreviewLocalizations extends StatefulWidget {
  const WidgetPreviewLocalizations({
    super.key,
    required this.localizationsData,
    required this.child,
  });

  final PreviewLocalizationsData? localizationsData;
  final Widget child;

  @override
  State<WidgetPreviewLocalizations> createState() =>
      _WidgetPreviewLocalizationsState();
}

class _WidgetPreviewLocalizationsState
    extends State<WidgetPreviewLocalizations> {
  PreviewLocalizationsData get _localizationsData => widget.localizationsData!;
  late final LocalizationsResolver _localizationsResolver =
      LocalizationsResolver(
        supportedLocales: _localizationsData.supportedLocales,
        locale: _localizationsData.locale,
        localeListResolutionCallback:
            _localizationsData.localeListResolutionCallback,
        localeResolutionCallback: _localizationsData.localeResolutionCallback,
        localizationsDelegates: _localizationsData.localizationsDelegates,
      );

  @override
  void didUpdateWidget(WidgetPreviewLocalizations oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PreviewLocalizationsData? localizationsData =
        widget.localizationsData;
    if (localizationsData == null) {
      return;
    }
    _localizationsResolver.update(
      supportedLocales: localizationsData.supportedLocales,
      locale: localizationsData.locale,
      localeListResolutionCallback:
          localizationsData.localeListResolutionCallback,
      localeResolutionCallback: localizationsData.localeResolutionCallback,
      localizationsDelegates: localizationsData.localizationsDelegates,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.localizationsData == null) {
      return widget.child;
    }
    return ListenableBuilder(
      listenable: _localizationsResolver,
      builder: (context, _) {
        return Localizations(
          locale: _localizationsResolver.locale,
          delegates: _localizationsResolver.localizationsDelegates.toList(),
          child: widget.child,
        );
      },
    );
  }
}

class WidgetPreviewerWindowConstraints extends InheritedWidget {
  const WidgetPreviewerWindowConstraints({
    super.key,
    required super.child,
    required this.constraints,
  });

  final BoxConstraints constraints;

  static BoxConstraints getRootConstraints(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<WidgetPreviewerWindowConstraints>();
    assert(
      result != null,
      'No WidgetPreviewerWindowConstraints founds in context',
    );
    return result!.constraints;
  }

  @override
  bool updateShouldNotify(WidgetPreviewerWindowConstraints oldWidget) {
    return oldWidget.constraints != constraints;
  }
}

class ZoomablePreviewArea extends StatelessWidget {
  const ZoomablePreviewArea({
    super.key,
    required this.child,
    required this.transformationController,
    required this.errorThrownDuringTreeConstruction,
  });

  final Widget child;
  final TransformationController transformationController;
  final bool errorThrownDuringTreeConstruction;

  @override
  Widget build(BuildContext context) {
    if (errorThrownDuringTreeConstruction) {
      return child;
    }
    return ListenableBuilder(
      listenable: transformationController,
      builder: (context, _) {
        final double scale = transformationController.value.entry(0, 0);
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _ScaledLayoutWrapper(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _ScaledLayoutWrapper extends SingleChildRenderObjectWidget {
  const _ScaledLayoutWrapper({super.child, required this.scale});

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _ScaledLayoutRenderObject(scale: scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _ScaledLayoutRenderObject renderObject,
  ) {
    renderObject.scale = scale;
  }
}

class _ScaledLayoutRenderObject extends RenderShiftedBox {
  _ScaledLayoutRenderObject({required this._scale, RenderBox? child})
    : super(child);

  double _scale;
  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) {
      return;
    }
    _scale = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    return child!.getMinIntrinsicWidth(height / scale) * scale;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    return child!.getMaxIntrinsicWidth(height / scale) * scale;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    return child!.getMinIntrinsicHeight(width / scale) * scale;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    return child!.getMaxIntrinsicHeight(width / scale) * scale;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child.size * scale);

    final BoxParentData childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    if (scale == 1.0) {
      super.paint(context, offset);
      layer = null;
      return;
    }
    final Matrix4 transform = Matrix4.diagonal3Values(scale, scale, 1.0);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (scale != 1.0) {
      transform.scaleByDouble(scale, scale, 1.0, 1.0);
    }
    super.applyPaintTransform(child, transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) {
      return false;
    }
    final Matrix4 transform = Matrix4.diagonal3Values(scale, scale, 1.0);
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }
}

class _WidgetPreviewWrapper extends SingleChildRenderObjectWidget {
  const _WidgetPreviewWrapper({
    super.child,
    required this.previewerConstraints,
  });

  final BoxConstraints previewerConstraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _WidgetPreviewWrapperBox(
      previewerConstraints: previewerConstraints,
      child: null,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _WidgetPreviewWrapperBox renderObject,
  ) {
    renderObject.setPreviewerConstraints(previewerConstraints);
  }
}

class _WidgetPreviewWrapperBox extends RenderShiftedBox {
  _WidgetPreviewWrapperBox({
    required RenderBox? child,
    required this._previewerConstraints,
  }) : super(child);

  BoxConstraints _constraintOverride = const BoxConstraints();
  BoxConstraints _previewerConstraints;

  void setPreviewerConstraints(BoxConstraints previewerConstraints) {
    if (_previewerConstraints == previewerConstraints) {
      return;
    }
    _previewerConstraints = previewerConstraints;
    markNeedsLayout();
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    if (child != null && constraints is BoxConstraints) {
      double minInstrinsicHeight;
      try {
        minInstrinsicHeight = child!.getMinIntrinsicHeight(
          constraints.maxWidth,
        );
      } on Object {
        minInstrinsicHeight = 0.0;
      }
      _constraintOverride = minInstrinsicHeight == 0
          ? _previewerConstraints
          : const BoxConstraints();
    }
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    final updatedConstraints = _constraintOverride.enforce(constraints);
    child.layout(updatedConstraints, parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

class PreviewAssetBundle extends PlatformAssetBundle {
  PreviewAssetBundle({required this.packageName});

  final String packageName;

  static const String _kPackagesPrefix = 'packages';

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin' ||
        key == 'AssetManifest.bin.json' ||
        key == 'FontManifest.json' ||
        key.startsWith(_kPackagesPrefix)) {
      return super.load(key);
    }
    return super.load(_toPackagePath(key));
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    if (kIsWeb) {
      final ByteData bytes = await load(key);
      return ImmutableBuffer.fromUint8List(Uint8List.sublistView(bytes));
    }
    return await ImmutableBuffer.fromAsset(
      key.startsWith(_kPackagesPrefix) ? key : _toPackagePath(key),
    );
  }

  String _toPackagePath(String key) => '$_kPackagesPrefix/$packageName/$key';
}

Future<void> mainImpl() async {
  final controller = WidgetPreviewScaffoldController(previews: previews);
  await controller.initialize();
  WidgetPreviewScaffoldInspectorService(dtdServices: controller.dtdServices);
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  binding.debugExcludeRootWidgetInspector = true;
  runWidget(
    DisableWidgetInspectorScope(
      child: binding.wrapWithDefaultView(
        HotReloadListener(
          onHotReload: controller.onHotReload,
          child: WidgetPreviewScaffold(
            controller: controller,
            ideTheme: getIdeTheme(),
          ),
        ),
      ),
    ),
  );
}

class WidgetPreviewScaffold extends StatefulWidget {
  const WidgetPreviewScaffold({
    super.key,
    required this.controller,
    this.ideTheme = const IdeTheme(),
    this.enableWebView = true,
  });

  final WidgetPreviewScaffoldController controller;
  final IdeTheme ideTheme;
  final bool enableWebView;

  @override
  State<WidgetPreviewScaffold> createState() => _WidgetPreviewScaffoldState();
}

class _WidgetPreviewScaffoldState extends State<WidgetPreviewScaffold> {
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    if (widget.enableWebView) {
      _webViewController = WebViewController()
        ..loadRequest(widget.controller.devToolsUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: widget.ideTheme,
        theme: ThemeData(),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: widget.ideTheme,
        theme: ThemeData.dark(),
      ),
      themeMode: widget.ideTheme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Material(
        child: OutlineDecoration.onlyTop(
          child: ValueListenableBuilder(
            valueListenable: widget.controller.widgetInspectorVisible,
            builder: (context, widgetInspectorVisible, previewView) {
              if (!widgetInspectorVisible) {
                return previewView!;
              }
              return SplitPane(
                axis: Axis.horizontal,
                initialFractions: const [0.7, 0.3],
                children: [
                  OutlineDecoration.onlyRight(child: previewView!),
                  OutlineDecoration.onlyLeft(
                    child: widget.enableWebView
                        ? WebViewWidget(controller: _webViewController!)
                        : Container(),
                  ),
                ],
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: WidgetPreviews(controller: widget.controller),
                  ),
                ),
                WidgetPreviewControls(controller: widget.controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WidgetPreviewControls extends StatelessWidget {
  const WidgetPreviewControls({super.key, required this.controller});

  static const _controlsPadding = 20.0;
  final WidgetPreviewScaffoldController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: _controlsPadding,
        left: _controlsPadding,
        right: _controlsPadding,
      ),
      child: Row(
        children: [
          LayoutTypeSelector(controller: controller),
          ValueListenableBuilder(
            valueListenable: controller.editorServiceAvailable,
            builder: (context, editorServiceAvailable, _) {
              if (!editorServiceAvailable) {
                return Container();
              }
              return Row(
                children: [
                  HorizontalSpacer(),
                  FilterBySelectedFileToggle(controller: controller),
                ],
              );
            },
          ),
          HorizontalSpacer(),
          Expanded(child: PreviewSearchControls(controller: controller)),
          HorizontalSpacer(),
          WidgetInspectorToggle(controller: controller),
          Spacer(),
          WidgetPreviewerRestartButton(controller: controller),
        ],
      ),
    );
  }
}

class WidgetPreviews extends StatelessWidget {
  const WidgetPreviews({super.key, required this.controller});

  final WidgetPreviewScaffoldController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WidgetPreviewGroups>(
      valueListenable: controller.filteredPreviewSetListenable,
      builder: (context, previewGroups, _) {
        if (previewGroups.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [NoPreviewsDetectedWidget()],
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final previewGroupsList = previewGroups.toList();
            return WidgetPreviewerWindowConstraints(
              constraints: constraints,
              child: ListView.builder(
                itemCount: previewGroups.length,
                itemBuilder: (context, index) {
                  return WidgetPreviewGroupWidget(
                    controller: controller,
                    group: previewGroupsList[index],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
