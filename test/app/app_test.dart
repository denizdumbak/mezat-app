import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/app.dart';
import 'package:mezat_app/core/widgets/config_error_app.dart';

void main() {
  testWidgets('app starts on the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.text('Mezat'), findsOneWidget);
    expect(find.text('Canlı mezatlar yakında burada.'), findsOneWidget);
  });

  testWidgets('config error screen shows the problem', (tester) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'SUPABASE_URL is missing'),
    );

    expect(find.text('Yapılandırma hatası'), findsOneWidget);
    expect(find.text('SUPABASE_URL is missing'), findsOneWidget);
  });
}
