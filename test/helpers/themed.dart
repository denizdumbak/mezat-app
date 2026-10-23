import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/theme.dart';

/// Pumps [child] inside the app theme, optionally with the system "reduce
/// motion" setting on and at a given screen width.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double width = 390,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}
