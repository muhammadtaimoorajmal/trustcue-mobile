/// Injectable adapter interface for external URL launching.
///
/// Implementations must open the destination strictly in an external application
/// rather than an in-app webview, and must not execute automated navigation without
/// prior confirmation.
abstract class UrlLauncherAdapter {
  /// Checks whether an external application is available to handle the given [url].
  Future<bool> canLaunch(Uri url);

  /// Launches the given [url] in an external application (browser).
  ///
  /// Returns `true` if the launch succeeded, `false` otherwise.
  Future<bool> launch(Uri url);
}
