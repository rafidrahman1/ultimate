import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLifecycleProvider =
    NotifierProvider<AppLifecycleController, AppLifecycleState>(
      AppLifecycleController.new,
    );

class AppLifecycleController extends Notifier<AppLifecycleState> {
  Completer<void>? _resumeCompleter;

  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void update(AppLifecycleState next) {
    state = next;
    if (next == AppLifecycleState.resumed) {
      final completer = _resumeCompleter;
      _resumeCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Waits until the app returns to the foreground.
  Future<void> waitUntilResumed({
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (state == AppLifecycleState.resumed) return;

    _resumeCompleter ??= Completer<void>();
    try {
      await _resumeCompleter!.future.timeout(timeout);
    } on TimeoutException {
      _resumeCompleter = null;
    }
  }
}
