import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/widgets/form_layout.dart';

import '../../helpers/fakes.dart';
import '../../helpers/screens.dart';

/// The auth screens in the new design: they fit a small phone and keep the
/// wordmark and the one gold button.
void main() {
  testWidgets('sign in fits a small phone', (tester) async {
    useSmallPhone(tester);
    await pumpApp(tester, auth: FakeAuthRepository());

    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign up fits a small phone, error included', (tester) async {
    useSmallPhone(tester);
    await pumpApp(tester, auth: FakeAuthRepository());
    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Kayıt ol'));

    expect(find.text('E-posta adresini gir.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choose username fits a small phone', (tester) async {
    useSmallPhone(tester);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedInAs: FakeAuthRepository.signedInUserId),
    );

    expect(find.byKey(const Key('chooseUsername.username')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
