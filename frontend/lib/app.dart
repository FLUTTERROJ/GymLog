import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/account_setup_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/calendar_service.dart';
import 'services/challenge_service.dart';
import 'services/exercise_service.dart';
import 'services/workout_service.dart';
import 'services/profile_service.dart';
import 'services/trainer_service.dart';
import 'services/theme_service.dart';

class SyncFitApp extends StatelessWidget {
  const SyncFitApp({super.key});

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
        ChangeNotifierProvider(create: (_) => CalendarService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Builder(
        builder: (context) {
          final themeSvc = context.watch<ThemeService>();
          return MaterialApp(
            title: 'SyncFit',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: themeSvc.mode,
            home: const AuthGate(),
          );
        },
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
    final profiles = context.watch<ProfileService>();
    debugPrint(
      'AuthGate.build: userId=$userId lastUserId=$_lastUserId '
      'isSignedIn=${auth.isSignedIn} profilesLoading=${profiles.isLoading} '
      'profile=${profiles.profile?.id}',
    );

    if (userId != _lastUserId) {
      _lastUserId = userId;
      // Not during build — these notify their listeners.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('AuthGate: postFrameCallback firing for userId=$userId');
        if (!mounted) return;
        context.read<ExerciseService>().clear();
        context.read<WorkoutService>().clear();
        context.read<ProfileService>().clear();
        context.read<TrainerService>().clear();
        context.read<CalendarService>().clear();
        if (userId != null) {
          context.read<ExerciseService>().load(force: true);
          context.read<ProfileService>().load().then((_) {
            debugPrint(
              'AuthGate: ProfileService.load() resolved, '
              'profile=${context.read<ProfileService>().profile?.id}',
            );
            if (!mounted) return;
            final profile = context.read<ProfileService>().profile;
            if (profile?.isTrainer == true) {
              context.read<TrainerService>().loadTrainees();
              context.read<CalendarService>().loadStatus();
            } else {
              context.read<WorkoutService>().loadToday();
            }
          });
        }
      });
    }

    if (!auth.isSignedIn) return const LoginScreen();
    if (profiles.isLoading || profiles.profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return profiles.profile!.isComplete
        ? const MainShell()
        : const AccountSetupScreen();
  }
}
