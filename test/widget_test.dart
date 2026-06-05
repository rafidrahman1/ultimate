import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/app.dart';

void main() {
  testWidgets('Home screen shows feature grid', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PersonalApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Data hub'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
