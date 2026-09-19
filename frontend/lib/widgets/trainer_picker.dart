import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/profile_service.dart';

/// Lets a trainee search trainers by username and pick one.
class TrainerPicker extends StatefulWidget {
  const TrainerPicker({
    super.key,
    this.selected,
    required this.onSelected,
  });

  final TrainerProfile? selected;
  final ValueChanged<TrainerProfile?> onSelected;

  @override
  State<TrainerPicker> createState() => _TrainerPickerState();
}

class _TrainerPickerState extends State<TrainerPicker> {
  final _query = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _searching = false;
  List<TrainerProfile> _results = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _query.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() {
        _error = null;
      });
      _search(_query.text);
      return;
    }

    _debounce?.cancel();
    setState(() {
      _results = const [];
      _error = null;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (!_focusNode.hasFocus) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results =
          await context.read<ProfileService>().searchTrainers(query.trim());
      if (mounted && _focusNode.hasFocus) {
        setState(() => _results = results);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not search trainers.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectTrainer(TrainerProfile trainer) {
    widget.onSelected(trainer);
    _query.clear();
    _focusNode.unfocus();
    setState(() => _results = const []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign to trainer',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Search by username so your trainer can review this workout.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 14),
          if (selected != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(
                  selected.username.isNotEmpty
                      ? selected.username[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(selected.username),
              subtitle: selected.fullName == null
                  ? null
                  : Text(selected.fullName!),
              trailing: IconButton(
                tooltip: 'Clear trainer',
                icon: const Icon(Icons.close),
                onPressed: () => widget.onSelected(null),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _query,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: 'Search trainers',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onQueryChanged,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_focusNode.hasFocus && _results.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final trainer in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    trainer.username.isNotEmpty
                        ? trainer.username[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(trainer.username),
                subtitle:
                    trainer.fullName == null ? null : Text(trainer.fullName!),
                trailing: selected?.id == trainer.id
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => _selectTrainer(trainer),
              ),
          ],
        ],
      ),
    );
  }
}
