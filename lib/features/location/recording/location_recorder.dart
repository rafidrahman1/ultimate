import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:personal/core/app_log.dart';

const _channel = MethodChannel('com.redpanda.personal/location_recorder');

class RecorderStatus {
  const RecorderStatus({
    this.supported = false,
    this.enabled = false,
    this.running = false,
    this.lastFix,
    this.logDir,
    this.alwaysLocation = false,
    this.activityRecognition = false,
    this.batteryExempt = false,
  });

  /// False off Android.
  final bool supported;

  /// You turned recording on (it restarts after a reboot).
  final bool enabled;

  /// The service is alive right now.
  final bool running;
  final DateTime? lastFix;

  /// Where the raw log lives.
  final String? logDir;

  /// "Allow all the time": needed to restart after a reboot.
  final bool alwaysLocation;

  /// Walking / vehicle detection; without it modes come from speed alone.
  final bool activityRecognition;

  /// Exempt from battery optimisation, so the phone doesn't kill it.
  final bool batteryExempt;

  /// Anything missing that makes recording less reliable.
  List<String> get warnings => [
    if (enabled && !running) 'Recording stopped. Tap to restart it.',
    if (enabled && !alwaysLocation)
      'Location is not set to "Allow all the time", so recording '
          'won\'t restart after a reboot.',
    if (enabled && !activityRecognition)
      'Physical activity access is off, so travel modes are guessed from '
          'speed alone.',
    if (enabled && !batteryExempt)
      'Battery optimisation is on for this app; the phone may stop recording.',
  ];
}

final locationRecorderProvider =
    AsyncNotifierProvider<LocationRecorderController, RecorderStatus>(
      LocationRecorderController.new,
    );

class LocationRecorderController extends AsyncNotifier<RecorderStatus> {
  @override
  Future<RecorderStatus> build() async {
    final status = await _read();
    // Killed by the system (or after an update before the boot receiver ran):
    // bring it back while the app is open.
    if (status.enabled && !status.running) {
      await _invoke('start');
      return _read();
    }
    return status;
  }

  Future<void> refresh() async {
    state = AsyncData(await _read());
  }

  /// Asks for every permission recording uses, then starts it. Returns false
  /// when location itself was refused.
  Future<bool> enable() async {
    if (!Platform.isAndroid) return false;
    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) return false;
    // Android shows "Allow all the time" on its own settings page.
    await Permission.locationAlways.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    final started = await _invoke('start') == true;
    await refresh();
    return started;
  }

  Future<void> disable() async {
    await _invoke('stop');
    await refresh();
  }

  /// Re-asks for whatever is missing (from a warning tap).
  Future<void> fixPermissions() async {
    final current = state.value;
    if (current == null) return;
    if (!current.alwaysLocation) await Permission.locationAlways.request();
    if (!current.activityRecognition) {
      await Permission.activityRecognition.request();
    }
    if (!current.batteryExempt) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    if (current.enabled && !current.running) await _invoke('start');
    await refresh();
  }

  Future<RecorderStatus> _read() async {
    if (!Platform.isAndroid) return const RecorderStatus();
    final raw = await _invoke('status');
    if (raw is! Map) return const RecorderStatus();
    final lastFixMs = (raw['lastFixMs'] as num?)?.toInt() ?? 0;
    return RecorderStatus(
      supported: true,
      enabled: raw['enabled'] == true,
      running: raw['running'] == true,
      lastFix: lastFixMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastFixMs)
          : null,
      logDir: raw['logDir'] as String?,
      alwaysLocation: await Permission.locationAlways.isGranted,
      activityRecognition: await Permission.activityRecognition.isGranted,
      batteryExempt: await Permission.ignoreBatteryOptimizations.isGranted,
    );
  }

  Future<Object?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<Object?>(method);
    } on PlatformException catch (error) {
      AppLog.warn('Location recorder $method failed: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
