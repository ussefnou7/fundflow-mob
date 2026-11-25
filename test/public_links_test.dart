import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/widgets/public_links.dart';

void main() {
  Future<void> pump(WidgetTester tester, String baseUrl) => tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: PublicLinks(baseUrl: baseUrl)),
      ),
    ),
  );

  testWidgets('store builds show the privacy and support links', (
    tester,
  ) async {
    await pump(tester, 'https://web.example.test');
    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.text('الدعم الفني'), findsOneWidget);
    final label = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('الدعم الفني'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(
      label.style?.textStyle?.resolve({})?.fontFamily,
      'Cairo',
      reason: 'a bare TextStyle drops the theme font and draws boxes',
    );
  });

  testWidgets('builds without WEB_BASE_URL hide them', (tester) async {
    await pump(tester, '');
    expect(find.text('سياسة الخصوصية'), findsNothing);
  });
}
