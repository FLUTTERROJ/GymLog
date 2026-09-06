import 'dart:async';

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

  await _bootstrap();
}

/// Split out from [main] so the "try again" button on [_StartupFailedApp]
/// can re-run it without re-entering the whole app.
Future<void> _bootstrap() async {
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    ).timeout(Env.networkTimeout);
    runApp(const SyncFitApp());
  } catch (error) {
    // A stuck connection here (e.g. trying to validate/refresh a stale
    // session) used to leave a blank page forever, with no UI painted at
    // all -- runApp() had never been called yet. Bounding it means there's
    // always something on screen, even when Supabase can't be reached.
    runApp(_StartupFailedApp(onRetry: _bootstrap));
  }
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

/// Shown when Supabase couldn't be reached within [Env.networkTimeout] --
/// most often a stuck connection trying to validate a leftover session.
/// "Try again" re-runs [_bootstrap] directly rather than requiring the user
/// to force-quit and relaunch.
class _StartupFailedApp extends StatefulWidget {
  const _StartupFailedApp({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_StartupFailedApp> createState() => _StartupFailedAppState();
}

class _StartupFailedAppState extends State<_StartupFailedApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    // A successful retry calls runApp() itself and replaces this whole
    // widget tree; a failed one mounts a fresh _StartupFailedApp, so there's
    // no state left here to reset either way.
    await widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not connect',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  "SyncFit couldn't reach the server. Check your connection "
                  'and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retrying ? null : _retry,
                  child: _retrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
