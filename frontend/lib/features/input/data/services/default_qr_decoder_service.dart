import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../domain/contracts/qr_decoder_service.dart';
import '../../domain/models/qr_decode_result.dart';
import '../../domain/models/qr_payload.dart';
import '../../domain/services/url_inspection_service.dart';

/// Default implementation of [QrDecoderService] backed by Google ML Kit Barcode Scanning.
///
/// Restricts scanning strictly to [BarcodeFormat.qrCode] and uses the bundled
/// on-device model. Never automatically navigates or executes payload intents.
class DefaultQrDecoderService implements QrDecoderService {
  DefaultQrDecoderService({
    BarcodeScanner Function()? scannerFactory,
    UrlInspectionService? urlInspector,
  }) : _scannerFactory = scannerFactory ?? _defaultScannerFactory,
       _urlInspector = urlInspector ?? const UrlInspectionService();

  final BarcodeScanner Function() _scannerFactory;
  final UrlInspectionService _urlInspector;

  static BarcodeScanner _defaultScannerFactory() {
    return BarcodeScanner(formats: const <BarcodeFormat>[BarcodeFormat.qrCode]);
  }

  @override
  Future<QrDecodeResult> decode(
    String filePath, {
    String? operationToken,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return QrDecodeResult.error('Image file does not exist on device.');
    }

    final scanner = _scannerFactory();
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final List<Barcode> barcodes = await scanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return QrDecodeResult.empty();
      }

      final payloads = <QrPayload>[];
      final seenRawValues = <String>{};

      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }

        // Deduplicate identical duplicate codes
        if (!seenRawValues.add(raw)) {
          continue;
        }

        final byteCount = utf8.encode(raw).length;
        final isOversized = byteCount > UrlInspectionService.maxUtf8Bytes;

        if (isOversized) {
          payloads.add(
            QrPayload(
              rawValue: raw,
              byteCount: byteCount,
              type: QrPayloadType.unsupported,
              summary: 'Decoded payload exceeds the 4,096-byte limit and cannot be processed.',
              formatDescription: 'Oversized Payload',
              isOversized: true,
            ),
          );
          continue;
        }

        final upper = raw.toUpperCase();
        if (upper.startsWith('WIFI:')) {
          payloads.add(
            QrPayload(
              rawValue: raw,
              byteCount: byteCount,
              type: QrPayloadType.unsupported,
              summary: 'Wi-Fi network configuration payload',
              formatDescription: 'Wi-Fi Configuration',
              isOversized: isOversized,
            ),
          );
        } else if (upper.startsWith('BEGIN:VCARD') ||
            upper.startsWith('MECARD:')) {
          payloads.add(
            QrPayload(
              rawValue: raw,
              byteCount: byteCount,
              type: QrPayloadType.unsupported,
              summary: 'Contact card (vCard / MeCard) payload',
              formatDescription: 'Contact Card',
              isOversized: isOversized,
            ),
          );
        } else if (raw.toLowerCase().startsWith('upi:') ||
            raw.toLowerCase().startsWith('bitcoin:')) {
          payloads.add(
            QrPayload(
              rawValue: raw,
              byteCount: byteCount,
              type: QrPayloadType.unsupported,
              summary: 'Financial / payment transfer intent',
              formatDescription: 'Payment Intent',
              isOversized: isOversized,
            ),
          );
        } else if (raw.toLowerCase().startsWith('intent:')) {
          payloads.add(
            QrPayload(
              rawValue: raw,
              byteCount: byteCount,
              type: QrPayloadType.unsupported,
              summary: 'Platform application intent',
              formatDescription: 'Application Intent',
              isOversized: isOversized,
            ),
          );
        } else {
          // Check if payload is a web URL or plain text
          final inspection = _urlInspector.inspect(raw);
          final looksLikeUrl =
              inspection.scheme == 'http' ||
              inspection.scheme == 'https' ||
              raw.toLowerCase().startsWith('http://') ||
              raw.toLowerCase().startsWith('https://');

          if (looksLikeUrl) {
            payloads.add(
              QrPayload(
                rawValue: raw,
                byteCount: byteCount,
                type: QrPayloadType.url,
                summary: raw.length > 60 ? '${raw.substring(0, 57)}...' : raw,
                formatDescription: 'Web Address',
                isOversized: isOversized,
                linkInspection: inspection,
              ),
            );
          } else {
            final singleLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
            final summary = singleLine.length > 60
                ? '${singleLine.substring(0, 57)}...'
                : singleLine;
            payloads.add(
              QrPayload(
                rawValue: raw,
                byteCount: byteCount,
                type: QrPayloadType.plainText,
                summary: summary,
                formatDescription: 'Plain Text',
                isOversized: isOversized,
              ),
            );
          }
        }
      }

      return QrDecodeResult(payloads: payloads);
    } catch (e) {
      return QrDecodeResult.error('Failed to decode QR code: $e');
    } finally {
      await scanner.close();
    }
  }
}
