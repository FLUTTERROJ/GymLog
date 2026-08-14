import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/challenge.dart';
import '../../services/challenge_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengeService>().loadChallenges();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<ChallengeService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly challenges'),
      ),
      body: RefreshIndicator(
        onRefresh: () => service.loadChallenges(),
        child: service.loading && service.challenges.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : service.challenges.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      Icon(Icons.flag_outlined,
                          size: 58, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 18),
                      Text(
                        'No challenges yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your trainer can assign a challenge here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: service.challenges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final challenge = service.challenges[index];
                      return Panel(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MonthlyChallengeDetailScreen(
                                challenge: challenge),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${friendlyDate(challenge.startDate)} – ${friendlyDate(challenge.endDate)}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.fitness_center_outlined,
                                    size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text('${challenge.exercises.length} exercises',
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class MonthlyChallengeDetailScreen extends StatefulWidget {
  const MonthlyChallengeDetailScreen({super.key, required this.challenge});

  final MonthlyChallenge challenge;

  @override
  State<MonthlyChallengeDetailScreen> createState() =>
      _MonthlyChallengeDetailScreenState();
}

class _MonthlyChallengeDetailScreenState
    extends State<MonthlyChallengeDetailScreen> {
  late DateTime _selectedDate;

  bool get _isFutureDate => _selectedDate.isAfter(today());

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.challenge.startDate;
    if (_selectedDate.isBefore(DateTime.now())) {
      _selectedDate = DateTime.now();
    }
    if (_selectedDate.isAfter(widget.challenge.endDate)) {
      _selectedDate = widget.challenge.endDate;
    }
  }

  Future<void> _toggleExercise(ChallengeExercise exercise, bool value) async {
    if (_isFutureDate) return; // belt-and-braces; the checkbox is disabled too
    await context.read<ChallengeService>().toggleCompletion(
          challengeId: widget.challenge.id,
          exerciseId: exercise.id,
          date: _selectedDate,
          completed: value,
        );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // toggleCompletion() reloads ChallengeService.challenges into fresh
    // objects; widget.challenge is the snapshot from when this screen was
    // opened and never gets those updates, so pull the live one back out by
    // id instead of trusting it for anything completion-related.
    final service = context.watch<ChallengeService>();
    final challenge = service.challenges.firstWhere(
      (c) => c.id == widget.challenge.id,
      orElse: () => widget.challenge,
    );
    final totalDays =
        challenge.endDate.difference(challenge.startDate).inDays + 1;

    Future<void> moveDay(int delta) async {
      final date = _selectedDate.add(Duration(days: delta));
      if (date.isBefore(challenge.startDate)) return;
      if (date.isAfter(challenge.endDate)) return;
      setState(() => _selectedDate = date);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(challenge.title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Exercises'),
              Tab(text: 'Calendar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => moveDay(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('d MMM').format(_selectedDate),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => moveDay(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isFutureDate) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "This day hasn't happened yet, so it can't be "
                            'ticked off until it arrives.',
                            style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (challenge.exercises.isEmpty)
                  Text('No exercises assigned yet.',
                      style: theme.textTheme.bodyMedium)
                else ...[
                  for (final exercise in challenge.exercises) ...[
                    Panel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: CheckboxListTile(
                        value: challenge.isExerciseDone(
                            exercise.id, _selectedDate),
                        onChanged: _isFutureDate
                            ? null
                            : (value) =>
                                _toggleExercise(exercise, value == true),
                        title: Text(exercise.name),
                        subtitle: Text(
                            '${exercise.reps} reps • ${exercise.sets} sets'),
                        secondary: _isFutureDate
                            ? Icon(Icons.lock_outline,
                                color: theme.colorScheme.outline)
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Daily progress',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (challenge.exercises.isEmpty)
                  Text('No exercises yet.')
                else ...[
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                    children: List.generate(totalDays, (index) {
                      final date =
                          challenge.startDate.add(Duration(days: index));
                      final count = challenge.countCompletedForDate(date);
                      final total = challenge.exercises.length;
                      final active = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final done = total > 0 && count >= total;
                      final partial = total > 0 && count > 0 && count < total;

                      return Container(
                        decoration: BoxDecoration(
                          color: done
                              ? theme.colorScheme.primaryContainer
                              : partial
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: active
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 2)
                              : null,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${date.day}',
                                style: theme.textTheme.labelLarge),
                            const SizedBox(height: 4),
                            Text(
                              total == 0 ? '0' : '$count/$total',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
