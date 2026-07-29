import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const GymLogApp());
}

/// Shown instead of a bare crash when the app was built without the Supabase
/// credentials, which is by far the most likely first-run mistake.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Supabase credentials missing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Run the app with your project URL and anon key:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const SelectableText(
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...',
                  style: TextStyle(fontFamily: 'monospace', height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Or copy env.example.json to env.json and use\n'
                  '--dart-define-from-file=env.json',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
