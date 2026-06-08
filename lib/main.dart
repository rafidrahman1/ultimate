import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:Personal/app/app.dart';
import 'package:Personal/core/month_end_analysis_notification_service.dart';
import 'package:Personal/firebase_options.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  RefreshRate.enable();
  await MonthEndAnalysisNotificationService.initialize();
  await MonthEndAnalysisNotificationService.scheduleFromSettings();
  runPersonalApp();
}
