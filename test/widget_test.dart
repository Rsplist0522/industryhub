






import 'package:flutter_test/flutter_test.dart';

import 'package:industryhub/main.dart';

void main() {
  testWidgets('app starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const IndustryHubApp());
    await tester.pump();

    expect(find.text('INDUSTRYHUB'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
  });
}
