import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_failure.dart';
import '../auth/auth_controller.dart';
import '../auth/session.dart';

/// Placeholder home. Becomes the live/upcoming auction list in M2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(currentProfileProvider).value?.username;
    final signOut = ref.watch(authControllerProvider(AuthForm.signOut));

    ref.listen(authControllerProvider(AuthForm.signOut), (_, next) {
      final error = next.error;
      if (error != null && !next.isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AuthFailure.messageFor(error))));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mezat'),
        actions: [
          if (username != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('@$username'),
              ),
            ),
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: signOut.isLoading
                ? null
                : () => ref
                      .read(authControllerProvider(AuthForm.signOut).notifier)
                      .signOut(),
          ),
        ],
      ),
      body: const Center(child: Text('Canlı mezatlar yakında burada.')),
    );
  }
}
