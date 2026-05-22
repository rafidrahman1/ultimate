import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/app.dart';

void main() {
  testWidgets('Home screen shows feature grid', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PersonalApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsWidgets);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Analyze data'), findsOneWidget);
  });
}
