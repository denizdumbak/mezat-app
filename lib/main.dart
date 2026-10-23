import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/env.dart';
import 'core/widgets/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Env env;
  try {
    env = Env.fromDefines();
  } on EnvException catch (e) {
    runApp(ConfigErrorApp(message: e.toString()));
    return;
  }

  await Supabase.initialize(
    url: env.supabaseUrl,
    // Supabase renamed the "anon key" to "publishable key"; same value.
    publishableKey: env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: App()));
}
