import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_failure.dart';

/// Shared frame for the app's forms: centered, scrollable (so the keyboard
/// never hides the button) and narrow on wide screens.
class FormLayout extends StatelessWidget {
  const FormLayout({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The error of the last failed action, or nothing.
class FailureMessage extends StatelessWidget {
  const FailureMessage({super.key, required this.state});

  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    if (error == null || state.isLoading) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        failureMessage(error),
        style: TextStyle(color: colors.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Primary button that shows a spinner and ignores taps while [busy].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
