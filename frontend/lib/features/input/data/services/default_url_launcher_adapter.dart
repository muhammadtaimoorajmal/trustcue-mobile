import 'package:url_launcher/url_launcher.dart';

import '../../domain/contracts/url_launcher_adapter.dart';

/// Default implementation of [UrlLauncherAdapter] using [url_launcher].
///
/// Always requests [LaunchMode.externalApplication] so destinations are opened
/// in the user's default browser or external handler rather than an embedded webview.
class DefaultUrlLauncherAdapter implements UrlLauncherAdapter {
  const DefaultUrlLauncherAdapter();

  @override
  Future<bool> canLaunch(Uri url) async {
    try {
      return await canLaunchUrl(url);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> launch(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
