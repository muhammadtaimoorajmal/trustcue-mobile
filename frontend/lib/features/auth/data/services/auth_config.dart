/// Configuration for Supabase client authentication.
///
/// Contains ONLY public client credentials (URL and publishable anonymous key).
/// Strictly NEVER accepts or holds server signing secrets or service-role keys.
class AuthConfig {
  const AuthConfig({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.callbackScheme = 'trustcue',
    this.callbackHost = 'auth-callback',
  });

  /// The public Supabase project URL (e.g. `https://xyzcompany.supabase.co`).
  final String? supabaseUrl;

  /// The public anonymous key for client requests.
  final String? supabaseAnonKey;

  /// The custom URI scheme for mobile deep-link callbacks.
  final String callbackScheme;

  /// The hostname component for mobile deep-link callbacks.
  final String callbackHost;

  /// Whether public cloud authentication parameters are present.
  bool get isConfigured =>
      supabaseUrl != null &&
      supabaseUrl!.trim().isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey!.trim().isNotEmpty;

  /// Full redirect URL registered with the authentication provider.
  String get redirectUrl => '$callbackScheme://$callbackHost';

  /// Construct configuration from compile-time environment defines.
  factory AuthConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    const scheme = String.fromEnvironment(
      'AUTH_CALLBACK_SCHEME',
      defaultValue: 'trustcue',
    );
    const host = String.fromEnvironment(
      'AUTH_CALLBACK_HOST',
      defaultValue: 'auth-callback',
    );

    return AuthConfig(
      supabaseUrl: url.isNotEmpty ? url : null,
      supabaseAnonKey: anonKey.isNotEmpty ? anonKey : null,
      callbackScheme: scheme,
      callbackHost: host,
    );
  }

  @override
  String toString() =>
      'AuthConfig(isConfigured: $isConfigured, scheme: $callbackScheme, host: $callbackHost)';
}
