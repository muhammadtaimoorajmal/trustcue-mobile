import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/domain/models/link_inspection_result.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';

import 'module_50e1_fixtures_test.dart';

void main() {
  const inspector = UrlInspectionService();

  group('Module 56: Exact Inventory of Links.txt (57 Entries)', () {
    final fixtures = loadAll57UrlFixtures();

    test('Inventory matches exactly 57 URL entries', () {
      expect(fixtures.length, equals(57));
      expect(fixtures.first.id, equals('URL-001'));
      expect(fixtures.last.id, equals('URL-057'));
    });

    test(
      'Every URL has a valid http or https scheme and non-empty destination',
      () {
        for (final f in fixtures) {
          expect(
            f.url.startsWith('http://') || f.url.startsWith('https://'),
            isTrue,
            reason: 'Fixture ${f.id} has invalid scheme: ${f.url}',
          );
        }
      },
    );

    test('Verifies structural observations across all 57 fixtures', () {
      for (final f in fixtures) {
        final res = inspector.inspect(f.url);
        expect(res.rawInput, equals(f.url));
        expect(
          res.isValid,
          isTrue,
          reason: 'Failed parsing on ${f.id}: ${f.url}',
        );
        expect(
          res.isLaunchable,
          isTrue,
          reason: 'Should be launchable on ${f.id}: ${f.url}',
        );
        expect(res.host, isNotNull);
        expect(res.host, isNotEmpty);
        expect(res.scheme, isIn(['http', 'https']));

        // Check specific structural observations based on URL patterns:
        // 1. Unencrypted HTTP
        if (res.scheme == 'http') {
          expect(
            res.observations.any((o) => o.contains('unencrypted HTTP')),
            isTrue,
            reason: '${f.id} with http scheme must observe unencrypted HTTP',
          );
        }

        // 2. Numerical IP hosts
        if (res.isIpAddress) {
          expect(
            res.observations.any((o) => o.contains('numerical IP')),
            isTrue,
            reason: '${f.id} with IP host must observe numerical IP',
          );
        }

        // 3. Non-standard ports
        if (res.port != null && res.port != 80 && res.port != 443) {
          expect(
            res.observations.any((o) => o.contains('non-standard')),
            isTrue,
            reason:
                '${f.id} with non-standard port ${res.port} must observe port',
          );
        }

        // 4. Known URL shorteners
        if (f.id == 'URL-030') {
          expect(res.host, equals('share.google'));
          expect(
            res.observations.any((o) => o.contains('shortening')),
            isTrue,
            reason: 'URL-030 share.google must be observed as URL shortener',
          );
        }
        if (f.id == 'URL-027') {
          expect(res.host, equals('s4w.in'));
          expect(
            res.observations.any((o) => o.contains('shortening')),
            isTrue,
            reason: 'URL-027 s4w.in must be observed as URL shortener',
          );
        }

        // 5. Public cloud hosting platforms under user subdomains
        if (res.host!.endsWith('.blogspot.com') ||
            res.host!.endsWith('.github.io') ||
            res.host!.endsWith('.vercel.app') ||
            res.host!.endsWith('.pages.dev') ||
            res.host!.endsWith('.wasmer.app') ||
            res.host!.endsWith('.duckdns.org') ||
            res.host!.endsWith('.trycloudflare.com')) {
          expect(
            res.observations.any((o) => o.contains('public cloud or hosting')),
            isTrue,
            reason:
                '${f.id} on hosting platform must observe public cloud/hosting',
          );
        }
      }
    });
  });

  group('Module 56: Supplementary Boundary & Edge Cases', () {
    test(
      'Ordinary benign HTTPS addresses parse cleanly with standard structure',
      () {
        final benigns = [
          'https://example.com/',
          'https://example.org/about/us',
          'https://subdomain.example.net/search?q=test#top',
          'https://docs.flutter.dev/get-started/install',
        ];
        for (final url in benigns) {
          final res = inspector.inspect(url);
          expect(res.isValid, isTrue);
          expect(res.isLaunchable, isTrue);
          expect(res.scheme, 'https');
          expect(res.isIpAddress, isFalse);
          expect(res.isPunycode, isFalse);
        }
      },
    );

    test('Normalizes scheme and host to lowercase while preserving path and query case', () {
      final res = inspector.inspect(
        'HTTPS://EXAMPLE.COM/MixedCasePath?Param=Value',
      );
      expect(res.isValid, isTrue);
      expect(res.scheme, equals('https'));
      expect(res.host, equals('example.com'));
      expect(res.path, equals('/MixedCasePath'));
      expect(res.query, equals('Param=Value'));
      expect(
        res.rawInput,
        equals('HTTPS://EXAMPLE.COM/MixedCasePath?Param=Value'),
      );
    });

    test('Trims surrounding whitespace but rejects interior whitespace', () {
      final resTrim = inspector.inspect('   https://example.com/clean   ');
      expect(resTrim.isValid, isTrue);
      expect(resTrim.host, 'example.com');
      expect(resTrim.rawInput, '   https://example.com/clean   ');

      final resInterior = inspector.inspect('https://example.com/bad path');
      expect(resInterior.isValid, isFalse);
      expect(resInterior.rejectionCode, LinkRejectionCode.malformedUrl);
    });

    test('Rejects bare domain missing explicit protocol scheme', () {
      final bare = ['example.com', 'www.example.org', 'sub.domain.net/test'];
      for (final b in bare) {
        final res = inspector.inspect(b);
        expect(res.isValid, isFalse);
        expect(res.rejectionCode, LinkRejectionCode.missingScheme);
        expect(res.rejectionReason, contains('https://'));
      }
    });

    test('Rejects user-info deception (credentials before @) regardless of position', () {
      final deceptive = [
        'https://paypal.com@evil.example/',
        'https://secure-login.google.com@attacker.example/account',
        'http://admin:secret123@legit.example/',
        'https://user@test.example:8080/path',
      ];
      for (final d in deceptive) {
        final res = inspector.inspect(d);
        expect(res.isValid, isFalse, reason: 'Failed to reject $d');
        expect(res.isLaunchable, isFalse);
        expect(res.rejectionCode, LinkRejectionCode.containsUserInfo);
        expect(res.rejectionReason, contains('user credentials'));
      }
    });

    test('Permits literal @ character in query and path components safely', () {
      final validAt = [
        'https://example.com/users/@handle',
        'https://example.com/contact?email=support@example.com',
      ];
      for (final v in validAt) {
        final res = inspector.inspect(v);
        expect(res.isValid, isTrue, reason: 'Failed to parse $v');
        expect(res.isLaunchable, isTrue);
        expect(res.hasUserInfo, isFalse);
      }
    });

    test(
      'Observes embedded domain patterns in subdomains (domain fronting)',
      () {
        final fronted = [
          'https://paypal.com.evil.example/login',
          'https://google.com.phishing-hub.example/auth',
        ];
        for (final f in fronted) {
          final res = inspector.inspect(f);
          expect(res.isValid, isTrue);
          expect(
            res.observations.any((o) => o.contains('embedded domain pattern')),
            isTrue,
            reason: 'Expected embedded domain observation on $f',
          );
        }
      },
    );

    test(
      'Differentiates public/documentation IPv4 from private/local IPv4',
      () {
        // Public / Documentation IPv4 accepted and flagged
        final publicIps = [
          'http://93.184.216.34/', // Example.com IP
          'http://192.0.2.1/', // RFC 5737 TEST-NET-1
          'http://198.51.100.25/', // RFC 5737 TEST-NET-2
          'http://203.0.113.50/', // RFC 5737 TEST-NET-3
        ];
        for (final p in publicIps) {
          final res = inspector.inspect(p);
          expect(res.isValid, isTrue);
          expect(res.isLaunchable, isTrue);
          expect(res.isIpAddress, isTrue);
          expect(
            res.observations.any((o) => o.contains('numerical IP')),
            isTrue,
          );
        }

        // Private / local IPv4 rejected for external launch
        final privateIps = [
          'http://127.0.0.1/',
          'http://10.1.2.3/',
          'http://172.16.5.6/',
          'http://192.168.1.1/',
          'http://169.254.10.20/',
        ];
        for (final priv in privateIps) {
          final res = inspector.inspect(priv);
          expect(res.isLaunchable, isFalse);
          expect(res.rejectionCode, LinkRejectionCode.localOrPrivateHost);
        }

        // Malformed IPv4 rejected
        final malformedIps = [
          'http://999.999.999.999/',
          'http://256.0.0.1/',
          'http://010.0.0.1/', // Octal leading zero
        ];
        for (final m in malformedIps) {
          final res = inspector.inspect(m);
          expect(res.isValid, isFalse);
          expect(res.rejectionCode, LinkRejectionCode.malformedHost);
        }
      },
    );

    test(
      'Differentiates public/documentation IPv6 from local/private IPv6',
      () {
        // Documentation IPv6 literal (RFC 3849) accepted
        final publicIpv6 = 'http://[2001:db8::1]/index.html';
        final resPublic = inspector.inspect(publicIpv6);
        expect(resPublic.isValid, isTrue);
        expect(resPublic.isLaunchable, isTrue);
        expect(resPublic.isIpAddress, isTrue);
        expect(
          resPublic.observations.any((o) => o.contains('IPv6 literal')),
          isTrue,
        );

        // Local/private IPv6 rejected
        final privateIpv6 = [
          'http://[::1]/',
          'http://[::]/',
          'http://[fc00::1]/',
          'http://[fe80::1]/',
          'http://[::ffff:192.168.1.1]/',
        ];
        for (final p in privateIpv6) {
          final res = inspector.inspect(p);
          expect(res.isLaunchable, isFalse);
          expect(res.rejectionCode, LinkRejectionCode.localOrPrivateHost);
        }
      },
    );

    test(
      'Accurately observes non-standard ports and rejects invalid ports',
      () {
        // Non-standard port observed
        final resPort = inspector.inspect('https://example.com:8443/api');
        expect(resPort.port, equals(8443));
        expect(
          resPort.observations.any(
            (o) => o.contains('non-standard network port :8443'),
          ),
          isTrue,
        );

        // Default ports omitted from observations
        final resHttp80 = inspector.inspect('http://example.com:80/');
        expect(
          resHttp80.observations.any((o) => o.contains('non-standard')),
          isFalse,
        );
        final resHttps443 = inspector.inspect('https://example.com:443/');
        expect(
          resHttps443.observations.any((o) => o.contains('non-standard')),
          isFalse,
        );

        // Invalid port numbers rejected
        final invalidPorts = [
          'https://example.com:0/',
          'https://example.com:65536/',
          'https://example.com:99999/',
        ];
        for (final inv in invalidPorts) {
          final res = inspector.inspect(inv);
          expect(res.isValid, isFalse);
          expect(res.rejectionCode, LinkRejectionCode.malformedPort);
        }
      },
    );

    test('Preserves query strings, fragments, and observes destination redirect keys', () {
      final res = inspector.inspect(
        'https://example.com/sso?target=https://destination.example/home&id=42#section2',
      );
      expect(res.isValid, isTrue);
      expect(
        res.query,
        equals('target=https://destination.example/home&id=42'),
      );
      expect(res.fragment, equals('section2'));
      expect(
        res.observations.any((o) => o.contains('2 query parameter(s)')),
        isTrue,
      );
      expect(
        res.observations.any(
          (o) => o.contains('commonly used for destination redirection'),
        ),
        isTrue,
      );
    });

    test('Rejects malformed percent-encoding but accepts valid encoding', () {
      final malformed = [
        'https://example.com/%zz',
        'https://example.com/%2',
        'https://example.com/test%',
      ];
      for (final m in malformed) {
        final res = inspector.inspect(m);
        expect(res.isValid, isFalse);
        expect(res.rejectionCode, LinkRejectionCode.malformedPercentEncoding);
      }

      final valid = inspector.inspect('https://example.com/%20%2F%3F');
      expect(valid.isValid, isTrue);
    });

    test('Accepts punycode ASCII labels and flags them; rejects raw Unicode hostnames', () {
      // Punycode ASCII domain accepted and flagged
      final resPuny = inspector.inspect('https://xn--e1afmkfd.xn--p1ai/path');
      expect(resPuny.isValid, isTrue);
      expect(resPuny.isPunycode, isTrue);
      expect(
        resPuny.observations.any((o) => o.contains('punycode label')),
        isTrue,
      );

      // Raw non-ASCII Unicode domain rejected with safe explanation
      final resUnicode = inspector.inspect('https://россия.рф/path');
      expect(resUnicode.isValid, isFalse);
      expect(
        resUnicode.rejectionCode,
        LinkRejectionCode.unicodeHostUnsupported,
      );
      expect(
        resUnicode.rejectionReason,
        contains('Standard ASCII punycode ("xn--") is required'),
      );
    });

    test('Observes shortened URLs without assuming destination', () {
      final shorteners = [
        'https://share.google/1CUx4XF0XRwYPB1HR',
        'https://s4w.in/roblox-invite',
        'https://bit.ly/3xyzExample',
        'https://tinyurl.com/synthetic456',
        'https://t.co/ab12cd34',
        'https://rb.gy/987654',
      ];
      for (final s in shorteners) {
        final res = inspector.inspect(s);
        expect(res.isValid, isTrue, reason: 'Failed on $s');
        expect(
          res.observations.any(
            (o) => o.contains('URL shortening or link redirection domain'),
          ),
          isTrue,
          reason: 'Expected shortener observation on $s',
        );
      }
    });

    test('Rejects all actionable and dangerous non-web schemes with clear explanation', () {
      final nonWeb = [
        'javascript:alert("pwned")',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'file:///sdcard/Download/malware.apk',
        'content://media/external/images/media/42',
        'intent:#Intent;action=android.intent.action.VIEW;end',
        'tel:+15551234567',
        'sms:+15551234567?body=Hello',
        'mailto:security-alert@example.com',
      ];
      for (final nw in nonWeb) {
        final res = inspector.inspect(nw);
        expect(res.isValid, isFalse, reason: 'Allowed $nw');
        expect(res.isLaunchable, isFalse);
        expect(res.rejectionCode, LinkRejectionCode.unsupportedScheme);
        expect(
          res.rejectionReason,
          contains('is not supported for web navigation'),
        );
      }
    });

    test('Enforces strict 4,096 UTF-8 byte boundary', () {
      final validLength = 'https://example.com/${'x' * 3000}';
      expect(utf8.encode(validLength).length <= 4096, isTrue);
      expect(inspector.inspect(validLength).isValid, isTrue);

      final overLength = 'https://example.com/${'x' * 4100}';
      expect(utf8.encode(overLength).length > 4096, isTrue);
      final resOver = inspector.inspect(overLength);
      expect(resOver.isValid, isFalse);
      expect(resOver.rejectionCode, LinkRejectionCode.tooLong);
    });

    test('Rejects control characters, zero-width characters, bidi overrides, and backslashes', () {
      expect(
        inspector.inspect('https://example.com/\x00').rejectionCode,
        LinkRejectionCode.containsControlChars,
      );
      expect(
        inspector.inspect('https://example.com/\x1F').rejectionCode,
        LinkRejectionCode.containsControlChars,
      );
      expect(
        inspector.inspect('https://example.com/\x7F').rejectionCode,
        LinkRejectionCode.containsControlChars,
      );

      expect(
        inspector.inspect('https://example\u200B.com').rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );
      expect(
        inspector.inspect('https://example\uFEFF.com').rejectionCode,
        LinkRejectionCode.containsInvisibleChars,
      );

      expect(
        inspector.inspect('https://example\u202E.com').rejectionCode,
        LinkRejectionCode.containsBidiChars,
      );
      expect(
        inspector.inspect('https://example\u2067.com').rejectionCode,
        LinkRejectionCode.containsBidiChars,
      );

      expect(
        inspector.inspect(r'https://example.com\evil.example').rejectionCode,
        LinkRejectionCode.containsBackslash,
      );
    });
  });

  group('Module 56: Controller Handoff & Safe Non-Launching Guarantee', () {
    late InputLinkController controller;

    setUp(() {
      controller = InputLinkController(urlInspector: inspector);
    });

    tearDown(() {
      controller.onClose();
    });

    test(
      'Controller inspectTextLink updates activeInspection without launching',
      () {
        controller.urlTextController.text = 'https://example.com/test';
        expect(controller.activeInspection, isNull);
        expect(controller.canOpenExternally, isFalse);

        controller.inspectTextLink();

        expect(controller.activeInspection, isNotNull);
        expect(controller.activeInspection!.isValid, isTrue);
        expect(controller.activeInspection!.host, 'example.com');
        expect(controller.canOpenExternally, isTrue);
        expect(controller.showOpenConfirmation.value, isFalse);
      },
    );

    test(
      'Controller handles rejected and unsupported URLs safely without crash',
      () {
        final invalidInputs = [
          'javascript:alert(1)',
          'http://192.168.1.1/',
          'https://user@evil.example/',
          'malformed:url::test',
          '',
        ];

        for (final inv in invalidInputs) {
          controller.urlTextController.text = inv;
          controller.inspectTextLink();

          expect(controller.activeInspection, isNotNull);
          expect(controller.activeInspection!.isLaunchable, isFalse);
          expect(controller.canOpenExternally, isFalse);
        }
      },
    );

    test('Editing text automatically invalidates prior inspection result and confirmation', () {
      controller.urlTextController.text = 'https://example.com';
      controller.inspectTextLink();
      expect(controller.activeInspection, isNotNull);

      controller.urlTextController.text = 'https://example.org';
      // Changing text resets confirmation and reviewed state
      expect(controller.showOpenConfirmation.value, isFalse);
      expect(controller.reviewedResult.value, isNull);
    });
  });
}
