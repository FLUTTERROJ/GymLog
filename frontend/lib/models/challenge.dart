class ChallengeExercise {
  const ChallengeExercise({
    required this.id,
    required this.name,
    required this.reps,
    required this.sets,
    required this.order,
  });

  final String id;
  final String name;
  final int reps;
  final int sets;
  final int order;

  factory ChallengeExercise.fromMap(Map<String, dynamic> map) =>
      ChallengeExercise(
        id: map['id'] as String,
        name: (map['exercise_name'] ?? map['name'] ?? 'Exercise') as String,
        reps: (map['target_reps'] ?? map['reps'] ?? 0) as int,
        sets: (map['target_sets'] ?? map['sets'] ?? 0) as int,
        order: (map['sort_order'] ?? 0) as int,
      );
}

class MonthlyChallenge {
  const MonthlyChallenge({
    required this.id,
    required this.title,
    required this.trainerId,
    required this.traineeId,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.traineeUsername,
    this.traineeFullName,
    this.exercises = const [],
    this.completedExercisesByDate = const {},
  });

  final String id;
  final String title;
  final String trainerId;
  final String traineeId;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final String? traineeUsername;
  final String? traineeFullName;
  final List<ChallengeExercise> exercises;
  final Map<DateTime, Set<String>> completedExercisesByDate;

  factory MonthlyChallenge.fromMap(Map<String, dynamic> map) {
    final rawExercises = map['challenge_exercises'] as List? ?? const [];
    final rawProgress = map['challenge_completions'] as List? ?? const [];
    final trainee = map['trainee'];

    final completionMap = <DateTime, Set<String>>{};
    for (final row in rawProgress) {
      final progress = Map<String, dynamic>.from(row as Map);
      if (progress['completed'] != true) continue;
      final exerciseId = progress['exercise_id'] as String?;
      final dateValue = progress['completion_date'] as String?;
      if (exerciseId == null || dateValue == null) continue;
      final date = DateTime.parse(dateValue).toLocal();
      completionMap.putIfAbsent(date, () => <String>{}).add(exerciseId);
    }

    return MonthlyChallenge(
      id: map['id'] as String,
      title: map['title'] as String,
      trainerId: map['trainer_id'] as String,
      traineeId: map['trainee_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String).toLocal(),
      endDate: DateTime.parse(map['end_date'] as String).toLocal(),
      notes: map['notes'] as String?,
      traineeUsername: trainee is Map ? (trainee['username'] as String?) : null,
      traineeFullName:
          trainee is Map ? (trainee['full_name'] as String?) : null,
      exercises: rawExercises
          .map((entry) => ChallengeExercise.fromMap(
              Map<String, dynamic>.from(entry as Map)))
          .toList(),
      completedExercisesByDate: completionMap,
    );
  }

  bool isExerciseDone(String exerciseId, DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return completedExercisesByDate[normalized]?.contains(exerciseId) ?? false;
  }

  int countCompletedForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final completedIds =
        completedExercisesByDate[normalized] ?? const <String>{};
    return completedIds.length;
  }

  String get traineeLabel {
    if (traineeUsername != null && traineeUsername!.trim().isNotEmpty) {
      return traineeUsername!.trim();
    }
    if (traineeFullName != null && traineeFullName!.trim().isNotEmpty) {
      return traineeFullName!.trim();
    }
    return 'Trainee';
  }
}
