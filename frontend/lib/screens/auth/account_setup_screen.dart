import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart' show describeError;
import '../../services/profile_service.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _username = TextEditingController();
  String _role = 'client';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(username)) {
      setState(() => _error = 'Use 3–30 letters, numbers, or underscores.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ProfileService>().completeSetup(
            username: username,
            role: _role,
          );
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set up your account')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Choose how you use GymLog',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'Your username is how people find and assign you. '),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'client',
                          icon: Icon(Icons.person_outline),
                          label: Text('Trainee')),
                      ButtonSegment(
                          value: 'trainer',
                          icon: Icon(Icons.fitness_center),
                          label: Text('Trainer')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (value) =>
                        setState(() => _role = value.first),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _username,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Unique username',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Saving...' : 'Continue')),
                ],
              ),
            ),
          ),
        ),
      );
}
