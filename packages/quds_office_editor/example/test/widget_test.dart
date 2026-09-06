import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_studio/main.dart';

void main() {
  testWidgets('studio hosts Word, Excel, and PowerPoint workspaces', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QudsOfficeStudioApp());
    await tester.pump();

    expect(find.text('Quds Office Studio'), findsOneWidget);
    expect(find.text('Word'), findsWidgets);
    expect(find.textContaining('Quds Office Studio'), findsWidgets);

    await tester.tap(find.text('Excel').first);
    await tester.pump();
    expect(find.text('Budget'), findsWidgets);
    expect(find.text('Roster'), findsWidgets);

    await tester.tap(find.text('PowerPoint').first);
    await tester.pump();
    expect(find.textContaining('Quds Office Suite'), findsWidgets);
  });
}
