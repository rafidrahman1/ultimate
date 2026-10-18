import 'package:flutter/widgets.dart';
import 'package:motohealth/app/app.dart';
import 'package:motohealth/features/reminders/reminder_service.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RefreshRate.enable();
  await ReminderService.initialize();
  runMotoHealthApp();
}
