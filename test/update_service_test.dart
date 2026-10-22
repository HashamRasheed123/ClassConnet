import 'package:flutter_test/flutter_test.dart';
import 'package:softwareclass/core/config/app_config.dart';
import 'package:softwareclass/core/services/update_service.dart';

void main() {
  group('UpdateService Model Tests', () {
    test('AppUpdateInfo parses relative download_url correctly', () {
      final json = {
        'version_code': 2,
        'version_name': '1.0.1',
        'release_notes': 'Fixed timetable sync bugs',
        'is_mandatory': false,
        'download_url': '/api/v1/download/1',
      };

      final info = AppUpdateInfo.fromJson(
        json,
        'http://titan.portal.kzynovex.online',
      );

      expect(info.versionCode, 2);
      expect(info.versionName, '1.0.1');
      expect(info.releaseNotes, 'Fixed timetable sync bugs');
      expect(info.isMandatory, false);
      expect(info.rawDownloadUrl, '/api/v1/download/1');
      expect(
        info.resolvedDownloadUrl,
        'http://titan.portal.kzynovex.online/api/v1/download/1',
      );
      expect(info.isNewerThanCurrent, true);
    });

    test('AppUpdateInfo preserves absolute download_url', () {
      final json = {
        'version_code': 3,
        'version_name': '1.1.0',
        'release_notes': 'Major update',
        'is_mandatory': true,
        'download_url': 'https://downloads.kzynovex.online/app-release.apk',
      };

      final info = AppUpdateInfo.fromJson(
        json,
        'http://titan.portal.kzynovex.online',
      );

      expect(info.versionCode, 3);
      expect(info.isMandatory, true);
      expect(
        info.resolvedDownloadUrl,
        'https://downloads.kzynovex.online/app-release.apk',
      );
    });

    test('AppUpdateInfo detects when server version is not newer', () {
      final json = {
        'version_code': AppConfig.appVersionCode,
        'version_name': AppConfig.appVersion,
        'release_notes': 'Current release',
        'is_mandatory': false,
        'download_url': '/api/v1/download/1',
      };

      final info = AppUpdateInfo.fromJson(
        json,
        'http://titan.portal.kzynovex.online',
      );

      expect(info.isNewerThanCurrent, false);
    });
  });
}
