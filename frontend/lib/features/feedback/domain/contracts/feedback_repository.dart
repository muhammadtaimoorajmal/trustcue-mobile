import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';

/// Contract for persisting anonymous user usefulness feedback locally on the device.
///
/// Invariants:
/// - Feedback is stored strictly in local SQLite.
/// - Zero network transmission or background telemetry.
/// - No personally identifiable information or raw message data.
abstract class FeedbackRepository {
  /// Saves an anonymous feedback record locally.
  Future<void> saveFeedback(AppFeedback feedback);

  /// Retrieves the total count of feedback items stored locally.
  Future<int> getFeedbackCount();

  /// Retrieves all feedback items ordered by creation date descending.
  Future<List<AppFeedback>> getAllFeedback({int limit = 50, int offset = 0});

  /// Deletes all locally stored feedback records.
  Future<void> clearAllFeedback();
}
