import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/exercise_service.dart';
import 'services/workout_service.dart';

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ExerciseService()),
        ChangeNotifierProvider(create: (_) => WorkoutService()),
      ],
      child: MaterialApp(
        title: 'GymLog',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const AuthGate(),
      ),
    );
  }
}

/// Swaps between the login screen and the app depending on the session, and
/// drops one user's cached data before the next one is shown any of it.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = auth.user?.id;

    if (userId != _lastUserId) {
      _lastUserId = userId;
      // Not during build — these notify their listeners.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ExerciseService>().clear();
        context.read<WorkoutService>().clear();
        if (userId != null) {
          context.read<ExerciseService>().load(force: true);
          context.read<WorkoutService>().loadToday();
        }
      });
    }

    return auth.isSignedIn ? const MainShell() : const LoginScreen();
  }
}
