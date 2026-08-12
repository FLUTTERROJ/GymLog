import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppProfile {
  const AppProfile({required this.id, this.username, required this.role});

  final String id;
  final String? username;
  final String role;

  bool get isTrainer => role == 'trainer';
  bool get isComplete => username != null && username!.isNotEmpty;

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
        id: map['id'] as String,
        username: map['username'] as String?,
        role: (map['role'] as String?) ?? 'client',
      );
}

class TrainerProfile {
  const TrainerProfile({required this.id, required this.username, this.fullName});
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
      final row = await _client
          .from('profiles')
          .select('id, username, role')
          .eq('id', user.id)
          .maybeSingle();
      _profile = row == null ? null : AppProfile.fromMap(Map<String, dynamic>.from(row));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> completeSetup({required String? username, required String role}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final normalizedUsername = username?.trim();
    final fallbackUsername = 'u_${user.id.replaceAll('-', '').substring(0, 10)}';
    await _client.from('profiles').update({
      'username': role == 'trainer' ? normalizedUsername : fallbackUsername,
      'role': role,
    }).eq('id', user.id);
    await load();
  }

  Future<List<TrainerProfile>> searchTrainers(String query) async {
    final rows = await _client.rpc('search_trainers', params: {'p_query': query});
    return (rows as List)
        .map((row) => TrainerProfile.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  void clear() {
    _profile = null;
    _loading = false;
    notifyListeners();
  }
}
