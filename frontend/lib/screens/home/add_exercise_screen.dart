import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/auth_service.dart' show describeError;
import '../../services/workout_service.dart';
import '../../widgets/exercise_picker.dart';

/// "What did you do?" — pick an exercise, then add one row per set.
///
/// Pops `true` once something was saved, so the caller knows to refresh.
class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  late DateTime _date = widget.initialDate ?? today();
  Exercise? _exercise;
  final List<_SetControllers> _sets = [_SetControllers()];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final set in _sets) {
      set.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final exercise = await showExercisePicker(context);
    if (exercise != null && mounted) {
      setState(() {
        _exercise = exercise;
        _error = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today().year - 2),
      lastDate: today(), // no logging workouts you haven't done yet
      helpText: 'Which day was this?',
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _addSet() {
    setState(() {
      // Carry the last set's weight forward — usually the same across sets.
      final previous = _sets.isEmpty ? null : _sets.last;
      _sets.add(_SetControllers(weight: previous?.weight.text ?? ''));
    });
  }

  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index).dispose();
      if (_sets.isEmpty) _sets.add(_SetControllers());
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final exercise = _exercise;
    if (exercise == null) {
      setState(() => _error = 'Pick an exercise first.');
      return;
    }

    final drafts = <SetDraft>[];
    for (var i = 0; i < _sets.length; i++) {
      final repsText = _sets[i].reps.text.trim();
      if (repsText.isEmpty) continue; // ignore rows left blank

      final reps = int.tryParse(repsText);
      if (reps == null || reps < 1 || reps > 1000) {
        setState(() => _error = 'Set ${i + 1}: reps must be between 1 and 1000.');
        return;
      }

      final weightText = _sets[i].weight.text.trim().replaceAll(',', '.');
      double? weight;
      if (weightText.isNotEmpty) {
        weight = double.tryParse(weightText);
        if (weight == null || weight < 0) {
          setState(() => _error = 'Set ${i + 1}: that weight isn\'t a number.');
          return;
        }
      }

      drafts.add(SetDraft(reps: reps, weightKg: weight));
    }

    if (drafts.isEmpty) {
      setState(() => _error = 'Enter the reps for at least one set.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<WorkoutService>().logSets(
            date: _date,
            exercise: exercise,
            sets: drafts,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add exercise'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // ------------------------------------------------------------ date
          Panel(
            onTap: _pickDate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.event, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        friendlyDate(_date),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------- exercise
          Panel(
            onTap: _pickExercise,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exercise', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        _exercise?.name ?? 'Tap to search…',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _exercise == null
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Sets',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Weight optional',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (var i = 0; i < _sets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SetRow(
                index: i,
                controllers: _sets[i],
                canRemove: _sets.length > 1,
                onRemove: () => _removeSet(i),
                onSubmitted: i == _sets.length - 1 ? _addSet : null,
              ),
            ),

          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _addSet,
            icon: const Icon(Icons.add),
            label: const Text('Add another set'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 20, color: theme.colorScheme.onErrorContainer,),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
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
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving…' : 'Save to workout'),
        ),
      ),
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

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '${index + 1}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controllers.reps,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Reps',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controllers.weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            decoration: const InputDecoration(
              labelText: 'kg',
              isDense: true,
            ),
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
      ],
    );
  }
}
