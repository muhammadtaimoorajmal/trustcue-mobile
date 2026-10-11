/// Supported static image formats for screenshot preview.
enum ImageFormat { png, jpeg }

/// Immutable descriptor representing a validated screenshot image selected
/// and owned by the application for local preview.
///
/// Invariants:
/// - [id] must not be empty.
/// - [width] and [height] must be positive and not exceed 12,000 pixels.
/// - Total pixels ([width] * [height]) must not exceed 20,000,000 pixels.
/// - [byteCount] must be positive and not exceed 10 MiB (10,485,760 bytes).
/// - [filePath] points to the app-owned private copy; it is strictly excluded
///   from [toString] and diagnostic output to preserve privacy.
class SelectedImageDescriptor {
  final String id;
  final ImageFormat format;
  final int width;
  final int height;
  final int byteCount;
  final String filePath;

  SelectedImageDescriptor({
    required this.id,
    required this.format,
    required this.width,
    required this.height,
    required this.byteCount,
    required this.filePath,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Image ID must not be empty.');
    }
    if (width <= 0 || height <= 0) {
      throw ArgumentError(
        'Image dimensions must be positive ($width x $height).',
      );
    }
    if (width > 12000 || height > 12000) {
      throw ArgumentError(
        'Image dimensions exceed 12,000 pixels ($width x $height).',
      );
    }
    if (width * height > 20000000) {
      throw ArgumentError(
        'Image pixel count exceeds 20,000,000 (${width * height}).',
      );
    }
    if (byteCount <= 0 || byteCount > 10 * 1024 * 1024) {
      throw ArgumentError.value(
        byteCount,
        'byteCount',
        'Image byte count must be between 1 and 10 MiB.',
      );
    }
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'File path must not be empty.',
      );
    }
  }

  /// Human-readable dimensions string (e.g. "1080 × 2400 px").
  String get dimensionsText => '$width × $height px';

  /// Human-readable uppercase format name (e.g. "PNG" or "JPEG").
  String get formatName => format == ImageFormat.png ? 'PNG' : 'JPEG';

  /// Formatted file size string (e.g. "840.5 KB" or "2.3 MB").
  String get formattedFileSize {
    if (byteCount < 1024 * 1024) {
      final kb = byteCount / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = byteCount / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelectedImageDescriptor &&
          other.id == id &&
          other.format == format &&
          other.width == width &&
          other.height == height &&
          other.byteCount == byteCount &&
          other.filePath == filePath);

  @override
  int get hashCode =>
      Object.hash(id, format, width, height, byteCount, filePath);

  @override
  String toString() {
    // Deliberately omits filePath to avoid leaking filesystem layout in logs.
    return 'SelectedImageDescriptor(id: $id, format: $formatName, dimensions: $dimensionsText, size: $formattedFileSize)';
  }
}
