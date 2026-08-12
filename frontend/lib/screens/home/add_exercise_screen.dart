import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/auth_service.dart' show describeError;
import '../../services/profile_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_picker.dart';
import '../../widgets/trainer_picker.dart';

/// Composes a complete workout, including multiple exercises and their sets.
class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  late DateTime _date = widget.initialDate ?? today();
  final List<_ExerciseDraft> _exercises = [_ExerciseDraft()];
  TrainerProfile? _trainer;
  bool _saving = false;
  String? _error;

  bool get _isTrainee =>
      !(context.read<ProfileService>().profile?.isTrainer ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillTrainer());
  }

  void _prefillTrainer() {
    final existing =
        context.read<WorkoutService>().workoutForDate(_date);
    if (existing?.trainerId == null) return;
    setState(() {
      _trainer = TrainerProfile(
        id: existing!.trainerId!,
        username: existing.trainerUsername ?? '',
        fullName: existing.trainerFullName,
      );
    });
  }

  @override
  void dispose() {
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today().year - 2),
      lastDate: today(),
      helpText: 'Which day was this?',
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
      _prefillTrainer();
    }
  }

  Future<void> _pickExercise(int index) async {
    final exercise = await showExercisePicker(context);
    if (exercise != null && mounted) {
      setState(() {
        _exercises[index].exercise = exercise;
        _error = null;
      });
    }
  }

  void _addExercise() => setState(() => _exercises.add(_ExerciseDraft()));

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index).dispose();
      if (_exercises.isEmpty) _exercises.add(_ExerciseDraft());
    });
  }

  void _addSet(_ExerciseDraft exercise) {
    setState(() {
      final previous = exercise.sets.last;
      exercise.sets.add(_SetControllers(weight: previous.weight.text));
    });
  }

  void _removeSet(_ExerciseDraft exercise, int index) {
    setState(() {
      exercise.sets.removeAt(index).dispose();
      if (exercise.sets.isEmpty) exercise.sets.add(_SetControllers());
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final workout = <WorkoutExerciseDraft>[];

    for (var exerciseIndex = 0;
        exerciseIndex < _exercises.length;
        exerciseIndex++) {
      final draft = _exercises[exerciseIndex];
      final hasInput = draft.sets.any(
        (set) =>
            set.reps.text.trim().isNotEmpty ||
            set.weight.text.trim().isNotEmpty,
      );
      final exercise = draft.exercise;
      if (exercise == null) {
        if (hasInput) {
          setState(() =>
              _error = 'Exercise ${exerciseIndex + 1}: choose an exercise.',);
          return;
        }
        continue;
      }

      final sets = <SetDraft>[];
      for (var setIndex = 0; setIndex < draft.sets.length; setIndex++) {
        final row = draft.sets[setIndex];
        final repsText = row.reps.text.trim();
        if (repsText.isEmpty) continue;

        final reps = int.tryParse(repsText);
        if (reps == null || reps < 1 || reps > 1000) {
          setState(() => _error =
              '${exercise.name}, set ${setIndex + 1}: reps must be between 1 and 1000.',);
          return;
        }
        final weightText = row.weight.text.trim().replaceAll(',', '.');
        double? weight;
        if (weightText.isNotEmpty) {
          weight = double.tryParse(weightText);
          if (weight == null || weight < 0) {
            setState(() => _error =
                '${exercise.name}, set ${setIndex + 1}: that weight is not a number.',);
            return;
          }
        }
        sets.add(SetDraft(reps: reps, weightKg: weight));
      }

      if (sets.isEmpty) {
        setState(
            () => _error = 'Enter reps for at least one ${exercise.name} set.',);
        return;
      }
      workout.add(WorkoutExerciseDraft(exercise: exercise, sets: sets));
    }

    if (workout.isEmpty) {
      setState(() => _error = 'Add at least one exercise and set.');
      return;
    }

    if (_isTrainee && _trainer == null) {
      setState(() => _error = 'Choose a trainer to assign this workout to.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WorkoutService>().logWorkout(
            date: _date,
            exercises: workout,
            trainerId: _trainer?.id,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = describeError(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add workout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Panel(
            onTap: _pickDate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(Icons.event, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(friendlyDate(_date),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              )),
              const Icon(Icons.chevron_right),
            ]),
          ),
          if (_isTrainee) ...[
            const SizedBox(height: 24),
            TrainerPicker(
              selected: _trainer,
              onSelected: (trainer) => setState(() => _trainer = trainer),
            ),
          ],
          const SizedBox(height: 24),
          Text('Exercises',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Add every exercise in this session, then save once.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _exercises.length; index++) ...[
            _ExerciseSection(
              number: index + 1,
              draft: _exercises[index],
              canRemove: _exercises.length > 1,
              onPickExercise: () => _pickExercise(index),
              onRemoveExercise: () => _removeExercise(index),
              onAddSet: () => _addSet(_exercises[index]),
              onRemoveSet: (setIndex) =>
                  _removeSet(_exercises[index], setIndex),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add another exercise'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(text: _error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving...' : 'Save workout'),
        ),
      ),
    );
  }
}

class _ExerciseDraft {
  Exercise? exercise;
  final List<_SetControllers> sets = [_SetControllers()];

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({
    required this.number,
    required this.draft,
    required this.canRemove,
    required this.onPickExercise,
    required this.onRemoveExercise,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final int number;
  final _ExerciseDraft draft;
  final bool canRemove;
  final VoidCallback onPickExercise;
  final VoidCallback onRemoveExercise;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = draft.exercise;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child:
                  Text('Exercise $number', style: theme.textTheme.labelLarge)),
          if (canRemove)
            IconButton(
              onPressed: onRemoveExercise,
              tooltip: 'Remove exercise $number',
              icon: const Icon(Icons.delete_outline),
            ),
        ]),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onPickExercise,
          icon: const Icon(Icons.fitness_center),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(exercise?.name ?? 'Choose exercise'),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Text('Sets',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Weight optional',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        const SizedBox(height: 10),
        for (var index = 0; index < draft.sets.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SetRow(
              index: index,
              controllers: draft.sets[index],
              canRemove: draft.sets.length > 1,
              onRemove: () => onRemoveSet(index),
              onSubmitted: index == draft.sets.length - 1 ? onAddSet : null,
            ),
          ),
        OutlinedButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add),
            label: const Text('Add set')),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: TextStyle(color: scheme.onErrorContainer))),
      ]),
    );
  }
}

class _SetControllers {
  _SetControllers({String reps = '', String weight = ''})
      : reps = TextEditingController(text: reps),
        weight = TextEditingController(text: weight);

  final TextEditingController reps;
  final TextEditingController weight;

  void dispose() {
    reps.dispose();
    weight.dispose();
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.controllers,
    required this.canRemove,
    required this.onRemove,
    this.onSubmitted,
  });

  final int index;
  final _SetControllers controllers;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      SizedBox(
        width: 34,
        child: Text('${index + 1}',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: theme.colorScheme.outline)),
      ),
      Expanded(
        flex: 3,
        child: TextField(
          controller: controllers.reps,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Reps', isDense: true),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 3,
        child: TextField(
          controller: controllers.weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: const InputDecoration(labelText: 'kg', isDense: true),
        ),
      ),
      SizedBox(
        width: 40,
        child: canRemove
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: theme.colorScheme.outline,
                onPressed: onRemove,
                tooltip: 'Remove set',
              )
            : null,
      ),
    ]);
  }
}
