import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:motohealth/app/app.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/features/reminders/reminder_service.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No crash service: log, and keep stray async errors from killing the app.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.warn('Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.warn('Unhandled error: $error');
    return true;
  };
  RefreshRate.enable();
  await ReminderService.initialize();
  runMotoHealthApp();
}
