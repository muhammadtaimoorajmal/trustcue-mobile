import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';

/// Production implementation of [IncomingShareAdapter] using Flutter's [MethodChannel].
class DefaultIncomingShareAdapter implements IncomingShareAdapter {
  DefaultIncomingShareAdapter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('trustcue/incoming_share') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<IncomingSharePayload> _streamController =
      StreamController<IncomingSharePayload>.broadcast();

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onShareReceived') {
      if (call.arguments is Map) {
        final payload = IncomingSharePayload.fromMap(
          call.arguments as Map<dynamic, dynamic>,
        );
        _streamController.add(payload);
      }
    }
  }

  @override
  Future<IncomingSharePayload?> getInitialShare() async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialShare',
      );
      if (result != null) {
        return IncomingSharePayload.fromMap(result);
      }
    } on MissingPluginException {
      // In unit test or non-Android environment
      return null;
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Stream<IncomingSharePayload> get shareStream => _streamController.stream;

  @override
  Future<bool> consumeShare(String eventId) async {
    if (!Platform.isAndroid) return true;
    try {
      final success = await _channel.invokeMethod<bool>('consumeShare', {
        'eventId': eventId,
      });
      return success ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> cleanStagedFile(String filePath) async {
    if (!Platform.isAndroid) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    }
    try {
      final success = await _channel.invokeMethod<bool>('cleanStagedFile', {
        'filePath': filePath,
      });
      return success ?? true;
    } on MissingPluginException {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _streamController.close();
  }
}
