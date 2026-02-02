import 'package:flutter/material.dart';

import 'nitj_email.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onSignedIn});

  final ValueChanged<String> onSignedIn;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // UI-only placeholder for "Google auth + email OTP".
    // Replace with real Google Sign-In + backend-issued OTP.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    widget.onSignedIn(_emailController.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'vibeU',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Campus-only dating + social for NITJ',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'College email',
                          hintText: 'name.branch.year@nitj.ac.in',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) {
                          final v = value ?? '';
                          if (v.trim().isEmpty) return 'Enter your NITJ email';
                          if (!isValidNitjEmail(v)) {
                            return 'Use: name.branch.year@nitj.ac.in';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.login),
                        label: Text(
                          _isSubmitting
                              ? 'Signing in…'
                              : 'Continue with Google (placeholder)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Next: we’ll verify by Google sign-in + email OTP.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
