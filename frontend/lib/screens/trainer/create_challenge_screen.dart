import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/challenge_service.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  static const List<String> _exerciseOptions = [
    'Push-ups',
    'Squats',
    'Lunges',
    'Plank',
    'Burpees',
    'Rows',
    'Deadlifts',
    'Bench Press',
    'Shoulder Press',
    'Pull-ups',
    'Dips',
    'Walking',
    'Cycling',
    'Jogging',
  ];

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final List<ChallengeEntryDraft> _entries = [ChallengeEntryDraft()];
  String? _selectedTraineeId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      context.read<ChallengeService>().clearSearch();
      return;
    }
    setState(() => _searching = true);
    try {
      await context.read<ChallengeService>().searchTrainees(query);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTraineeId == null || _selectedTraineeId!.trim().isEmpty) {
      setState(() => _error = 'Select a trainee first.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Give the challenge a title.');
      return;
    }

    try {
      await context.read<ChallengeService>().createChallenge(
            traineeId: _selectedTraineeId!,
            title: _titleController.text,
            startDate: _startDate,
            endDate: _endDate,
            exercises: _entries,
            notes: _notesController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<ChallengeService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create challenge'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const SizedBox(height: 8),
          Text('Assign to trainee',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Search by username so your trainee can be assigned this challenge.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search trainees',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => _search(),
            onSubmitted: (_) => _search(),
          ),
          if (service.searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...service.searchResults.map((result) {
              final selected = _selectedTraineeId == result.id;
              return InkWell(
                onTap: () => setState(() => _selectedTraineeId = result.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          (result.username ?? result.fullName ?? 'U')
                              .trim()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.label,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (result.fullName != null &&
                                result.fullName!.trim().isNotEmpty)
                              Text(result.fullName!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (_searchController.text.trim().isNotEmpty && !_searching) ...[
            const SizedBox(height: 12),
            Text('No matching trainees found.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 24),
          Text('Exercises',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Add every exercise in this challenge, then save once.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _entries.length; index++) ...[
            _ChallengeExerciseSection(
              number: index + 1,
              draft: _entries[index],
              canRemove: _entries.length > 1,
              onRemove: () => setState(() => _entries.removeAt(index)),
              exerciseOptions: _exerciseOptions,
              onExerciseSelected: (value) {
                setState(() {
                  final entry = _entries[index];
                  if (value == '__custom__') {
                    entry.custom = true;
                    entry.exerciseId = null;
                    entry.name = '';
                    return;
                  }
                  entry.custom = false;
                  entry.exerciseId = value;
                  entry.name = value;
                });
              },
              onCustomChange: (value) {
                setState(() => _entries[index].name = value);
              },
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() => _entries.add(ChallengeEntryDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Add another exercise'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
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
                      size: 20, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
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
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Create challenge'),
        ),
      ),
    );
  }
}

class _ChallengeExerciseSection extends StatelessWidget {
  const _ChallengeExerciseSection({
    required this.number,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.exerciseOptions,
    required this.onExerciseSelected,
    required this.onCustomChange,
  });

  final int number;
  final ChallengeEntryDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final List<String> exerciseOptions;
  final ValueChanged<String> onExerciseSelected;
  final ValueChanged<String> onCustomChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedValue = draft.custom
        ? '__custom__'
        : (draft.exerciseId ?? (draft.name.isNotEmpty ? draft.name : null));

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Exercise $number',
                    style: theme.textTheme.labelLarge),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.outline,
                  tooltip: 'Remove exercise $number',
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedValue,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Choose exercise',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            items: [
              ...exerciseOptions.map(
                (exercise) => DropdownMenuItem<String>(
                  value: exercise,
                  child: Text(exercise),
                ),
              ),
              const DropdownMenuItem<String>(
                value: '__custom__',
                child: Text('Add custom exercise'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onExerciseSelected(value);
            },
          ),
          if (draft.custom || (draft.exerciseId == null && draft.name.isNotEmpty)) ...[
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Custom exercise name'),
              onChanged: onCustomChange,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Sets',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Weight optional',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      draft.reps = int.tryParse(value) ?? 0,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      draft.sets = int.tryParse(value) ?? 0,
                  decoration: const InputDecoration(labelText: 'Sets'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
