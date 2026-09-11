
import 'dart:async';

import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:widget_preview_scaffold/src/dtd/dtd_connection_info.dart';
import 'package:widget_preview_scaffold/src/dtd/editor_service.dart';
import 'package:widget_preview_scaffold/src/dtd/utils.dart';

class WidgetPreviewScaffoldDtdServices with DtdEditorService {

  static const kIsWindows = 'isWindows';
  static const kHotRestartPreviewer = 'hotRestartPreviewer';
  static const kResolveUri = 'resolveUri';
  static const kSetPreference = 'setPreference';
  static const kGetPreference = 'getPreference';
  static const kGetDevToolsUri = 'getDevToolsUri';

  static const kNoValueForKey = 200;


  Future<void> connect({Uri? dtdUri}) async {
    final Uri dtdWsUri = dtdUri ?? Uri.parse(kWidgetPreviewDtdUri);
    dtd = await DartToolingDaemon.connect(dtdWsUri);
    unawaited(
      dtd.postEvent(
        kWidgetPreviewScaffoldStream,
        'Connected',
        const <String, Object?>{},
      ),
    );
    await _determineIfWindows();
    await initializeEditorService(this);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await dtd.close();
  }

  Future<DTDResponse?> _call(
    String methodName, {
    Map<String, Object?>? params,
  }) => dtd.safeCall(kWidgetPreviewService, methodName, params: params);

  late final bool isWindows;

  Future<void> _determineIfWindows() async {
    isWindows = (BoolResponse.fromDTDResponse(
      (await _call(kIsWindows))!,
    )).value!;
  }

  Future<void> hotRestartPreviewer() => _call(kHotRestartPreviewer);

  Future<Uri?> resolveUri(Uri uri) async {
    final response = await _call(kResolveUri, params: {'uri': uri.toString()});
    if (response == null) {
      return null;
    }
    final result = StringResponse.fromDTDResponse(response).value;
    return result == null ? null : Uri.parse(result);
  }

  Future<Object?> getPreference(String key) async {
    try {
      final response = await _call(kGetPreference, params: {'key': key});
      return switch (response?.type) {
        'StringResponse' => StringResponse.fromDTDResponse(response!).value,
        'BoolResponse' => BoolResponse.fromDTDResponse(response!).value,
        _ => throw StateError('Unexpected response type: ${response?.type}'),
      };
    } on RpcException catch (e) {
      if (e.code == kNoValueForKey) {
        return null;
      }
      rethrow;
    }
  }

  Future<bool> getFlag(String key, {bool defaultValue = false}) async {
    final result = await getPreference(key) as bool?;
    return result ?? defaultValue;
  }

  Future<void> setPreference(String key, Object? value) async {
    await _call(kSetPreference, params: {'key': key, 'value': value});
  }

  Future<Uri> getDevToolsUri() async {
    final result = StringResponse.fromDTDResponse(
      (await _call(kGetDevToolsUri))!,
    );
    return Uri.parse(result.value!);
  }

  @override
  late final DartToolingDaemon dtd;
}
