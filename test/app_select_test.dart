import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/core/widgets/app_select.dart';

void main() {
  testWidgets('premium select searches long option lists', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppSelect<String>(
                label: 'مركز التكلفة',
                value: selected,
                searchable: true,
                options: List.generate(
                  10,
                  (index) => AppSelectOption(
                    value: '$index',
                    label: 'مشروع رقم ${index + 1}',
                  ),
                ),
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty,
      isFalse,
    );
    await tester.tap(find.text('اختر…'));
    await tester.pumpAndSettle();
    expect(find.text('ابحث بالاسم أو الكود…'), findsOneWidget);
    expect(find.text('10 نتيجة'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(
      tester.getSize(find.byType(ListView)).height,
      lessThanOrEqualTo(420),
    );
    await tester.enterText(find.byType(TextField), 'رقم 9');
    await tester.pumpAndSettle();
    expect(find.text('مشروع رقم 9'), findsOneWidget);
    expect(find.text('مشروع رقم 1'), findsNothing);
    await tester.tap(find.text('مشروع رقم 9'));
    await tester.pumpAndSettle();
    expect(find.text('مشروع رقم 9'), findsOneWidget);
  });

  testWidgets('short filters open below the field without search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: AppSelect<String>(
                label: 'الحالة',
                value: '',
                options: const [
                  AppSelectOption(value: '', label: 'كل الحالات'),
                  AppSelectOption(value: 'APPROVED', label: 'معتمد'),
                  AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('كل الحالات'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('معتمد'), findsOneWidget);
    final fieldBottom = tester.getBottomLeft(find.text('كل الحالات').first).dy;
    final optionTop = tester.getTopLeft(find.text('معتمد')).dy;
    expect(optionTop, greaterThan(fieldBottom));
  });

  testWidgets('lists open above a field near the bottom edge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 520),
              child: AppSelect<String>(
                label: 'الحالة',
                value: '',
                options: const [
                  AppSelectOption(value: '', label: 'كل الحالات'),
                  AppSelectOption(value: 'APPROVED', label: 'معتمد'),
                  AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('كل الحالات'));
    await tester.pumpAndSettle();
    final fieldTop = tester.getTopLeft(find.byType(InputDecorator)).dy;
    final optionBottom = tester.getBottomLeft(find.text('مرفوض')).dy;
    expect(optionBottom, lessThan(fieldTop));
  });

  testWidgets('search folds Arabic spellings and matches codes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppSelect<String>(
              label: 'المقاول',
              options: [
                for (var i = 0; i < 12; i++)
                  AppSelectOption(
                    value: '$i',
                    label: i == 7 ? 'مؤسسة الإخلاص للمقاولات' : 'مقاول $i',
                    subtitle: 'CON-${i.toString().padLeft(3, '0')}',
                  ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('اختر…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الاخلاص');
    await tester.pumpAndSettle();
    expect(find.text('مؤسسة الإخلاص للمقاولات'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'con-003');
    await tester.pumpAndSettle();
    expect(find.text('مقاول 3'), findsOneWidget);
    expect(find.text('مقاول 4'), findsNothing);
  });
}
