import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../core/theme.dart';
import '../models/workout.dart';

/// One exercise inside a day, with a chip per set.
class ExerciseGroupCard extends StatelessWidget {
  const ExerciseGroupCard({
    super.key,
    required this.group,
    this.onDelete,
  });

  final ExerciseGroup group;

  /// When null the card is read-only (used in the trainer-style history view).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        plural(group.sets.length, 'set'),
                        '${group.totalReps} reps',
                        if (group.volume > 0)
                          '${formatWeight(group.volume)} kg total',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.outline,
                  tooltip: 'Remove ${group.name}',
                  onPressed: onDelete,
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final set in group.sets)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      set.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
