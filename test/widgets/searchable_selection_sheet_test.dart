import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/searchable_selection_sheet.dart';

void main() {
  testWidgets('the clear-search button has a translated tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SearchableSelectionSheet<int>(
            title: 'Pick',
            searchHint: 'Search',
            items: const [
              SearchableSheetItem(
                value: 1,
                title: 'One',
                subtitle: '',
                leading: SizedBox(),
              ),
            ],
            isSelected: (_) => false,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'on');
    await tester.pump();
    final clear = find.byTooltip('bf_bills_clear_search');
    expect(clear, findsOneWidget);
    await tester.tap(clear);
    await tester.pump();
    expect(find.byTooltip('bf_bills_clear_search'), findsNothing);
  });
}
