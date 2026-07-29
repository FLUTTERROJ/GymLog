import 'package:flutter/material.dart';

/// Google sign-in button.
///
/// The mark is drawn in code so the app doesn't need a bundled asset. If you
/// want the official four-colour logo, drop `assets/google_logo.png` into
/// pubspec.yaml and swap [_GoogleMark] for an `Image.asset`. Google's branding
/// guidelines apply if you ship this to a store.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const _GoogleMark(),
      label: Text(label),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.1,
        ),
      ),
    );
  }
}
