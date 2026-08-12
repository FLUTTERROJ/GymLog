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
  final _titleController = TextEditingController();
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
      appBar: AppBar(title: const Text('Create monthly challenge')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Challenge title'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start date'),
                    child: Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'End date'),
                    child: Text(
                        '${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Assign to trainee',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                      labelText: 'Search username or name'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const Text('Searching...')
                      : const Text('Search')),
            ],
          ),
          if (service.searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...service.searchResults.map((result) {
              final selected = _selectedTraineeId == result.id;
              return Panel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => setState(() => _selectedTraineeId = result.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.label,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (result.fullName != null &&
                              result.fullName!.trim().isNotEmpty)
                            Text(result.fullName!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercises',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _entries.add(ChallengeEntryDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      decoration:
                          InputDecoration(labelText: 'Exercise ${index + 1}'),
                      onChanged: (value) => item.name = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 85,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      onChanged: (value) =>
                          item.reps = int.tryParse(value) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 85,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sets'),
                      onChanged: (value) =>
                          item.sets = int.tryParse(value) ?? 0,
                    ),
                  ),
                  if (_entries.length > 1)
                    IconButton(
                      onPressed: () => setState(() => _entries.removeAt(index)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Create challenge'),
          ),
        ],
      ),
    );
  }
}
