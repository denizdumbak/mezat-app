import 'package:flutter/services.dart';

/// Widget tests draw text with a placeholder font (Ahem) unless real fonts
/// are loaded. `flutter test` bundles the pubspec fonts and Material icons,
/// so they can be read from rootBundle and registered here.
Future<void> loadAppFonts() async {
  final families = {
    'Fraunces': ['Fraunces-SemiBold', 'Fraunces-Bold'],
    'Manrope': [
      'Manrope-Regular',
      'Manrope-Medium',
      'Manrope-SemiBold',
      'Manrope-Bold',
      'Manrope-ExtraBold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
