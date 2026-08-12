import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/trainer_service.dart';
import 'create_challenge_screen.dart';
import 'trainee_workouts_screen.dart';

class TraineesScreen extends StatefulWidget {
  const TraineesScreen({super.key});

  @override
  State<TraineesScreen> createState() => _TraineesScreenState();
}

class _TraineesScreenState extends State<TraineesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrainerService>().loadTrainees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final trainer = context.watch<TrainerService>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${auth.displayName}'),
            Text(
              'Your trainees',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TrainerService>().loadTrainees(),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
        ),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Create challenge'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<TrainerService>().loadTrainees(),
        child: Builder(
          builder: (context) {
            if (trainer.loading && trainer.trainees.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (trainer.trainees.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 56,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No trainees yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When a trainee logs a workout and assigns it to you, '
                    'they appear here.',
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
              itemCount: trainer.trainees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trainee = trainer.trainees[index];
                return Panel(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TraineeWorkoutsScreen(trainee: trainee),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          (trainee.username?.isNotEmpty == true
                                  ? trainee.username![0]
                                  : trainee.fullName?.isNotEmpty == true
                                      ? trainee.fullName![0]
                                      : '?')
                              .toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trainee.displayName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                plural(trainee.workoutCount, 'workout'),
                                if (trainee.latestWorkoutDate != null)
                                  'Last: ${friendlyDate(trainee.latestWorkoutDate!)}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.outline),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
