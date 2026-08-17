import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart' show describeError;
import '../../services/calendar_service.dart';
import '../../services/trainer_service.dart';

/// Connect Google Calendar, map the names it uses to real trainee accounts,
/// and see what tomorrow's reminder run will actually send.
class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  State<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calendar = context.read<CalendarService>();
      calendar.loadStatus();
      calendar.loadMappings();
      if (calendar.status.connected) calendar.fetchPreview();
    });
  }

  Future<void> _connect() async {
    final calendar = context.read<CalendarService>();
    try {
      await calendar.connect();
      if (calendar.status.connected) await calendar.fetchPreview();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(error))));
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Reminders will stop going out until you reconnect. Your saved '
          'name mappings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<CalendarService>().disconnect();
  }

  Future<void> _mapName(String calendarName) async {
    final trainees = context.read<TrainerService>().trainees;
    if (trainees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No trainees yet — a trainee has to log a workout and assign it '
            'to you before you can map names to them.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<TraineeSummary>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Who is "$calendarName"?',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final trainee in trainees)
              ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (trainee.username?.isNotEmpty == true
                            ? trainee.username![0]
                            : '?')
                        .toUpperCase(),
                  ),
                ),
                title: Text(trainee.displayName),
                onTap: () => Navigator.of(sheetContext).pop(trainee),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    try {
      await context.read<CalendarService>().saveMapping(
            calendarName: calendarName,
            traineeId: selected.id,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendar = context.watch<CalendarService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar reminders')),
      body: RefreshIndicator(
        onRefresh: () async {
          await calendar.loadStatus();
          await calendar.loadMappings();
          if (calendar.status.connected) await calendar.fetchPreview();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _ConnectionCard(
              status: calendar.status,
              busy: calendar.connecting || calendar.loadingStatus,
              onConnect: _connect,
              onDisconnect: _disconnect,
            ),
            if (calendar.status.connected) ...[
              const SizedBox(height: 24),
              Text(
                "Tomorrow's sessions",
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Read live from your calendar — mapped names will get a '
                'reminder email the evening before.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              if (calendar.loadingPreview)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (calendar.previewError != null)
                Text(calendar.previewError!,
                    style: TextStyle(color: theme.colorScheme.error))
              else if (calendar.preview.sessions.isEmpty)
                Panel(
                  child: Text(
                    'Nothing on your calendar for tomorrow that matches the '
                    '"Name : Paid/Unpaid : Location" format.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              else
                for (final session in calendar.preview.sessions) ...[
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEE, d MMM · h:mm a').format(session.start),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('${session.names.join(", ")} · ${session.paidStatus} · '
                            '${session.location}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 24),
              Text(
                'Names from your calendar',
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Map each one to a trainee once — the app remembers it after '
                'that.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              if (calendar.preview.names.isEmpty && !calendar.loadingPreview)
                Panel(
                  child: Text(
                    'No names detected yet — they show up here once you '
                    'have sessions on the calendar for tomorrow.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              else
                for (final name in calendar.preview.names) ...[
                  Panel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onTap: name.mapped ? null : () => _mapName(name.name),
                    child: Row(
                      children: [
                        Icon(
                          name.mapped
                              ? Icons.check_circle
                              : Icons.help_outline,
                          color: name.mapped
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.name,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              if (name.mapped)
                                Text('Mapped to ${name.traineeLabel ?? "a trainee"}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline)),
                            ],
                          ),
                        ),
                        if (!name.mapped)
                          Text('Tap to map',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              if (calendar.mappings.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'All saved mappings',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final mapping in calendar.mappings) ...[
                  Panel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${mapping.calendarName} → ${mapping.traineeLabel ?? "?"}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove mapping',
                          onPressed: () => context
                              .read<CalendarService>()
                              .removeMapping(mapping.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.status,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
  });

  final CalendarConnectionStatus status;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.connected ? 'Connected' : 'Not connected',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.connected
                ? 'Reading sessions from ${status.googleEmail ?? "your Google Calendar"}. '
                    'Trainees with a mapped name get an email the evening before their session.'
                : 'Connect your Google Calendar so GymLog can email each trainee a '
                    'reminder the evening before their session, based on your '
                    'existing event titles.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: status.connected
                ? OutlinedButton.icon(
                    onPressed: busy ? null : onDisconnect,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  )
                : FilledButton.icon(
                    onPressed: busy ? null : onConnect,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(busy ? 'Connecting…' : 'Connect Google Calendar'),
                  ),
          ),
        ],
      ),
    );
  }
}
