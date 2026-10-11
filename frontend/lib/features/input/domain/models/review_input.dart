import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// In-memory parameter container passed to the `/input/review` route.
///
/// Contains the source [TextSnapshot] and source revision identifier, with an optional
/// path to the temporary screenshot file if originated from `/input/screenshot`.
/// Sensitive message content and filesystem paths are never serialized into URLs or query strings.
class ReviewInput {
  const ReviewInput({
    required this.snapshot,
    required this.sourceRevision,
    this.imagePath,
  });

  /// The immutable initial snapshot prepared by the source input route.
  final TextSnapshot snapshot;

  /// Identifier representing the revision of the source data (e.g. image revision or edit sequence).
  final String sourceRevision;

  /// Optional app-owned temporary image path for comparison display if originated from screenshot.
  final String? imagePath;

  @override
  String toString() {
    return 'ReviewInput(snapshotId: ${snapshot.id}, source: ${snapshot.source.name}, revision: $sourceRevision, hasImage: ${imagePath != null})';
  }
}
