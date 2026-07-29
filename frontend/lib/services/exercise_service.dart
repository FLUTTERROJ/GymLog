import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exercise.dart';

/// Backs the searchable exercise dropdown.
///
/// The catalogue is small (a few hundred rows at most) and changes rarely, so
/// it is fetched once and searched in memory — the picker stays responsive on
/// every keystroke without hitting the network.
class ExerciseService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Exercise> _exercises = const [];
  bool _loading = false;
  String? _error;

  List<Exercise> get exercises => List.unmodifiable(_exercises);
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isLoaded => _exercises.isNotEmpty;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_exercises.isNotEmpty && !force) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _client
          .from('exercises')
          .select('id, name, muscle_group, is_global')
          .order('name');

      _exercises = rows
          .map((row) => Exercise.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      _error = 'Could not load exercises.';
      debugPrint('ExerciseService.load: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Drops the previous user's catalogue on sign-out — it contains their
  /// private additions.
  void clear() {
    _exercises = const [];
    _error = null;
    notifyListeners();
  }

  /// Case-insensitive substring match, with prefix matches ranked first so
  /// typing "bench" surfaces "Bench Press" above "Close Grip Bench Press".
  List<Exercise> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return exercises;

    final prefix = <Exercise>[];
    final contains = <Exercise>[];
    for (final exercise in _exercises) {
      final name = exercise.name.toLowerCase();
      if (name.startsWith(q)) {
        prefix.add(exercise);
      } else if (name.contains(q)) {
        contains.add(exercise);
      }
    }
    return [...prefix, ...contains];
  }

  bool hasExactMatch(String query) {
    final q = query.trim().toLowerCase();
    return _exercises.any((e) => e.name.toLowerCase() == q);
  }

  /// Adds an exercise the catalogue didn't have.
  ///
  /// Goes through the `add_exercise` RPC, which returns the existing row if the
  /// name is already taken — that's what keeps "Bench Press" and "bench press"
  /// from both ending up in the dropdown.
  Future<Exercise> create(String name, {String? muscleGroup}) async {
    final row = await _client.rpc(
      'add_exercise',
      params: {'p_name': name, 'p_muscle_group': muscleGroup},
    );

    final exercise = Exercise.fromMap(Map<String, dynamic>.from(row as Map));

    if (!_exercises.any((e) => e.id == exercise.id)) {
      _exercises = [..._exercises, exercise]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    }
    return exercise;
  }
}
