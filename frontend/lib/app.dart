import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/account_setup_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/challenge_service.dart';
import 'services/exercise_service.dart';
import 'services/workout_service.dart';
import 'services/profile_service.dart';
import 'services/trainer_service.dart';

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ExerciseService()),
        ChangeNotifierProvider(create: (_) => WorkoutService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => TrainerService()),
        ChangeNotifierProvider(create: (_) => ChallengeService()),
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
        context.read<ProfileService>().clear();
        context.read<TrainerService>().clear();
        if (userId != null) {
          context.read<ExerciseService>().load(force: true);
          context.read<ProfileService>().load().then((_) {
            if (!mounted) return;
            final profile = context.read<ProfileService>().profile;
            if (profile?.isTrainer == true) {
              context.read<TrainerService>().loadTrainees();
            } else {
              context.read<WorkoutService>().loadToday();
            }
          });
        }
      });
    }

    if (!auth.isSignedIn) return const LoginScreen();
    final profiles = context.watch<ProfileService>();
    if (profiles.isLoading || profiles.profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return profiles.profile!.isComplete
        ? const MainShell()
        : const AccountSetupScreen();
  }
}
