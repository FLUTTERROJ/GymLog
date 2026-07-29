import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// Thin wrapper over Supabase auth that exposes the current session as a
/// [ChangeNotifier], so the widget tree can rebuild on sign in / sign out.
class AuthService extends ChangeNotifier {
  AuthService() {
    _session = _client.auth.currentSession;
    _sub = _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;
      notifyListeners();
    });
  }

  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _sub;

  Session? _session;

  bool get isSignedIn => _session != null;
  User? get user => _session?.user;

  String get displayName {
    final user = this.user;
    if (user == null) return '';
    final meta = user.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name']) as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  String get email => user?.email ?? '';

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Returns `true` when a session was created straight away.
  ///
  /// Returns `false` when the project has "Confirm email" switched on — the
  /// user has to click the link in their inbox before they can sign in.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String role,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'username': username.trim(),
        'role': role,
      },
      emailRedirectTo: kIsWeb ? null : Env.authRedirectUrl,
    );
    return response.session != null;
  }

  /// Opens the Google consent screen. On mobile the browser hands the session
  /// back through the [Env.authRedirectUrl] deep link, which fires
  /// `onAuthStateChange` above — so there is nothing to await here beyond the
  /// launch itself.
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : Env.authRedirectUrl,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : Env.authRedirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Turns Supabase/network errors into something worth showing a user.
String describeError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505' &&
        error.message.toLowerCase().contains('username')) {
      return 'That username is already taken. Try another one.';
    }
    return error.message;
  }
  if (error is StorageException) return error.message;
  return 'Something went wrong. Please try again.';
}
