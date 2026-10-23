import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/form_layout.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_controller.dart';
import 'session.dart';

/// Shown while the session is restored or the profile loads, and when the
/// profile could not be loaded.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final error = profile.error;
    // Watched so the sign-out controller stays alive while its request runs.
    ref.watch(authControllerProvider(AuthForm.signOut));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.contentMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: Wordmark()),
                  const SizedBox(height: AppSpace.xl),
                  if (error == null || profile.isLoading)
                    const Center(child: AppLoader())
                  else ...[
                    Text(
                      failureMessage(error),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpace.xl),
                    PrimaryButton(
                      label: 'Tekrar dene',
                      onPressed: () => ref.invalidate(currentProfileProvider),
                    ),
                    const SizedBox(height: AppSpace.s),
                    TextButton(
                      onPressed: () => ref
                          .read(
                            authControllerProvider(AuthForm.signOut).notifier,
                          )
                          .signOut(),
                      child: const Text('Çıkış yap'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
