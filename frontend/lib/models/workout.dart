import '../core/formatting.dart';
import 'exercise.dart';

/// One set actually performed.
class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.reps,
    required this.exercise,
    required this.createdAt,
    this.weightKg,
  });

  final String id;
  final String exerciseId;
  final int setNumber;
  final int reps;
  final double? weightKg;
  final DateTime createdAt;

  /// Joined in by the query; null only if the embed was skipped.
  final Exercise? exercise;

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    final embedded = map['exercises'];
    return WorkoutSet(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      setNumber: (map['set_number'] as num).toInt(),
      reps: (map['reps'] as num).toInt(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      exercise: embedded is Map
          ? Exercise.fromMap(Map<String, dynamic>.from(embedded))
          : null,
    );
  }

  /// "12 × 40 kg", or just "12 reps" for bodyweight work.
  String get label => weightKg == null
      ? '$reps reps'
      : '$reps × ${formatWeight(weightKg!)} kg';

  double get volume => (weightKg ?? 0) * reps;
}

/// All the sets of one exercise within a single day, in the order performed.
class ExerciseGroup {
  ExerciseGroup({required this.exerciseId, required this.name, required this.sets});

  final String exerciseId;
  final String name;
  final List<WorkoutSet> sets;

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);
  double get volume => sets.fold(0.0, (sum, s) => sum + s.volume);
}

/// A single day of training.
class Workout {
  const Workout({
    required this.id,
    required this.date,
    required this.sets,
    this.notes,
  });

  final String id;
  final DateTime date;
  final String? notes;
  final List<WorkoutSet> sets;

  factory Workout.fromMap(Map<String, dynamic> map) {
    final rawSets = (map['workout_sets'] as List?) ?? const [];
    // Ordered by when they were logged, so exercises stay grouped in the order
    // the user did them rather than interleaving by set number.
    final sets = rawSets
        .map((e) => WorkoutSet.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.setNumber.compareTo(b.setNumber);
      });

    return Workout(
      id: map['id'] as String,
      date: parseDate(map['workout_date'] as String),
      notes: map['notes'] as String?,
      sets: sets,
    );
  }

  bool get isEmpty => sets.isEmpty;

  /// Sets folded back under their exercise, first-logged first.
  List<ExerciseGroup> get groups {
    final byExercise = <String, ExerciseGroup>{};
    for (final set in sets) {
      byExercise
          .putIfAbsent(
            set.exerciseId,
            () => ExerciseGroup(
              exerciseId: set.exerciseId,
              name: set.exercise?.name ?? 'Unknown exercise',
              sets: [],
            ),
          )
          .sets
          .add(set);
    }
    return byExercise.values.toList();
  }

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);
  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);
}
