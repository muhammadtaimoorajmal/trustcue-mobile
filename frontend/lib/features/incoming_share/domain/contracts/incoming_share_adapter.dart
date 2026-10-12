import 'dart:async';

import '../models/incoming_share_payload.dart';

/// Contract abstracting the platform-level incoming share receiver.
abstract class IncomingShareAdapter {
  /// Fetches any initial share delivered when the application was launched cold.
  Future<IncomingSharePayload?> getInitialShare();

  /// Stream of new shares delivered while the application is already running.
  Stream<IncomingSharePayload> get shareStream;

  /// Informs the native receiver that the event has been handled and can be cleared from memory.
  Future<bool> consumeShare(String eventId);

  /// Requests the native receiver to clean up a staged temporary file.
  Future<bool> cleanStagedFile(String filePath);

  /// Disposes of any active listeners or streams.
  void dispose();
}
