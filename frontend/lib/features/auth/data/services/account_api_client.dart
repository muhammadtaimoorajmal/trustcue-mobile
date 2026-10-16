import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';

/// Typed HTTP API client for TrustCue's account profile and lifecycle endpoints.
///
/// Invariants & Security Boundaries:
/// - Never includes or handles administrative service-role keys.
/// - Authenticates strictly via user JWT Bearer token supplied by [tokenProvider].
/// - Enforces bounded timeouts and fails safely to typed [AnalysisFailure] errors.
class AccountApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() tokenProvider;
  final Duration timeout;

  AccountApiClient({
    String? baseUrl,
    http.Client? httpClient,
    required this.tokenProvider,
    this.timeout = const Duration(seconds: 10),
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

  /// Retrieves user profile metadata for the authenticated session.
  Future<Result<UserProfile>> getProfile() async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to access profile.',
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/account/profile');
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
        return Result.success(UserProfile.fromJson(decoded));
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
          'Failed to retrieve profile: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Profile retrieval timed out. Please check your connection.',
        ),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable(
          'Unexpected profile retrieval error: ${e.toString()}',
        ),
      );
    }
  }

  /// Updates profile display name and/or cloud sync preference for the authenticated session.
  Future<Result<UserProfile>> updateProfile({
    String? displayName,
    bool? syncEnabled,
  }) async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to update profile.',
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/account/profile');
      final payload = <String, dynamic>{};
      if (displayName != null) {
        payload['displayName'] = displayName.trim().isEmpty
            ? null
            : displayName.trim();
      }
      if (syncEnabled != null) {
        payload['syncEnabled'] = syncEnabled;
      }

      final response = await _httpClient
          .patch(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.success(UserProfile.fromJson(decoded));
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
          'Failed to update profile: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Profile update timed out. Please check your connection.',
        ),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable(
          'Unexpected profile update error: ${e.toString()}',
        ),
      );
    }
  }

  /// Initiates permanent administrative account deletion on the backend.
  Future<Result<bool>> deleteAccount() async {
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication required to delete account.',
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/account');
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
        return const Result.success(true);
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
          'Failed to delete account: server returned HTTP ${response.statusCode}.',
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Account deletion timed out. Please check your connection.',
        ),
      );
    } on SocketException catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable('Network connection failure: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable(
          'Unexpected account deletion error: ${e.toString()}',
        ),
      );
    }
  }

  void close() {
    _httpClient.close();
  }
}
