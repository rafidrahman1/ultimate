import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/analysis/ui/analysis_confirm_preferences_service.dart';
import 'package:personal/features/app_update/app_update_service.dart';
import 'package:personal/features/export/export_markdown_builder.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('core_infra_test');
    AppLog.directoryOverride = () async => dir;
  });

  tearDown(() async {
    await AppLog.read(); // let pending writes finish
    AppLog.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  group('AppLog', () {
    test('keeps warnings in a file, stamped with the clock', () async {
      withClock(Clock.fixed(DateTime(2026, 11, 11, 9, 30)), () {
        AppLog.warn('first');
        AppLog.warn('second');
      });
      final log = await AppLog.read();
      expect(
        log,
        '2026-11-11T09:30:00.000 first\n2026-11-11T09:30:00.000 second\n',
      );

      await AppLog.clear();
      expect(await AppLog.read(), isEmpty);
    });

    test('drops the older half once the file is too large', () async {
      final file = File('${dir.path}/app_log.txt');
      final old = [
        for (var i = 0; i < 6000; i++)
          'old line number $i padding padding padding',
      ];
      await file.writeAsString('${old.join('\n')}\n');
      expect(await file.length(), greaterThan(AppLog.maxBytes));

      AppLog.warn('newest');
      final log = await AppLog.read();
      expect(log.length, lessThan(AppLog.maxBytes));
      expect(log, isNot(contains('old line number 0 ')));
      expect(log, contains('old line number 5999 '));
      expect(log.trimRight().endsWith('newest'), isTrue);
      // The cut lands on a line boundary.
      expect(log.startsWith('old line number'), isTrue);
    });
  });

  group('promptTextFingerprint', () {
    test('is the FNV-1a offset basis for no input, and stable otherwise', () {
      expect(promptTextFingerprint(''), 0x811c9dc5);
      expect(promptTextFingerprint('a'), isNot(promptTextFingerprint('b')));
      expect(promptTextFingerprint('abc'), promptTextFingerprint('abc'));
      expect(promptTextFingerprint('abc'), isNot(promptTextFingerprint('acb')));
      expect(
        promptTextFingerprint('a' * 5000),
        inInclusiveRange(0, 0xffffffff),
      );
    });
  });

  group('update download', () {
    AppUpdate update(int size) => AppUpdate(
      version: AppVersion.tryParse('9.9.9+9')!,
      apkUrl: Uri.parse('https://example.com/app.apk'),
      notes: '',
      sizeBytes: size,
    );

    test('saves the file and reports progress', () async {
      final service = AppUpdateService(
        client: MockClient((_) async => http.Response.bytes([1, 2, 3, 4], 200)),
      );
      final file = File('${dir.path}/out.apk');
      final progress = <double>[];
      await service.downloadApk(update(4), file, onProgress: progress.add);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      expect(progress.last, 1.0);
    });

    test('a truncated download throws and leaves no file', () async {
      final service = AppUpdateService(
        client: MockClient((_) async => http.Response.bytes([1, 2], 200)),
      );
      final file = File('${dir.path}/out.apk');
      await expectLater(
        service.downloadApk(update(10), file),
        throwsA(isA<HttpException>()),
      );
      expect(await file.exists(), isFalse);
    });

    test('a server error throws', () async {
      final service = AppUpdateService(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      await expectLater(
        service.downloadApk(update(0), File('${dir.path}/out.apk')),
        throwsA(isA<HttpException>()),
      );
    });

    test('old APKs are removed, other files are kept', () async {
      await File('${dir.path}/personal-1.0.0+1.apk').writeAsString('x');
      await File('${dir.path}/keep.txt').writeAsString('x');
      await deleteDownloadedApks(dir);
      expect(await File('${dir.path}/personal-1.0.0+1.apk').exists(), isFalse);
      expect(await File('${dir.path}/keep.txt').exists(), isTrue);
    });
  });

  group('buildExportMarkdown', () {
    test('renders every section and marks missing sources', () {
      final period = AnalysisPeriod.forReference(DateTime(2026, 10, 20));
      final md = buildExportMarkdown(
        dataSnapshot: {'health': 'Slept well.', 'expenses': 'Spent 10.'},
        period: period,
        generatedAt: DateTime(2026, 11, 11, 9, 5),
      );
      expect(
        md,
        startsWith('# Personal Data Export — ${period.dataRangeLabel}'),
      );
      expect(md, contains('Generated November 11, 2026 9:05 AM.'));
      expect(md, contains('## Health\nSlept well.\n'));
      expect(md, contains('## Expenses\nSpent 10.\n'));
      expect(md, contains('## Gaming\nNo data available.\n'));
    });
  });
}
