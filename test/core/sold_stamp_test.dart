import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/design_tokens.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/sold_stamp.dart';

import '../helpers/themed.dart';

Finder _inStamp(Type type) =>
    find.descendant(of: find.byType(SoldStamp), matching: find.byType(type));

const _stamp = SoldStamp(
  winnerUsername: 'plakci_baris',
  amount: Money.kurus(125000),
  isMe: false,
);

void main() {
  testWidgets('drops in with a shake, then shows the winner', (tester) async {
    await pumpThemed(tester, _stamp);

    await tester.pump(AppDurations.sold ~/ 2);
    expect(_inStamp(Transform), findsWidgets);
    // The winner waits until the stamp has landed.
    final winner = tester.widget<AnimatedOpacity>(_inStamp(AnimatedOpacity));
    expect(winner.opacity, 0);

    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(_inStamp(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.text('@plakci_baris'), findsOneWidget);
  });

  testWidgets('with reduced motion it only fades in', (tester) async {
    await pumpThemed(tester, _stamp, reduceMotion: true);
    await tester.pump(AppDurations.sold ~/ 2);

    expect(_inStamp(Transform), findsNothing);
    expect(_inStamp(Opacity), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('SATILDI'), findsOneWidget);
  });
}
