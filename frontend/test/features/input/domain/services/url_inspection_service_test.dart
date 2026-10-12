import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/domain/models/link_inspection_result.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';

void main() {
  const inspector = UrlInspectionService();

  group('UrlInspectionService - Length and Basic Validation', () {
    test('rejects empty input', () {
      final res = inspector.inspect('');
      expect(res.isValid, isFalse);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.empty);
    });

    test('rejects whitespace-only input', () {
      final res = inspector.inspect('   \n\t  ');
      expect(res.isValid, isFalse);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.empty);
    });

    test('rejects input exceeding 4,096 UTF-8 bytes', () {
      final longDomain = 'https://example.com/${'a' * 4100}';
      expect(utf8.encode(longDomain).length > 4096, isTrue);

      final res = inspector.inspect(longDomain);
      expect(res.isValid, isFalse);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.tooLong);
    });

    test('accepts input within 4,096 UTF-8 bytes', () {
      final longValid = 'https://example.com/${'a' * 3000}';
      final res = inspector.inspect(longValid);
      expect(res.isValid, isTrue);
      expect(res.isLaunchable, isTrue);
    });
  });

  group('UrlInspectionService - Schemes', () {
    test('rejects bare domain without scheme', () {
      final res = inspector.inspect('example.com/path');
      expect(res.isValid, isFalse);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.missingScheme);
      expect(res.rejectionReason, contains('https://'));
    });

    test('rejects dangerous schemes', () {
      final dangerous = [
        'javascript:alert(1)',
        'data:text/html,<h1>Phish</h1>',
        'file:///etc/passwd',
        'intent:#Intent;action=android.intent.action.VIEW;end',
        'tel:+15551234567',
        'sms:+15551234567',
        'mailto:admin@example.com',
      ];

      for (final url in dangerous) {
        final res = inspector.inspect(url);
        expect(res.isValid, isFalse, reason: 'Failed on $url');
        expect(res.isLaunchable, isFalse, reason: 'Failed on $url');
        expect(
          res.rejectionCode,
          LinkRejectionCode.unsupportedScheme,
          reason: 'Failed on $url',
        );
      }
    });

    test('accepts http and https schemes case-insensitively', () {
      final resHttps = inspector.inspect('HTTPS://example.com');
      expect(resHttps.isValid, isTrue);
      expect(resHttps.isLaunchable, isTrue);
      expect(resHttps.scheme, 'https');

      final resHttp = inspector.inspect('HTTP://example.com');
      expect(resHttp.isValid, isTrue);
      expect(resHttp.isLaunchable, isTrue);
      expect(resHttp.scheme, 'http');
    });
  });

  group('UrlInspectionService - Prohibited Characters & UserInfo', () {
    test('rejects embedded user credentials / userinfo', () {
      final withCreds = [
        'https://user:password@example.com',
        'https://admin@example.com/path',
        'http://spoof.com@legit.com',
      ];

      for (final url in withCreds) {
        final res = inspector.inspect(url);
        expect(res.isValid, isFalse);
        expect(res.isLaunchable, isFalse);
        expect(res.rejectionCode, LinkRejectionCode.containsUserInfo);
      }
    });

    test('rejects backslashes', () {
      final res = inspector.inspect(r'https://example.com\evil.com');
      expect(res.isValid, isFalse);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.containsBackslash);
    });

    test('rejects control characters', () {
      final res1 = inspector.inspect('https://example.com/\x00');
      expect(res1.rejectionCode, LinkRejectionCode.containsControlChars);

      final res2 = inspector.inspect('https://example.com/\x1F');
      expect(res2.rejectionCode, LinkRejectionCode.containsControlChars);

      final res3 = inspector.inspect('https://example.com/\x7F');
      expect(res3.rejectionCode, LinkRejectionCode.containsControlChars);
    });

    test('rejects zero-width and invisible characters', () {
      final zwsp = 'https://example\u200B.com';
      final zwnj = 'https://example\u200C.com';
      final zwj = 'https://example\u200D.com';
      final bom = 'https://example\uFEFF.com';

      expect(
        inspector.inspect(zwsp).rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );
      expect(
        inspector.inspect(zwnj).rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );
      expect(
        inspector.inspect(zwj).rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );
      expect(
        inspector.inspect(bom).rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );
    });

    test('rejects bidirectional override characters', () {
      final rlo = 'https://example\u202E.com';
      final lro = 'https://example\u202D.com';
      final rli = 'https://example\u2067.com';

      expect(
        inspector.inspect(rlo).rejectionCode,
        LinkRejectionCode.containsBidiChars,
      );
      expect(
        inspector.inspect(lro).rejectionCode,
        LinkRejectionCode.containsBidiChars,
      );
      expect(
        inspector.inspect(rli).rejectionCode,
        LinkRejectionCode.containsBidiChars,
      );
    });

    test('rejects invalid percent-encoding', () {
      final incomplete = 'https://example.com/test%2';
      final nonHex = 'https://example.com/test%zz';

      expect(
        inspector.inspect(incomplete).rejectionCode,
        LinkRejectionCode.malformedPercentEncoding,
      );
      expect(
        inspector.inspect(nonHex).rejectionCode,
        LinkRejectionCode.malformedPercentEncoding,
      );
    });

    test('accepts valid percent-encoding', () {
      final valid = 'https://example.com/test%20query%2Fitem';
      final res = inspector.inspect(valid);
      expect(res.isValid, isTrue);
      expect(res.isLaunchable, isTrue);
    });
  });

  group('UrlInspectionService - Hostname and IP Restrictions', () {
    test('rejects localhost and single-label hosts', () {
      final locals = [
        'http://localhost',
        'http://localhost:8080',
        'http://myrouter',
        'https://internal-server',
        'http://app.localhost',
        'http://printer.local',
      ];

      for (final url in locals) {
        final res = inspector.inspect(url);
        expect(res.isLaunchable, isFalse, reason: 'Failed on $url');
        expect(
          res.rejectionCode,
          LinkRejectionCode.localOrPrivateHost,
          reason: 'Failed on $url',
        );
      }
    });

    test('rejects private IPv4 addresses (RFC 1918)', () {
      final privateIps = [
        'http://10.0.0.1',
        'http://10.255.255.254',
        'http://172.16.0.1',
        'http://172.31.255.254',
        'http://192.168.0.1',
        'http://192.168.100.254',
      ];

      for (final url in privateIps) {
        final res = inspector.inspect(url);
        expect(res.isLaunchable, isFalse, reason: 'Failed on $url');
        expect(
          res.rejectionCode,
          LinkRejectionCode.localOrPrivateHost,
          reason: 'Failed on $url',
        );
      }
    });

    test('rejects loopback, link-local, unspecified IPv4', () {
      final internalIps = [
        'http://127.0.0.1',
        'http://127.2.3.4',
        'http://169.254.1.1',
        'http://0.0.0.0',
        'http://255.255.255.255',
      ];

      for (final url in internalIps) {
        final res = inspector.inspect(url);
        expect(res.isLaunchable, isFalse, reason: 'Failed on $url');
        expect(
          res.rejectionCode,
          LinkRejectionCode.localOrPrivateHost,
          reason: 'Failed on $url',
        );
      }
    });

    test('rejects local and private IPv6 addresses', () {
      final internalIpv6 = [
        'http://[::1]',
        'http://[::]',
        'http://[fc00::1]',
        'http://[fd12:3456::1]',
        'http://[fe80::1]',
      ];

      for (final url in internalIpv6) {
        final res = inspector.inspect(url);
        expect(res.isLaunchable, isFalse, reason: 'Failed on $url');
        expect(
          res.rejectionCode,
          LinkRejectionCode.localOrPrivateHost,
          reason: 'Failed on $url',
        );
      }
    });

    test('rejects Unicode hostnames without Punycode', () {
      final unicodeHost = 'https://раypal.com'; // Cyrillic 'а'
      final res = inspector.inspect(unicodeHost);
      expect(res.isLaunchable, isFalse);
      expect(res.rejectionCode, LinkRejectionCode.unicodeHostUnsupported);
    });

    test('accepts ASCII Punycode hostnames and flags them', () {
      final punycodeUrl = 'https://xn--e1afmkfd.xn--p1ai';
      final res = inspector.inspect(punycodeUrl);
      expect(res.isValid, isTrue);
      expect(res.isLaunchable, isTrue);
      expect(res.isPunycode, isTrue);
      expect(res.observations.any((o) => o.contains('punycode')), isTrue);
    });

    test('accepts public IPv4 and flags as numerical IP', () {
      final publicIp = 'http://93.184.216.34/test';
      final res = inspector.inspect(publicIp);
      expect(res.isValid, isTrue);
      expect(res.isLaunchable, isTrue);
      expect(res.isIpAddress, isTrue);
      expect(res.observations.any((o) => o.contains('numerical IP')), isTrue);
    });

    test('accepts public IPv6 literal', () {
      final publicIpv6 = 'http://[2001:db8::1]/test';
      final res = inspector.inspect(publicIpv6);
      expect(res.isValid, isTrue);
      expect(res.isLaunchable, isTrue);
      expect(res.isIpAddress, isTrue);
    });
  });

  group('UrlInspectionService - Factual Observations', () {
    test('observes unencrypted HTTP', () {
      final res = inspector.inspect('http://example.com');
      expect(res.isLaunchable, isTrue);
      expect(
        res.observations.any((o) => o.contains('unencrypted HTTP')),
        isTrue,
      );
    });

    test('observes non-standard port', () {
      final res = inspector.inspect('https://example.com:8443/api');
      expect(res.port, 8443);
      expect(res.observations.any((o) => o.contains('non-standard')), isTrue);
    });

    test('does not observe default ports', () {
      final resHttps = inspector.inspect('https://example.com:443');
      expect(
        resHttps.observations.any((o) => o.contains('non-standard')),
        isFalse,
      );

      final resHttp = inspector.inspect('http://example.com:80');
      expect(
        resHttp.observations.any((o) => o.contains('non-standard')),
        isFalse,
      );
    });

    test('observes query parameters and open redirect parameters', () {
      final res = inspector.inspect(
        'https://example.com/login?redirect=https://evil.com&track=123',
      );
      expect(res.query, isNotNull);
      expect(
        res.observations.any((o) => o.contains('query parameter')),
        isTrue,
      );
      expect(res.observations.any((o) => o.contains('redirect')), isTrue);
    });
  });
}
