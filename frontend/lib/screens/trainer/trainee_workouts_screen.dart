import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/trainer_service.dart';
import '../../widgets/exercise_group_card.dart';

class TraineeWorkoutsScreen extends StatefulWidget {
  const TraineeWorkoutsScreen({super.key, required this.trainee});

  final TraineeSummary trainee;

  @override
  State<TraineeWorkoutsScreen> createState() => _TraineeWorkoutsScreenState();
}

class _TraineeWorkoutsScreenState extends State<TraineeWorkoutsScreen> {
  bool _loading = true;
  List<Workout> _workouts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workouts = await context
          .read<TrainerService>()
          .loadWorkouts(widget.trainee.id);
      if (mounted) setState(() => _workouts = workouts);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load workouts.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.trainee.displayName)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_loading && _workouts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null) {
              return ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(onPressed: _load, child: const Text('Retry')),
                  ),
                ],
              );
            }

            if (_workouts.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 56,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No workouts assigned yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _WorkoutDayCard(workout: workout),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WorkoutDayCard extends StatelessWidget {
  const _WorkoutDayCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = workout.notes?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          friendlyDate(workout.date),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          [
            plural(workout.groups.length, 'exercise'),
            plural(workout.sets.length, 'set'),
            '${workout.totalReps} reps',
          ].join(' · '),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        for (final group in workout.groups) ...[
          ExerciseGroupCard(group: group),
          const SizedBox(height: 12),
        ],
        if (notes != null && notes.isNotEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 18, color: theme.colorScheme.outline),
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
    );
  }
}
