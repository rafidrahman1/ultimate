import 'package:flutter/widgets.dart';
import 'package:personal/app/app.dart';
import 'package:personal/features/commute_tracking/application/commute_tracking_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CommuteTrackingBootstrap.initialize();
  runPersonalApp();
}
