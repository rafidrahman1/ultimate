import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/backup_service.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backs up and restores prefs, skipping device-specific keys', () async {
    SharedPreferences.setMockInitialValues({
      'insight_checklist_v2_abc_w0': '{"completed":[1]}',
      'home_checklist_result_id_v1': 'abc',
      'app_data_folder_uri_v1': 'content://x',
      'data_cache_expenses_v1': '{}',
    });
    final dir = await Directory.systemTemp.createTemp('backup_test');
    addTearDown(() => dir.delete(recursive: true));
    final service = BackupService(
      storage: AnalysisReportsStorage.forDirectory(dir),
    );

    expect(await service.peek(), isNull);
    final info = await service.backUp();
    expect(info.entryCount, 2);
    expect((await service.peek())!.entryCount, 2);

    SharedPreferences.setMockInitialValues({});
    expect(await service.restore(), 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('insight_checklist_v2_abc_w0'), contains('1'));
    expect(prefs.getString('app_data_folder_uri_v1'), isNull);
  });
}
