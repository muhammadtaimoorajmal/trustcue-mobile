import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/reports/domain/models/cloud_sync_models.dart';

/// Typed HTTP API client for Module 39 Cloud Report Synchronization.
///
/// Invariants:
/// - Authenticates strictly via user JWT Bearer token supplied by [tokenProvider].
/// - Fails closed to typed [AnalysisFailure] errors.
/// - Handles 403 sync_opt_in_required gracefully.
class SyncApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() tokenProvider;
  final Duration timeout;

  SyncApiClient({
    String? baseUrl,
    http.Client? httpClient,
    required this.tokenProvider,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
       _httpClient = httpClient ?? http.Client();

  static String _resolveDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    if (envUrl.trim().isNotEmpty) {
      return envUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    if (kReleaseMode) {
      return 'https://api.trustcue.app';
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Batch uploads report summaries and tombstones to cloud sync.
  Future<Result<SyncPushResult>> pushReports(
    List<CloudReportItem> reports,
  ) async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to synchronize reports.',
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/sync/reports');
      final body = jsonEncode({
        'reports': reports.map((r) => r.toJson()).toList(),
      });

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.success(SyncPushResult.fromJson(decoded));
      }

      if (response.statusCode == 401) {
        return const Result.failure(
          AnalysisFailure.unauthorized(
            'Session expired or invalid. Please sign in again.',
          ),
        );
      }

      if (response.statusCode == 403) {
        return const Result.failure(
          AnalysisFailure.storage(
            'Cloud sync is disabled in your account settings. Enable sync to back up reports.',
          ),
        );
      }

      return Result.failure(
        AnalysisFailure.unavailable(
          'Cloud sync upload failed: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Cloud sync timed out. Please check your connection.',
        ),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error during cloud sync upload: $e',
        ),
      );
    }
  }

  /// Retrieves report summaries updated after [since].
  Future<Result<SyncPullResult>> pullReports({
    DateTime? since,
    int limit = 50,
    String? cursor,
  }) async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to retrieve synced reports.',
        ),
      );
    }

    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (since != null) {
        queryParams['since'] = since.toUtc().toIso8601String();
      }
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final uri = Uri.parse('$baseUrl/api/v1/sync/reports')
          .replace(queryParameters: queryParams);

      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.success(SyncPullResult.fromJson(decoded));
      }

      if (response.statusCode == 401) {
        return const Result.failure(
          AnalysisFailure.unauthorized(
            'Session expired or invalid. Please sign in again.',
          ),
        );
      }

      if (response.statusCode == 403) {
        return const Result.failure(
          AnalysisFailure.storage(
            'Cloud sync is disabled in your account settings.',
          ),
        );
      }

      return Result.failure(
        AnalysisFailure.unavailable(
          'Cloud sync download failed: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Cloud sync timed out. Please check your connection.',
        ),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error during cloud sync download: $e',
        ),
      );
    }
  }

  /// Purges all cloud synced reports for the authenticated account.
  Future<Result<SyncPurgeResult>> purgeSyncedReports() async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to purge cloud backups.',
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/sync/reports');
      final response = await _httpClient
          .delete(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.success(SyncPurgeResult.fromJson(decoded));
      }

      if (response.statusCode == 401) {
        return const Result.failure(
          AnalysisFailure.unauthorized(
            'Session expired or invalid. Please sign in again.',
          ),
        );
      }

      return Result.failure(
        AnalysisFailure.unavailable(
          'Cloud backup purge failed: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout('Cloud backup purge timed out.'),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error during cloud backup purge: $e',
        ),
      );
    }
  }
}
