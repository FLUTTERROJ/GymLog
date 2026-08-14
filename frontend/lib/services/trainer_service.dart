import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workout.dart';

class TraineeSummary {
  const TraineeSummary({
    required this.id,
    required this.username,
    this.fullName,
    required this.workoutCount,
    this.latestWorkoutDate,
  });
  final String id;
  final String? fullName;
  final String? username;
  final int workoutCount;
  final DateTime? latestWorkoutDate;
  factory TraineeSummary.fromMap(Map<String, dynamic> map) => TraineeSummary(
    id: map['id'] as String,
    username: map['username'] as String?,
    fullName: map['full_name'] as String?,
    workoutCount: (map['workout_count'] as num).toInt(),
    latestWorkoutDate: map['latest_workout_date'] == null
        ? null
        : DateTime.parse(map['latest_workout_date'] as String),
  );

  String get displayName {
    if (username != null && username!.isNotEmpty) return username!;
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!.trim();
    return 'Trainee';
  }
}

class TrainerService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  bool loading = false;
  List<TraineeSummary> trainees = const [];

  static const _withSets = '''
id, workout_date, notes, trainer_id,
trainer:profiles!workouts_trainer_id_fkey ( username, full_name ),
workout_sets ( id, exercise_id, set_number, reps, weight_kg, created_at, exercises ( id, name, muscle_group, is_global ) )
''';

  Future<void> loadTrainees() async {
    loading = true; notifyListeners();
    try {
      final rows = await _client.rpc('get_my_trainees');
      trainees = (rows as List).map((row) => TraineeSummary.fromMap(Map<String, dynamic>.from(row as Map))).toList();
    } finally { loading = false; notifyListeners(); }
  }

  Future<List<Workout>> loadWorkouts(String traineeId) async {
    final rows = await _client.from('workouts').select(_withSets).eq('user_id', traineeId).order('workout_date', ascending: false);
    return rows.map((row) => Workout.fromMap(Map<String, dynamic>.from(row))).where((workout) => !workout.isEmpty).toList();
  }

  void clear() {
    trainees = const [];
    loading = false;
    notifyListeners();
  }
}
