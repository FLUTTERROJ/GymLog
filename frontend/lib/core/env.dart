/// Build-time configuration.
///
/// Values come from `--dart-define` (or `--dart-define-from-file=env.json`) so
/// nothing secret is committed. The anon key is safe to ship inside the app —
/// Row Level Security in the database is what protects the data, not the
/// secrecy of that key. The service_role key must never appear here.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where Google sends the user back to after they approve the sign-in.
  ///
  /// Must match, exactly:
  ///   * Supabase → Authentication → URL Configuration → Redirect URLs
  ///   * the intent-filter in android/app/src/main/AndroidManifest.xml
  ///   * CFBundleURLSchemes in ios/Runner/Info.plist
  static const String authRedirectUrl = 'io.supabase.gymlog://login-callback/';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
