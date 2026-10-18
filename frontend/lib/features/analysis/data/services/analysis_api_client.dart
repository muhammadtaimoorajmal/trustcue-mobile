import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/ai_analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Typed, privacy-preserving HTTP API client for TrustCue's protected cloud AI analysis endpoint.
///
/// Invariants & Security Boundaries:
/// - Never includes or handles provider API keys or administrative secrets.
/// - Authenticates strictly via user JWT Bearer token supplied by [tokenProvider].
/// - Evaluates explicit [UploadConsent] validity BEFORE initiating network transmission.
/// - Never logs request payload bodies, analyzed user text, or bearer tokens.
/// - Enforces bounded response sizes (max 1 MB) and bounded timeouts (20 seconds).
/// - Fails closed to privacy-safe, typed [AnalysisFailure] objects.
class AnalysisApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() tokenProvider;
  final Duration timeout;
  final int maxResponseBytes;
  final AiAnalysisReportCodec _codec;

  AnalysisApiClient({
    String? baseUrl,
    http.Client? httpClient,
    required this.tokenProvider,
    this.timeout = const Duration(seconds: 20),
    this.maxResponseBytes = 1000000,
    AiAnalysisReportCodec? codec,
  }) : baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
       _httpClient = httpClient ?? http.Client(),
       _codec = codec ?? const AiAnalysisReportCodec();

  static String _resolveDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    if (envUrl.trim().isNotEmpty) {
      return envUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    if (kReleaseMode) {
      return 'https://trustcue-backend.onrender.com';
    }

    // In local development, Android emulator accesses host loopback via 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Transmits the user-reviewed text snapshot for protected server-assisted AI analysis.
  ///
  /// Requires explicit, affirmative [consent] bound to [snapshot].
  Future<Result<AiAnalysisReport>> analyzeWithAi({
    required TextSnapshot snapshot,
    required UploadConsent consent,
    required String sourceRevision,
    String? currentAccountId,
  }) async {
    // 1. Enforce local pre-upload consent binding before sending any bytes
    if (!consent.isValidFor(snapshot, candidateAccountId: currentAccountId)) {
      return const Result.failure(
        AnalysisFailure.consentRequired(
          'Explicit user upload consent is required to transmit text for AI review.',
        ),
      );
    }

    // 2. Resolve authenticated JWT Bearer token
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const Result.failure(
        AnalysisFailure.unauthorized(
          'Authentication is required to use Cloud AI features.',
        ),
      );
    }

    // 3. Assemble validated request payload
    final payload = {
      'snapshotId': snapshot.id,
      'text': snapshot.text,
      'source': snapshot.source.name,
      'sourceRevision': sourceRevision,
      'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      'consent': consent.toJson(),
    };

    final uri = Uri.parse('$baseUrl/api/v1/analysis/ai');
    final headers = {
      'Authorization': 'Bearer ${token.trim()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);

      // Enforce strict response body size limit
      if (response.bodyBytes.length > maxResponseBytes) {
        return const Result.failure(
          AnalysisFailure.malformedData(
            'Server response exceeded maximum safe boundary.',
          ),
        );
      }

      final statusCode = response.statusCode;

      if (statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        if (decodedJson is! Map<String, dynamic>) {
          return const Result.failure(
            AnalysisFailure.malformedData('Expected JSON object from server.'),
          );
        }

        final report = _codec.decode(decodedJson);

        // Client-side verification: guarantee that returned offsets and excerpts
        // strictly match the local reviewed snapshot
        report.validateAgainst(snapshot);
        return Result.success(report);
      }

      // Handle typed HTTP failure envelopes
      Map<String, dynamic>? errorBody;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic> &&
            parsed['error'] is Map<String, dynamic>) {
          errorBody = parsed['error'] as Map<String, dynamic>;
        }
      } catch (_) {
        // Fallback for non-JSON error envelopes
      }

      final errorCode = errorBody?['code'] as String?;
      final errorMessage = errorBody?['message'] as String?;

      switch (statusCode) {
        case 400:
          if (errorCode == 'consent_required' ||
              errorCode == 'unsupported_disclosure_version') {
            return Result.failure(
              AnalysisFailure.consentRequired(
                errorMessage ?? 'Upload consent was rejected or invalid.',
              ),
            );
          }
          return Result.failure(
            AnalysisFailure.invalidInput(
              errorMessage ?? 'Submitted text failed validation.',
            ),
          );

        case 401:
          return const Result.failure(
            AnalysisFailure.unauthorized(
              'Your session has expired. Please sign in again.',
            ),
          );

        case 413:
          return const Result.failure(
            AnalysisFailure.invalidInput(
              'Submitted text exceeds server size limit.',
            ),
          );

        case 429:
          final retryAfterHeader = response.headers['retry-after'];
          final retrySeconds = retryAfterHeader != null
              ? int.tryParse(retryAfterHeader)
              : null;
          return Result.failure(
            AnalysisFailure.rateLimited(
              errorMessage ?? 'Daily AI request quota or rate limit exceeded.',
              retrySeconds?.toString(),
            ),
          );

        case 502:
          return Result.failure(
            AnalysisFailure.providerError(
              errorMessage ??
                  'AI model output could not be grounded in your message.',
            ),
          );

        case 503:
          return Result.failure(
            AnalysisFailure.unavailable(
              errorMessage ??
                  'Cloud AI analysis service is temporarily unavailable.',
            ),
          );

        case 504:
          return const Result.failure(
            AnalysisFailure.timeout('Cloud AI analysis request timed out.'),
          );

        default:
          return Result.failure(
            AnalysisFailure.unavailable(
              'Server returned error ($statusCode). Local results preserved.',
            ),
          );
      }
    } on TimeoutException {
      return const Result.failure(
        AnalysisFailure.timeout(
          'Cloud AI analysis timed out. Local results preserved.',
        ),
      );
    } on SocketException {
      return const Result.failure(
        AnalysisFailure.unavailable(
          'Network connection failed. Local analysis results preserved.',
        ),
      );
    } on http.ClientException {
      return const Result.failure(
        AnalysisFailure.unavailable(
          'Unable to reach TrustCue backend. Local analysis results preserved.',
        ),
      );
    } on FormatException catch (e) {
      return Result.failure(
        AnalysisFailure.malformedData(
          'Failed to decode server analysis response: ${e.message}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.unavailable(
          'An unexpected error occurred during AI analysis. Local results preserved.',
        ),
      );
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}
