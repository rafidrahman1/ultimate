import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/core/analysis_reports_storage.dart';
import 'package:Personal/features/results/results_folder_path.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory reportsDir;
  late AnalysisReportsStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('analysis_reports_test_');
    reportsDir = Directory('${tempRoot.path}${Platform.pathSeparator}Reports');
    await reportsDir.create(recursive: true);
    storage = AnalysisReportsStorage.forDirectory(reportsDir);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('throws when configured folder does not exist', () async {
    final missingDir = Directory('${tempRoot.path}${Platform.pathSeparator}Missing');
    final missingStorage = AnalysisReportsStorage.forDirectory(missingDir);

    expect(
      missingStorage.reportsDirectory,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not exist'),
        ),
      ),
    );
  });

  test('returns empty list when no folder is configured', () async {
    final loaded = await AnalysisReportsStorage.instance.loadAll();

    expect(loaded, isEmpty);
    expect(await AnalysisReportsStorage.instance.hasConfiguredFolder(), isFalse);
  });

  test('saves and loads analysis report files', () async {
    final report = {
      'id': 'report-1',
      'createdAt': DateTime(2026, 5, 1).toIso8601String(),
      'title': 'Monthly insights · May 2026',
      'prompt': 'prompt',
      'output': 'output',
      'dataSnapshot': {'health': 'steps'},
    };

    await storage.save(report);
    final loaded = await storage.loadAll();

    expect(loaded.length, 1);
    expect(loaded.first['id'], 'report-1');
    expect(loaded.first['title'], 'Monthly insights · May 2026');
  });

  test('migrates legacy SharedPreferences reports into configured folder', () async {
    final legacyReport = {
      'id': 'legacy-1',
      'createdAt': DateTime(2026, 4, 1).toIso8601String(),
      'title': 'Legacy report',
      'prompt': 'prompt',
      'output': 'output',
      'dataSnapshot': <String, String>{},
    };
    SharedPreferences.setMockInitialValues({
      legacyAnalysisResultsStorageKey: jsonEncode([legacyReport]),
      analysisReportsFolderUriKey: Uri.file(reportsDir.path).toString(),
    });

    final configuredStorage = AnalysisReportsStorage.instance;
    configuredStorage.invalidateCache();
    final loaded = await configuredStorage.loadAll();

    expect(loaded.length, 1);
    expect(loaded.first['id'], 'legacy-1');
    expect(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.getString(legacyAnalysisResultsStorageKey),
      ),
      completion(isNull),
    );
  });

  test('delete and clearAll remove report files only', () async {
    await storage.save({
      'id': 'keep-me',
      'createdAt': DateTime(2026, 5, 1).toIso8601String(),
      'title': 'One',
      'prompt': '',
      'output': '',
      'dataSnapshot': <String, String>{},
    });
    await storage.save({
      'id': 'remove-me',
      'createdAt': DateTime(2026, 5, 2).toIso8601String(),
      'title': 'Two',
      'prompt': '',
      'output': '',
      'dataSnapshot': <String, String>{},
    });
    await File(
      '${reportsDir.path}${Platform.pathSeparator}other-file.json',
    ).writeAsString('{}');

    await storage.delete('remove-me');
    var loaded = await storage.loadAll();
    expect(loaded.map((item) => item['id']), ['keep-me']);
    expect(
      await File(
        '${reportsDir.path}${Platform.pathSeparator}other-file.json',
      ).exists(),
      isTrue,
    );

    await storage.clearAll();
    loaded = await storage.loadAll();
    expect(loaded, isEmpty);
    expect(
      await File(
        '${reportsDir.path}${Platform.pathSeparator}other-file.json',
      ).exists(),
      isTrue,
    );
  });
}
