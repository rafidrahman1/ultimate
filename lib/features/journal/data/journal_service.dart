import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/forecasts/reminders/check_in_reminder_service.dart';
import 'package:personal/features/journal/data/journal_models.dart';

// Kept in shared_preferences, not the data cache: it is typed in by hand,
// cannot be rebuilt from a source file, and so belongs in the backup.
const _journalKey = 'journal_v1';

final journalProvider = NotifierProvider<JournalNotifier, Journal>(
  JournalNotifier.new,
);

class JournalNotifier extends Notifier<Journal> {
  static Journal _memoryFallback = Journal.empty;

  bool _changed = false;

  @override
  Journal build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    final raw = prefs?.getString(_journalKey);
    if (raw != null && !_changed) {
      try {
        final loaded = Journal.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
        _memoryFallback = loaded;
        state = loaded;
      } catch (_) {
        // An unreadable store is treated as an empty journal.
      }
    }
    unawaited(_syncReminder());
  }

  Future<void> _syncReminder() => CheckInReminderService.apply(
    loggedToday: state.checkInOn(habitDayOf(clock.now())) != null,
  );

  Future<void> _save(Journal next) async {
    _changed = true;
    _memoryFallback = next;
    state = next;
    await (await safePrefs())?.setString(_journalKey, jsonEncode(next));
  }

  /// Saves how [day] felt, replacing an earlier check-in for it.
  Future<void> checkIn(
    DateTime day, {
    required int mood,
    required int energy,
    required int stress,
  }) async {
    await _save(
      Journal(
        checkIns: [
          for (final c in state.checkIns)
            if (c.day != day) c,
          DayCheckIn(day: day, mood: mood, energy: energy, stress: stress),
        ],
        intakes: state.intakes,
      ),
    );
    unawaited(_syncReminder());
  }

  Future<void> removeCheckIn(DateTime day) async {
    await _save(
      Journal(
        checkIns: [
          for (final c in state.checkIns)
            if (c.day != day) c,
        ],
        intakes: state.intakes,
      ),
    );
    unawaited(_syncReminder());
  }

  Future<void> logIntake(IntakeKind kind, DateTime at) => _save(
    Journal(
      checkIns: state.checkIns,
      intakes: [...state.intakes, IntakeEvent(at, kind)],
    ),
  );

  Future<void> removeIntake(IntakeEvent event) => _save(
    Journal(
      checkIns: state.checkIns,
      intakes: [
        for (final e in state.intakes)
          if (!identical(e, event)) e,
      ],
    ),
  );
}
