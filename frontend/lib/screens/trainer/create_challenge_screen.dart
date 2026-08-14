import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
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
  final List<ChallengeProfileSearchResult> _selectedTrainees = [];
  DateTime _startDate = today();
  DateTime _endDate = today().add(const Duration(days: 30));
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

  void _addTrainee(ChallengeProfileSearchResult trainee) {
    setState(() {
      if (!_selectedTrainees.any((t) => t.id == trainee.id)) {
        _selectedTrainees.add(trainee);
      }
      _error = null;
      _searchController.clear();
    });
    context.read<ChallengeService>().clearSearch();
  }

  void _removeTrainee(String traineeId) {
    setState(() => _selectedTrainees.removeWhere((t) => t.id == traineeId));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: today().subtract(const Duration(days: 365)),
      lastDate: today().add(const Duration(days: 730)),
      helpText: 'When does the challenge start?',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: today().add(const Duration(days: 730)),
      helpText: 'When does the challenge end?',
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _submit() async {
    if (_selectedTrainees.isEmpty) {
      setState(() => _error = 'Select at least one trainee.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Give the challenge a title.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date must be on or after the start date.');
      return;
    }

    setState(() => _error = null);

    try {
      await context.read<ChallengeService>().createChallenge(
            traineeIds: _selectedTrainees.map((t) => t.id).toList(),
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
    final results = service.searchResults
        .where((r) => !_selectedTrainees.any((t) => t.id == r.id))
        .toList();
    final query = _searchController.text.trim();

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
          Text('Challenge title',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. August Strength Challenge',
            ),
          ),

          const SizedBox(height: 28),
          Text('Assign to trainees',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Search by username, tap to add. You can add more than one.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          if (_selectedTrainees.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final trainee in _selectedTrainees)
                  InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        trainee.label.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    label: Text(trainee.label),
                    onDeleted: () => _removeTrainee(trainee.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search trainees',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => _search(),
            onSubmitted: (_) => _search(),
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...results.map((result) {
              return InkWell(
                onTap: () => _addTrainee(result),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          result.label.substring(0, 1).toUpperCase(),
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
                      Icon(Icons.add_circle_outline,
                          color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              );
            }),
          ] else if (query.isNotEmpty && !_searching) ...[
            const SizedBox(height: 12),
            Text('No matching trainees found.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],

          const SizedBox(height: 28),
          Text('Duration',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'When does this challenge run?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Panel(
                  onTap: _pickStartDate,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Starts', style: theme.textTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        friendlyDate(_startDate),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Panel(
                  onTap: _pickEndDate,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Ends', style: theme.textTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        friendlyDate(_endDate),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
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
