import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_service.dart';

/// In-app guide to every screen and flow, written for the person using the
/// app rather than the person building it. Reachable from a help icon on
/// both the trainee and trainer home screens.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTrainer =
        context.watch<ProfileService>().profile?.isTrainer ?? false;

    final neutral = theme.colorScheme.secondary;
    final trainerColor = theme.colorScheme.primary;
    final traineeColor = theme.colorScheme.tertiary;

    final traineeSection = _Section(
      icon: Icons.person_outline,
      title: 'For trainees',
      roleLabel: 'Trainee',
      accent: traineeColor,
      initiallyExpanded: !isTrainer,
      children: [
        _SubSection(
          title: 'Log today\'s workout',
          accent: traineeColor,
          child: _Steps(
            accent: traineeColor,
            steps: const [
              'Tap "+ Add workout" on the Today tab (or "Log your workout" '
                  'if today is empty).',
              'Check the date at the top — it defaults to today, but you '
                  'can back-date any session up to today.',
              'Tap "Choose exercise" and search. Not in the list? Type the '
                  'name and tap Add "…" — it\'s saved to your own list from '
                  'then on.',
              'Enter reps for each set. Weight (kg) is optional — leave it '
                  'blank for bodyweight moves.',
              'Tap "Add another exercise" for more than one movement in the '
                  'session.',
              'Under "Assign to trainer", search their username and tap '
                  'them — this is what makes the session visible to them.',
              'Tap "Save workout".',
            ],
          ),
        ),
        _SubSection(
          title: 'During the day',
          accent: traineeColor,
          child: _Bullets(
            accent: traineeColor,
            items: const [
              'The Today screen totals your exercises, sets, reps and kg '
                  'volume as you log them.',
              'Tap the notes card to leave your trainer a note about how '
                  'the session felt.',
              'Tap the delete icon on an exercise card to remove it, and '
                  'every set logged under it that day.',
              'One workout exists per calendar day — logging the same '
                  'exercise again continues its set numbering rather than '
                  'starting a new entry.',
            ],
          ),
        ),
        _SubSection(
          title: 'History',
          accent: traineeColor,
          child: _Bullets(
            accent: traineeColor,
            items: const [
              'Every day you\'ve logged, newest first, with a quick preview '
                  'and stat pills.',
              'Tap a day to open it fully — edit the session, add more to '
                  'it, or remove a single exercise.',
              'Pull down to refresh.',
            ],
          ),
        ),
        _SubSection(
          title: 'Monthly challenges',
          accent: traineeColor,
          child: _Bullets(
            accent: traineeColor,
            items: const [
              'Your trainer builds these — a set of exercises to complete '
                  'daily over a date range.',
              'The Exercises tab is today\'s checklist; use the arrows to '
                  'move between days. Future days stay locked until they '
                  'arrive.',
              'The Calendar tab shows a grid of the whole challenge — full '
                  'cells mean everything was completed that day, partial '
                  'cells mean some was.',
            ],
          ),
        ),
      ],
    );

    final trainerSection = _Section(
      icon: Icons.fitness_center,
      title: 'For trainers',
      roleLabel: 'Trainer',
      accent: trainerColor,
      initiallyExpanded: isTrainer,
      children: [
        _SubSection(
          title: 'Your trainees',
          accent: trainerColor,
          child: _Bullets(
            accent: trainerColor,
            items: const [
              'Someone appears on your list the first time they log a '
                  'workout and search-and-select your username — there\'s '
                  'no invite step on your side.',
              'Each row shows their workout count and most recent session '
                  'date.',
              'Tap a trainee to see their full logged history, read-only.',
            ],
          ),
        ),
        _SubSection(
          title: 'Create a monthly challenge',
          accent: trainerColor,
          child: _Steps(
            accent: trainerColor,
            steps: const [
              'Tap "Create challenge" from your trainee list.',
              'Give it a title, e.g. "August Strength Challenge".',
              'Search trainees by username and tap to add them — you can '
                  'assign the same challenge to several people at once.',
              'Set the start and end dates.',
              'Add exercises — pick from the built-in list or tap "Add '
                  'custom exercise" to name your own — then set reps and '
                  'sets for each.',
              'Add optional notes and tap "Create challenge". Every '
                  'assigned trainee sees it immediately.',
            ],
          ),
        ),
        _SubSection(
          title: 'Google Calendar reminders (optional)',
          accent: trainerColor,
          child: _Steps(
            accent: trainerColor,
            steps: const [
              'Tap the calendar icon in the top bar of your trainee list.',
              'Tap "Connect Google Calendar" and approve the consent '
                  'screen — it grants read-only calendar access plus '
                  'permission to send mail as your own Google account, '
                  'which is what sends the reminders.',
              'SyncFit reads tomorrow\'s events formatted as '
                  '"Name : Paid/Unpaid : Location" and shows a live '
                  'preview.',
              'Tap any unmapped name once and pick which trainee it refers '
                  'to — remembered for every future session with that '
                  'name.',
              'From then on, that trainee automatically gets a reminder '
                  'email the evening before their session.',
            ],
          ),
        ),
      ],
    );

    final roleSections = isTrainer
        ? [trainerSection, traineeSection]
        : [traineeSection, trainerSection];

    return Scaffold(
      appBar: AppBar(title: const Text('How SyncFit works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quick tour of every screen and flow.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _LegendDot(color: traineeColor, label: 'Trainee'),
                    const SizedBox(width: 18),
                    _LegendDot(color: trainerColor, label: 'Trainer'),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            icon: Icons.flag_outlined,
            title: 'Getting started',
            roleLabel: 'Everyone',
            accent: neutral,
            initiallyExpanded: true,
            children: [
              _SubSection(
                title: null,
                accent: neutral,
                child: _Bullets(
                  accent: neutral,
                  items: const [
                    'One account type, two roles — Trainee or Trainer — '
                        'chosen at sign-up and shown to the other side by '
                        'your username.',
                    'Sign up with email + password or Google. New accounts '
                        'pick a unique username, 3–30 letters, numbers or '
                        'underscores.',
                    'Forgot your password? Enter your email on the sign-in '
                        'screen and tap "Forgot password?" for a reset '
                        'link.',
                    'You stay signed in between app launches. Sign out any '
                        'time from the logout icon in the top-right '
                        'corner.',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...roleSections.expand((s) => [s, const SizedBox(height: 14)]),
          _Section(
            icon: Icons.phone_iphone,
            title: 'Install on your phone',
            roleLabel: 'Everyone',
            accent: neutral,
            children: [
              _SubSection(
                title: 'iPhone / iPad (Safari)',
                accent: neutral,
                child: _Steps(
                  accent: neutral,
                  steps: const [
                    'Open the SyncFit web link in Safari.',
                    'Tap the Share icon.',
                    'Tap "Add to Home Screen", then "Add".',
                  ],
                ),
              ),
              _SubSection(
                title: 'Android (Chrome)',
                accent: neutral,
                child: _Steps(
                  accent: neutral,
                  steps: const [
                    'Open the SyncFit web link in Chrome.',
                    'Tap the ⋮ menu.',
                    'Tap "Install app" (or "Add to Home screen"), then '
                        'confirm.',
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.roleLabel,
    required this.accent,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String roleLabel;
  final Color accent;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 20, 6),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RolePill(label: roleLabel, color: accent),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(
                    height: 1,
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  const _SubSection({
    required this.title,
    required this.accent,
    required this.child,
  });

  final String? title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title!,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 13),
        ],
        child,
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.accent});

  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps, required this.accent});

  final List<String> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[i],
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
