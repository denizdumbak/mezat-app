import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../app_failure.dart';

/// Shared frame for the app's forms: a big heading, scrollable content (so
/// the keyboard never hides the button), narrow on wide screens.
///
/// Pushed forms get a back button; entry screens (sign in, sign up) show the
/// "mezat" wordmark instead.
class FormLayout extends StatelessWidget {
  const FormLayout({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.edge,
              AppSpace.s,
              AppSpace.edge,
              AppSpace.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: canPop ? const BackButton() : const Wordmark(),
                  ),
                  const SizedBox(height: AppSpace.l),
                  Text(title, style: text.headlineLarge),
                  const SizedBox(height: AppSpace.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's name set in the display face, in gold. Stands in for a logo.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSize.touch,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'mezat',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.l),
      child: Text(
        failureMessage(error),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: AppColors.urgent),
        textAlign: TextAlign.center,
      ),
    );
  }
}
