import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/google_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isSignUp = false;
  String _role = 'client';
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
      _info = null;
      _role = 'client';
      _username.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthService>();
    try {
      if (_isSignUp) {
        final username = _role == 'trainer' ? _username.text : '';
        final signedIn = await auth.signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          username: username,
          role: _role,
        );
        // With "Confirm email" enabled there's no session yet — the AuthGate
        // won't move, so say why.
        if (!signedIn && mounted) {
          setState(() {
            _isSignUp = false;
            _info = 'Check ${_email.text.trim()} for a confirmation link, '
                'then sign in.';
          });
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      // On success the auth state listener swaps this screen out.
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AuthService>().signInWithGoogle();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      // The browser hop is asynchronous; re-enable the form either way so the
      // screen isn't stuck if the user cancels at the consent screen.
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap this again.');
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'Password reset link sent to $email.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 52,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isSignUp ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Log your training and share it with your trainer.'
                          : 'Sign in to log today\'s workout.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 28),

                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 2)
                                ? 'Please enter your name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'client',
                            icon: Icon(Icons.person_outline),
                            label: Text('Trainee'),
                          ),
                          ButtonSegment(
                            value: 'trainer',
                            icon: Icon(Icons.fitness_center),
                            label: Text('Trainer'),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (value) =>
                            setState(() {
                              _role = value.first;
                              if (_role != 'trainer') _username.clear();
                            }),
                      ),
                      const SizedBox(height: 12),
                      if (_role == 'trainer') ...[
                        TextFormField(
                          controller: _username,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Unique username',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (value) => _isSignUp &&
                                  _role == 'trainer' &&
                                  !RegExp(r'^[A-Za-z0-9_]{3,30}$')
                                      .hasMatch((value ?? '').trim())
                              ? 'Use 3–30 letters, numbers, or underscores'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Please enter your email';
                        final looksValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email);
                        return looksValid ? null : 'That doesn\'t look like an email';
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _isSignUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) return 'Please enter a password';
                        if (_isSignUp && password.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _Banner(
                        text: _error!,
                        icon: Icons.error_outline,
                        background: theme.colorScheme.errorContainer,
                        foreground: theme.colorScheme.onErrorContainer,
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 8),
                      _Banner(
                        text: _info!,
                        icon: Icons.mark_email_unread_outlined,
                        background: theme.colorScheme.secondaryContainer,
                        foreground: theme.colorScheme.onSecondaryContainer,
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    GoogleButton(
                      label: _isSignUp
                          ? 'Sign up with Google'
                          : 'Continue with Google',
                      onPressed: _busy ? null : _google,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? 'Already have an account?'
                              : 'New here?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _busy ? null : _toggleMode,
                          child: Text(_isSignUp ? 'Sign in' : 'Create one'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
