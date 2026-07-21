import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:personal/app/app.dart';
import 'package:personal/firebase_options.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  RefreshRate.enable();
  runPersonalApp();
}
