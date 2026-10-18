import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/storage/json_file_cache.dart';

const _key = 'ai_reports_v1';

class SavedReport {
  const SavedReport(this.text, this.at, {this.question = ''});

  final String text;
  final DateTime at;
  final String question;
}

final reportsProvider =
    AsyncNotifierProvider<ReportsStore, Map<String, SavedReport>>(
      ReportsStore.new,
    );

/// The latest answer for each bike and analysis kind, so a report is still
/// there after the app closes. Keyed `bikeId|kind`.
class ReportsStore extends AsyncNotifier<Map<String, SavedReport>> {
  static String keyFor(String bikeId, String kind) => '$bikeId|$kind';

  @override
  Future<Map<String, SavedReport>> build() async {
    final json = await JsonFileCache.instance.read(_key);
    final out = <String, SavedReport>{};
    for (final e in (json?['reports'] as Map? ?? const {}).entries) {
      final v = e.value as Map;
      out['${e.key}'] = SavedReport(
        v['text'] as String,
        DateTime.parse(v['at'] as String),
        question: v['question'] as String? ?? '',
      );
    }
    return out;
  }

  Future<void> save(String bikeId, String kind, SavedReport report) async {
    final next = {...?state.valueOrNull, keyFor(bikeId, kind): report};
    state = AsyncData(next);
    await JsonFileCache.instance.write(_key, {
      'reports': {
        for (final e in next.entries)
          e.key: {
            'text': e.value.text,
            'at': e.value.at.toIso8601String(),
            'question': e.value.question,
          },
      },
    });
  }
}
