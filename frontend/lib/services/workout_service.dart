import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatting.dart';
import '../models/exercise.dart';
import '../models/workout.dart';

/// One row the user typed into the "add exercise" sheet.
class SetDraft {
  const SetDraft({required this.reps, this.weightKg});

  final int reps;
  final double? weightKg;
}

/// All sets for one exercise while composing a workout.
class WorkoutExerciseDraft {
  const WorkoutExerciseDraft({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<SetDraft> sets;
}

class WorkoutService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  /// Workout + its sets + the exercise behind each set, in one round trip.
  /// PostgREST resolves the nesting from the foreign keys.
  static const String _withSets = '''
id,
workout_date,
notes,
trainer_id,
trainer:profiles!workouts_trainer_id_fkey ( username, full_name ),
workout_sets (
  id,
  exercise_id,
  set_number,
  reps,
  weight_kg,
  created_at,
  exercises ( id, name, muscle_group, is_global )
)
''';

  Workout? _today;
  bool _loadingToday = false;

  List<Workout> _history = const [];
  bool _loadingHistory = false;
  bool _historyLoaded = false;

  String? _error;

  Workout? get todayWorkout => _today;
  bool get isLoadingToday => _loadingToday;

  List<Workout> get history => List.unmodifiable(_history);
  bool get isLoadingHistory => _loadingHistory;
  bool get isHistoryLoaded => _historyLoaded;

  String? get error => _error;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  // ---------------------------------------------------------------- reading

  Future<void> loadToday() async {
    if (_loadingToday) return; // the gate and the home screen both ask on start
    _loadingToday = true;
    _error = null;
    notifyListeners();

    try {
      final row = await _client
          .from('workouts')
          .select(_withSets)
          .eq('user_id', _userId)
          .eq('workout_date', toDateString(today()))
          .maybeSingle();

      _today =
          row == null ? null : Workout.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      _error = 'Could not load today\'s workout.';
      debugPrint('WorkoutService.loadToday: $error');
    } finally {
      _loadingToday = false;
      notifyListeners();
    }
  }

  /// Every day that has at least one set logged, newest first.
  Future<void> loadHistory({int limit = 90}) async {
    if (_loadingHistory) return;
    _loadingHistory = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _client
          .from('workouts')
          .select(_withSets)
          .eq('user_id', _userId)
          .order('workout_date', ascending: false)
          .limit(limit);

      _history = rows
          .map((row) => Workout.fromMap(Map<String, dynamic>.from(row)))
          // A workout row is created the moment the day is opened, so drop the
          // ones where nothing was actually logged.
          .where((workout) => !workout.isEmpty)
          .toList();
      _historyLoaded = true;
    } catch (error) {
      _error = 'Could not load your history.';
      debugPrint('WorkoutService.loadHistory: $error');
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  Workout? workoutById(String id) {
    for (final workout in _history) {
      if (workout.id == id) return workout;
    }
    return _today?.id == id ? _today : null;
  }

  // ---------------------------------------------------------------- writing

  Workout? workoutForDate(DateTime date) {
    final target = toDateString(date);
    if (_today != null && toDateString(_today!.date) == target) return _today;
    for (final workout in _history) {
      if (toDateString(workout.date) == target) return workout;
    }
    return null;
  }

  /// Saves every exercise in a composed workout to the same date.
  Future<void> logWorkout({
    required DateTime date,
    required List<WorkoutExerciseDraft> exercises,
    String? trainerId,
  }) async {
    final entries = exercises.where((entry) => entry.sets.isNotEmpty).toList();
    if (entries.isEmpty) return;

    final workoutRow = await _client.rpc(
      'get_or_create_workout',
      params: {'p_date': toDateString(date)},
    );
    final workoutId = (workoutRow as Map)['id'] as String;
    final nextSetNumbers = <String, int>{};
    final payload = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final existingNext = nextSetNumbers[entry.exercise.id];
      late int next;
      if (existingNext == null) {
        final last = await _client
            .from('workout_sets')
            .select('set_number')
            .eq('workout_id', workoutId)
            .eq('exercise_id', entry.exercise.id)
            .order('set_number', ascending: false)
            .limit(1)
            .maybeSingle();
        next = ((last?['set_number'] as num?)?.toInt() ?? 0) + 1;
      } else {
        next = existingNext;
      }
      for (final set in entry.sets) {
        payload.add({
          'workout_id': workoutId,
          'exercise_id': entry.exercise.id,
          'set_number': next++,
          'reps': set.reps,
          'weight_kg': set.weightKg,
        });
      }
      nextSetNumbers[entry.exercise.id] = next;
    }

    await _client.from('workout_sets').insert(payload);
    if (trainerId != null) {
      await _client
          .from('workouts')
          .update({'trainer_id': trainerId}).eq('id', workoutId);
    }
    await _refreshAfterWrite();
  }

  Future<void> logSets({
    required DateTime date,
    required Exercise exercise,
    required List<SetDraft> sets,
  }) =>
      logWorkout(
        date: date,
        exercises: [WorkoutExerciseDraft(exercise: exercise, sets: sets)],
      );

  Future<void> deleteSet(String setId) async {
    await _client.from('workout_sets').delete().eq('id', setId);
    await _refreshAfterWrite();
  }

  /// Removes every set of one exercise from a day.
  Future<void> deleteExerciseFromWorkout({
    required String workoutId,
    required String exerciseId,
  }) async {
    await _client
        .from('workout_sets')
        .delete()
        .eq('workout_id', workoutId)
        .eq('exercise_id', exerciseId);
    await _refreshAfterWrite();
  }

  Future<void> saveNotes(
      {required DateTime date, required String notes}) async {
    final workoutRow = await _client.rpc(
      'get_or_create_workout',
      params: {'p_date': toDateString(date)},
    );
    final workoutId = (workoutRow as Map)['id'] as String;

    final trimmed = notes.trim();
    await _client.from('workouts').update(
        {'notes': trimmed.isEmpty ? null : trimmed}).eq('id', workoutId);

    await _refreshAfterWrite();
  }

  Future<void> _refreshAfterWrite() async {
    await loadToday();
    if (_historyLoaded) await loadHistory();
  }

  /// Drops the previous user's data on sign-out.
  void clear() {
    _today = null;
    _history = const [];
    _historyLoaded = false;
    _error = null;
    notifyListeners();
  }
}
