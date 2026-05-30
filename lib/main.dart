import 'package:flutter/widgets.dart';
import 'package:personal/app/app.dart';
import 'package:refresh_rate/refresh_rate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RefreshRate.enable();
  runPersonalApp();
}
