import 'package:flutter/material.dart';

/// Shown instead of the real app when startup configuration is invalid,
/// so a missing `.env` shows a readable message rather than a crash.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yapılandırma hatası',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 12),
                const Text(
                  'Uygulamayı `flutter run --dart-define-from-file=.env` '
                  'ile başlatın. Örnek değerler için .env.example dosyasına bakın.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
