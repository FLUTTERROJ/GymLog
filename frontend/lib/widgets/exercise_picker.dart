import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../services/auth_service.dart' show describeError;
import '../services/exercise_service.dart';

/// Opens the searchable exercise list. Resolves to the chosen [Exercise], or
/// `null` if the user backed out.
///
/// A full-screen route rather than a bottom sheet: the list is long, the search
/// field needs the keyboard up the whole time, and this way the OS handles the
/// keyboard inset for us.
Future<Exercise?> showExercisePicker(BuildContext context) {
  return Navigator.of(context).push<Exercise>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ExercisePickerPage(),
    ),
  );
}

class _ExercisePickerPage extends StatefulWidget {
  const _ExercisePickerPage();

  @override
  State<_ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<_ExercisePickerPage> {
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Refresh in the background in case another device added an exercise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExerciseService>().load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create(ExerciseService service) async {
    final name = _query.trim();
    if (name.isEmpty || _creating) return;

    setState(() => _creating = true);
    try {
      final exercise = await service.create(name);
      if (mounted) Navigator.of(context).pop(exercise);
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ExerciseService>();
    final theme = Theme.of(context);
    final rows = _buildRows(service);
    final showCreate =
        _query.trim().isNotEmpty && !service.hasExactMatch(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose exercise'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search or type a new exercise',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (_) {
                if (showCreate) _create(service);
              },
            ),
          ),
          if (showCreate)
            _CreateTile(
              name: _query.trim(),
              busy: _creating,
              onTap: () => _create(service),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (service.isLoading && !service.isLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (service.error != null && !service.isLoaded) {
                  return _PickerMessage(
                    icon: Icons.cloud_off,
                    title: service.error!,
                    action: FilledButton.tonal(
                      onPressed: () => service.load(force: true),
                      child: const Text('Retry'),
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return _PickerMessage(
                    icon: Icons.search_off,
                    title: 'No exercise matches "${_query.trim()}"',
                    subtitle: showCreate
                        ? 'Tap "Add" above to save it to your list.'
                        : null,
                  );
                }
                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is _HeaderRow) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                        child: Text(
                          row.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      );
                    }
                    final exercise = (row as _ExerciseRow).exercise;
                    return ListTile(
                      title: Text(exercise.name),
                      subtitle: exercise.isGlobal
                          ? (exercise.muscleGroup == null
                              ? null
                              : Text(exercise.muscleGroup!))
                          : const Text('Added by you'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(context).pop(exercise),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// With an empty query the full catalogue is shown bucketed by muscle group
  /// (the user's own exercises first). While searching, a flat ranked list is
  /// more useful than headers.
  List<_PickerRow> _buildRows(ExerciseService service) {
    if (_query.trim().isNotEmpty) {
      return service.search(_query).map(_ExerciseRow.new).toList();
    }

    final buckets = <String, List<Exercise>>{};
    for (final exercise in service.exercises) {
      buckets.putIfAbsent(exercise.groupLabel, () => []).add(exercise);
    }

    const mine = 'Your exercises';
    final labels = buckets.keys.toList()
      ..sort((a, b) {
        if (a == mine) return -1;
        if (b == mine) return 1;
        return a.compareTo(b);
      });

    return [
      for (final label in labels) ...[
        _HeaderRow(label),
        ...buckets[label]!.map(_ExerciseRow.new),
      ],
    ];
  }
}

sealed class _PickerRow {
  const _PickerRow();
}

class _HeaderRow extends _PickerRow {
  const _HeaderRow(this.label);
  final String label;
}

class _ExerciseRow extends _PickerRow {
  const _ExerciseRow(this.exercise);
  final Exercise exercise;
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({
    required this.name,
    required this.busy,
    required this.onTap,
  });

  final String name;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(Icons.add_circle_outline, color: scheme.onPrimaryContainer),
        title: Text(
          'Add "$name"',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          'Saves it to your dropdown for next time',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
        onTap: busy ? null : onTap,
      ),
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
