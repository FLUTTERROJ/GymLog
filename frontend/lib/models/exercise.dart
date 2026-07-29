/// An entry in the exercise dropdown.
///
/// `isGlobal` rows are the catalogue seeded in the database and shared by
/// everyone. The rest are exercises this user added themselves when the
/// dropdown didn't have what they did.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.isGlobal,
    this.muscleGroup,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final bool isGlobal;

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map['id'] as String,
        name: map['name'] as String,
        muscleGroup: map['muscle_group'] as String?,
        isGlobal: (map['is_global'] as bool?) ?? false,
      );

  /// Section header in the picker; custom exercises get their own bucket.
  String get groupLabel => isGlobal ? (muscleGroup ?? 'Other') : 'Your exercises';

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
