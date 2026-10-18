/// Data transfer and domain models for Module 39 Cloud Report Synchronization.
library;

class CloudReportItem {
  final String clientReportId;
  final String snapshotId;
  final int schemaVersion;
  final int syncGeneration;
  final Map<String, dynamic> reportPayload;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime clientUpdatedAt;

  const CloudReportItem({
    required this.clientReportId,
    required this.snapshotId,
    this.schemaVersion = 1,
    this.syncGeneration = 1,
    required this.reportPayload,
    this.isDeleted = false,
    this.deletedAt,
    required this.clientUpdatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientReportId': clientReportId,
      'snapshotId': snapshotId,
      'schemaVersion': schemaVersion,
      'syncGeneration': syncGeneration,
      'reportPayload': reportPayload,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt!.toUtc().toIso8601String(),
      'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
    };
  }
}

class CloudReportRecord {
  final String id;
  final String clientReportId;
  final String snapshotId;
  final int schemaVersion;
  final int revision;
  final int syncGeneration;
  final Map<String, dynamic> reportPayload;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CloudReportRecord({
    required this.id,
    required this.clientReportId,
    required this.snapshotId,
    required this.schemaVersion,
    required this.revision,
    this.syncGeneration = 1,
    required this.reportPayload,
    required this.isDeleted,
    this.deletedAt,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CloudReportRecord.fromJson(Map<String, dynamic> json) {
    return CloudReportRecord(
      id: json['id'] as String,
      clientReportId: json['clientReportId'] as String,
      snapshotId: json['snapshotId'] as String,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      revision: json['revision'] as int? ?? 1,
      syncGeneration: json['syncGeneration'] as int? ?? 1,
      reportPayload: (json['reportPayload'] as Map).cast<String, dynamic>(),
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      clientUpdatedAt: DateTime.parse(json['clientUpdatedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class SyncPushResult {
  final int acceptedCount;
  final List<String> syncedReportIds;
  final DateTime serverTimestamp;

  const SyncPushResult({
    required this.acceptedCount,
    required this.syncedReportIds,
    required this.serverTimestamp,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) {
    return SyncPushResult(
      acceptedCount: json['acceptedCount'] as int? ?? 0,
      syncedReportIds:
          (json['syncedReportIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
    );
  }
}

class SyncPullResult {
  final List<CloudReportRecord> reports;
  final String? nextCursor;
  final bool hasMore;
  final DateTime serverTimestamp;

  const SyncPullResult({
    required this.reports,
    this.nextCursor,
    required this.hasMore,
    required this.serverTimestamp,
  });

  factory SyncPullResult.fromJson(Map<String, dynamic> json) {
    final rawReports = (json['reports'] as List<dynamic>?) ?? [];
    return SyncPullResult(
      reports: rawReports
          .map((r) => CloudReportRecord.fromJson(r as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
    );
  }
}

class SyncPurgeResult {
  final int purgedCount;
  final String message;
  final DateTime serverTimestamp;

  const SyncPurgeResult({
    required this.purgedCount,
    required this.message,
    required this.serverTimestamp,
  });

  factory SyncPurgeResult.fromJson(Map<String, dynamic> json) {
    return SyncPurgeResult(
      purgedCount: json['purgedCount'] as int? ?? 0,
      message: json['message'] as String? ?? 'Cloud synced reports purged.',
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
    );
  }
}
