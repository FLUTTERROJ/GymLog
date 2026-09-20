import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

class AppProfile {
  const AppProfile({
    required this.id,
    this.username,
    this.fullName,
    required this.role,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String role;

  bool get isTrainer => role == 'trainer';
  bool get isComplete => username != null && username!.trim().isNotEmpty;

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
        id: map['id'] as String,
        username: map['username'] as String?,
        fullName: map['full_name'] as String?,
        role: (map['role'] as String?) ?? 'client',
      );
}

class TrainerProfile {
  const TrainerProfile({
    required this.id,
    required this.username,
    this.fullName,
  });
  final String id;
  final String username;
  final String? fullName;

  factory TrainerProfile.fromMap(Map<String, dynamic> map) => TrainerProfile(
        id: map['id'] as String,
        username: map['username'] as String,
        fullName: map['full_name'] as String?,
      );
}

class ProfileService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  AppProfile? _profile;
  bool _loading = false;

  AppProfile? get profile => _profile;
  bool get isLoading => _loading;

  Future<void> load() async {
    final user = _client.auth.currentUser;
    if (user == null || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      var row = await _client
          .from('profiles')
          .select('id, username, full_name, role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(Env.networkTimeout);

      if (row == null) {
        // A signed-in user with no profile row at all. This is meant to be
        // impossible -- a trigger on auth.users creates one for every
        // signup -- but that trigger hasn't reliably fired for every
        // sign-in path (seen in practice for Google-only accounts with no
        // prior email/password signup). Rather than depend on fully
        // understanding an opaque trigger-timing issue inside Supabase
        // Auth, create the missing row directly: same fields, same
        // defaults the trigger itself would have used.
        final meta = user.userMetadata;
        final fullName = (meta?['full_name'] ?? meta?['name']) as String?;
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          if (fullName != null) 'full_name': fullName,
        }).timeout(Env.networkTimeout);

        row = await _client
            .from('profiles')
            .select('id, username, full_name, role')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(Env.networkTimeout);
      }

      if (row == null) {
        // Still nothing after trying to create it -- genuinely broken, not
        // just a missing trigger. AuthGate can't tell "still loading" apart
        // from "loaded, and it's empty" (both look like `profile == null`),
        // so left alone this hangs on the loading spinner forever. Signing
        // out is the same recovery the catch block below already uses for
        // an unusable session.
        _profile = null;
        await _client.auth.signOut().timeout(Env.networkTimeout).catchError(
              (_) {},
            );
      } else {
        _profile = AppProfile.fromMap(Map<String, dynamic>.from(row));
      }
    } catch (error) {
      // A stale session left over from a different Supabase project (or an
      // account that no longer exists) fails right here rather than at
      // sign-in -- as does a connection that just hangs, now that this is
      // time-bounded. Without this, `profile` never becomes non-null and
      // AuthGate is stuck on its loading spinner forever -- signing out
      // clears the bad session and drops back to the login screen instead.
      debugPrint('ProfileService.load: $error');
      _profile = null;
      // signOut() clears local session state synchronously before it makes
      // its own (separately unbounded) network call -- bounding it here just
      // stops that trailing call from leaving this future pending forever.
      await _client.auth.signOut().timeout(Env.networkTimeout).catchError(
            (_) {},
          );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> completeSetup({
    required String username,
    required String role,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final normalizedUsername = username.trim();
    await _client.from('profiles').update({
      'username': normalizedUsername,
      'role': role,
    }).eq('id', user.id);
    await load();
  }

  Future<List<TrainerProfile>> searchTrainers(String query) async {
    final rows =
        await _client.rpc('search_trainers', params: {'p_query': query});
    return (rows as List)
        .map(
          (row) =>
              TrainerProfile.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  void clear() {
    _profile = null;
    _loading = false;
    notifyListeners();
  }
}
