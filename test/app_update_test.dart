import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/app_update/app_update_service.dart';

void main() {
  final current = AppVersion.tryParse('2.2.1+3')!;

  Map<String, dynamic> release(String tag, {bool apk = true}) => {
    'tag_name': tag,
    'body': 'notes',
    'assets': [
      if (apk)
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://example.com/app.apk',
          'size': 10,
        },
    ],
  };

  test('newer version offers update', () {
    expect(parseLatestRelease(release('v2.3.0+4'), current), isNotNull);
    expect(parseLatestRelease(release('v2.2.1+4'), current), isNotNull);
  });

  test('same or older version offers nothing', () {
    expect(parseLatestRelease(release('v2.2.1+3'), current), isNull);
    expect(parseLatestRelease(release('v2.2.0+9'), current), isNull);
  });

  test('release without apk or bad tag is ignored', () {
    expect(parseLatestRelease(release('v3.0.0', apk: false), current), isNull);
    expect(parseLatestRelease(release('nightly'), current), isNull);
  });
}
