import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';

class ChallengeEntryDraft {
  ChallengeEntryDraft({
    this.exerciseId,
    this.name = '',
    this.reps = 10,
    this.sets = 3,
    this.custom = false,
  });

  String? exerciseId;
  String name;
  int reps;
  int sets;
  bool custom;
}

class ChallengeProfileSearchResult {
  const ChallengeProfileSearchResult({
    required this.id,
    this.username,
    this.fullName,
  });

  final String id;
  final String? username;
  final String? fullName;

  factory ChallengeProfileSearchResult.fromMap(Map<String, dynamic> map) =>
      ChallengeProfileSearchResult(
        id: map['id'] as String,
        username: map['username'] as String?,
        fullName: map['full_name'] as String?,
      );

  String get label {
    if (username != null && username!.trim().isNotEmpty) return username!.trim();
    if (fullName != null && fullName!.trim().isNotEmpty)
      return fullName!.trim();
    return 'User';
  }
}

class ChallengeService extends ChangeNotifier {
  final _client = Supabase.instance.client;

  bool loading = false;
  List<MonthlyChallenge> challenges = const [];
  List<ChallengeProfileSearchResult> searchResults = const [];

  Future<void> loadChallenges() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    loading = true;
    notifyListeners();

    try {
      final rows = await _client.from('monthly_challenges').select('''
            id,
            title,
            trainer_id,
            trainee_id,
            start_date,
            end_date,
            trainee:profiles!monthly_challenges_trainee_id_fkey(id, username, full_name),
            challenge_exercises (
              id,
              exercise_name,
              target_reps,
              target_sets,
              sort_order
            ),
            challenge_completions (
              exercise_id,
              completion_date,
              completed
            )
          ''').eq('trainee_id', user.id).order('start_date', ascending: false);

      challenges = (rows as List)
          .map((row) =>
              MonthlyChallenge.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (error) {
      debugPrint('ChallengeService.loadChallenges: $error');
      challenges = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<ChallengeProfileSearchResult>> searchTrainees(
      String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      searchResults = const [];
      notifyListeners();
      return const [];
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('profiles')
        .select('id, username, full_name')
        .neq('id', userId)
        .eq('role', 'trainee')
        .eq('trainer_id', userId)
        .limit(200);

    final matches = (rows as List)
        .map((row) => ChallengeProfileSearchResult.fromMap(
            Map<String, dynamic>.from(row as Map)))
        .where((user) {
          final haystack = [user.username ?? '', user.fullName ?? '']
              .join(' ')
              .toLowerCase();
          return haystack.contains(trimmed.toLowerCase());
        })
        .take(12)
        .toList();

    final results = matches;

    searchResults = results;
    notifyListeners();
    return results;
  }

  Future<void> createChallenge({
    required String traineeId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<ChallengeEntryDraft> exercises,
    String? notes,
  }) async {
    if (title.trim().isEmpty) {
      throw StateError('Challenge title is required.');
    }
    if (traineeId.isEmpty) {
      throw StateError('Select a trainee.');
    }
    final validExercises = exercises
        .where((entry) =>
            entry.name.trim().isNotEmpty && entry.reps > 0 && entry.sets > 0)
        .toList();
    if (validExercises.isEmpty) {
      throw StateError('Add at least one exercise target.');
    }

    final trainerId = _client.auth.currentUser?.id;
    if (trainerId == null) throw StateError('Not signed in.');

    final challengeRow = await _client
        .from('monthly_challenges')
        .insert({
          'trainer_id': trainerId,
          'trainee_id': traineeId,
          'title': title.trim(),
          'start_date': startDate.toIso8601String().split('T').first,
          'end_date': endDate.toIso8601String().split('T').first,
          'notes':
              notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
        })
        .select()
        .single();

    final challengeId = challengeRow['id'] as String;
    final payload = validExercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      return {
        'challenge_id': challengeId,
        'exercise_name': exercise.name.trim(),
        'target_reps': exercise.reps,
        'target_sets': exercise.sets,
        'sort_order': index,
      };
    }).toList();

    await _client.from('challenge_exercises').insert(payload);
  }

  Future<void> toggleCompletion({
    required String challengeId,
    required String exerciseId,
    required DateTime date,
    required bool completed,
  }) async {
    final payload = {
      'challenge_id': challengeId,
      'exercise_id': exerciseId,
      'completion_date': date.toIso8601String().split('T').first,
      'completed': completed,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('challenge_completions').upsert(payload,
        onConflict: 'challenge_id,exercise_id,completion_date');

    await loadChallenges();
  }

  Future<int> getCompletionCount({
    required String challengeId,
    required String exerciseId,
    required DateTime date,
  }) async {
    final rows = await _client
        .from('challenge_completions')
        .select('id')
        .eq('challenge_id', challengeId)
        .eq('exercise_id', exerciseId)
        .eq('completion_date', date.toIso8601String().split('T').first)
        .eq('completed', true);
    return (rows as List).length;
  }

  void clearSearch() {
    searchResults = const [];
    notifyListeners();
  }
}
