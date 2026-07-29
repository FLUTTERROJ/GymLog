import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart' show describeError;
import '../../services/workout_service.dart';
import '../../widgets/exercise_group_card.dart';
import '../home/add_exercise_screen.dart';

/// A single past day, in full.
///
/// Reads the workout out of [WorkoutService] by id rather than taking the
/// object, so edits made here are reflected without passing anything back up.
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  Future<void> _addToThisDay(BuildContext context, DateTime date) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddExerciseScreen(initialDate: date),
      ),
    );
  }

  Future<void> _deleteGroup(
    BuildContext context, {
    required String exerciseId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content:
            const Text('Every set logged for it that day will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<WorkoutService>().deleteExerciseFromWorkout(
            workoutId: workoutId,
            exerciseId: exerciseId,
          );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workouts = context.watch<WorkoutService>();
    final workout = workouts.workoutById(workoutId);

    if (workout == null) {
      // Every exercise was deleted, so the day dropped out of the history list.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'This workout is no longer available.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ),
      );
    }

    final notes = workout.notes?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(friendlyDate(workout.date))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addToThisDay(context, workout.date),
        icon: const Icon(Icons.add),
        label: const Text('Add to workout'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Metric(
                  value: '${workout.groups.length}',
                  label: workout.groups.length == 1 ? 'exercise' : 'exercises',
                ),
                _Metric(
                  value: '${workout.sets.length}',
                  label: workout.sets.length == 1 ? 'set' : 'sets',
                ),
                _Metric(value: '${workout.totalReps}', label: 'total reps'),
                if (workout.totalVolume > 0)
                  _Metric(
                    value: formatWeight(workout.totalVolume),
                    label: 'kg volume',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final group in workout.groups) ...[
            ExerciseGroupCard(
              group: group,
              onDelete: () => _deleteGroup(
                context,
                exerciseId: group.exerciseId,
                name: group.name,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text('Notes', style: theme.textTheme.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(notes, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
