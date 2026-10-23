import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/widgets/config_error_app.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('app starts on the sign-in screen when signed out', (
    tester,
  ) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    expect(find.widgetWithText(AppBar, 'Giriş yap'), findsOneWidget);
  });

  testWidgets('config error screen shows the problem', (tester) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'SUPABASE_URL is missing'),
    );

    expect(find.text('Yapılandırma hatası'), findsOneWidget);
    expect(find.text('SUPABASE_URL is missing'), findsOneWidget);
  });
}
