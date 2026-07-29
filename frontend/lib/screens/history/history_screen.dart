import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workouts = context.read<WorkoutService>();
      if (!workouts.isHistoryLoaded) workouts.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workouts = context.watch<WorkoutService>();
    final days = workouts.history;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<WorkoutService>().loadHistory(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<WorkoutService>().loadHistory(),
        child: Builder(
          builder: (context) {
            if (workouts.isLoadingHistory && days.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (days.isEmpty) {
              // Must stay scrollable or pull-to-refresh stops working.
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                children: [
                  Icon(
                    Icons.history,
                    size: 56,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No past workouts yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Once you log a session it shows up here, '
                    'newest day first.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.45,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _DayCard(workout: days[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = workout.groups;
    final names = groups.map((g) => g.name).toList();
    final preview = names.length <= 3
        ? names.join(' · ')
        : '${names.take(3).join(' · ')} +${names.length - 3} more';

    return Panel(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workoutId: workout.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  friendlyDate(workout.date),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            preview,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(text: plural(groups.length, 'exercise')),
              _Pill(text: plural(workout.sets.length, 'set')),
              _Pill(text: '${workout.totalReps} reps'),
              if (workout.totalVolume > 0)
                _Pill(text: '${formatWeight(workout.totalVolume)} kg'),
              if (workout.notes != null && workout.notes!.trim().isNotEmpty)
                const _Pill(text: 'Has notes', icon: Icons.sticky_note_2_outlined),
              if (workout.trainerLabel != null)
                _Pill(text: workout.trainerLabel!, icon: Icons.fitness_center),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
