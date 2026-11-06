import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:personal/app/app.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Notification setup is not needed for the first frame; run it alongside.
  unawaited(NotificationSetup.cancelLegacyReminders());
  runPersonalApp();
}
