
import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';

extension WidgetPreviewScaffoldDtdUtils on DartToolingDaemon {
  Future<void> safeStreamListen(String streamId) async {
    try {
      await streamListen(streamId);
    } on RpcException catch (e) {
      if (e.code != RpcErrorCodes.kStreamAlreadySubscribed) {
        rethrow;
      }
    }
  }

  Future<DTDResponse?> safeCall(
    String? serviceName,
    String methodName, {
    Map<String, Object?>? params,
  }) async {
    try {
      return await call(serviceName, methodName, params: params);
    } on RpcException catch (e) {
      if (e.code != RpcErrorCodes.kMethodNotFound &&
          e.code != RpcErrorCodes.kServiceDisappeared) {
        rethrow;
      }
      return null;
    }
  }
}
