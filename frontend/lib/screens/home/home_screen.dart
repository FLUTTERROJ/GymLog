import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_group_card.dart';
import 'add_exercise_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutService>().loadToday();
    });
  }

  Future<void> _addExercise() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AddExerciseScreen(),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    }
  }

  Future<void> _editNotes() async {
    final workouts = context.read<WorkoutService>();
    final controller =
        TextEditingController(text: workouts.todayWorkout?.notes ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notes for your trainer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'How did the session feel? Any niggles?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null || !mounted) return;

    try {
      await workouts.saveNotes(date: today(), notes: result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(error))));
      }
    }
  }

  Future<void> _confirmDeleteGroup(
    String workoutId,
    String exerciseId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content:
            const Text('Every set you logged for it today will be deleted.'),
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

    if (confirmed != true || !mounted) return;

    try {
      await context.read<WorkoutService>().deleteExerciseFromWorkout(
            workoutId: workoutId,
            exerciseId: exerciseId,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final workouts = context.watch<WorkoutService>();
    final workout = workouts.todayWorkout;
    final groups = workout?.groups ?? const [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${auth.displayName}'),
            Text(
              DateFormat('EEEE, d MMMM').format(today()),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add workout'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<WorkoutService>().loadToday(),
        child: workouts.isLoadingToday && workout == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  if (groups.isEmpty)
                    _EmptyToday(onAdd: _addExercise)
                  else ...[
                    _TodaySummary(workout: workout!),
                    if (workout.trainerLabel != null) ...[
                      const SizedBox(height: 12),
                      _TrainerChip(label: workout.trainerLabel!),
                    ],
                    const SizedBox(height: 20),
                    for (final group in groups) ...[
                      ExerciseGroupCard(
                        group: group,
                        onDelete: () => _confirmDeleteGroup(
                          workout.id,
                          group.exerciseId,
                          group.name,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    _NotesCard(
                      notes: workout.notes,
                      onTap: _editNotes,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TrainerChip extends StatelessWidget {
  const _TrainerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.fitness_center, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assigned to $label',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat(value: '${workout.groups.length}', label: 'exercises'),
      _Stat(value: '${workout.sets.length}', label: 'sets'),
      _Stat(value: '${workout.totalReps}', label: 'reps'),
      if (workout.totalVolume > 0)
        _Stat(value: formatWeight(workout.totalVolume), label: 'kg volume'),
    ];

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const _StatDivider(),
            Expanded(child: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.onTap});

  final String? notes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNotes = notes != null && notes!.trim().isNotEmpty;

    return Panel(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, color: theme.colorScheme.outline),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes for your trainer',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  hasNotes ? notes!.trim() : 'Add a note about this session',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasNotes
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center,
            size: 56,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 18),
          Text(
            'Nothing logged yet today',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Add every exercise you did and the reps for each set. '
              'Your trainer sees it as soon as you save.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.45),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Log your workout'),
            ),
          ),
        ],
      ),
    );
  }
}
