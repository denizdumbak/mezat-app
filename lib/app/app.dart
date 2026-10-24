import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mezat',
      debugShowCheckedModeBanner: false,
      // Light everywhere; the live room wraps itself in liveTheme (router).
      theme: browseTheme,
      // The app is Turkish only, so the locale is fixed instead of following
      // the device: an English phone would otherwise get English pickers in a
      // Turkish app.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
