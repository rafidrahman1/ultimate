import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/progress_review/progress_review_dashboard.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';
import 'package:personal/core/theme/app_theme.dart';

void main() {
  testWidgets('dashboard renders summary and domains', (tester) async {
    final data = ProgressReviewViewData.mock();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ProgressReviewDashboard(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Core summary'), findsOneWidget);
    expect(find.textContaining('Spending stayed below'), findsOneWidget);
  });
}
