import 'package:flutter/widgets.dart';
import 'package:Personal/app/app.dart';
import 'package:Personal/core/month_end_analysis_notification_service.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RefreshRate.enable();
  await MonthEndAnalysisNotificationService.initialize();
  await MonthEndAnalysisNotificationService.scheduleFromSettings();
  runPersonalApp();
}
