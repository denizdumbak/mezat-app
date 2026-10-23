import 'package:flutter/material.dart';

/// Placeholder home. Becomes the live/upcoming auction list in M2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mezat')),
      body: const Center(child: Text('Canlı mezatlar yakında burada.')),
    );
  }
}
