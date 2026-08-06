import 'package:flutter_test/flutter_test.dart';
import 'package:trascribe/services/update_checker.dart';

void main() {
  group('UpdateInfo.isUpdateAvailable', () {
    test('true when latest > current (patch)', () {
      expect(
        UpdateInfo(currentVersion: '1.0.0', latestVersion: '1.0.1').isUpdateAvailable,
        isTrue,
      );
    });

    test('true when latest > current (minor)', () {
      expect(
        UpdateInfo(currentVersion: '1.0.0', latestVersion: '1.1.0').isUpdateAvailable,
        isTrue,
      );
    });

    test('true when latest > current (major)', () {
      expect(
        UpdateInfo(currentVersion: '1.9.9', latestVersion: '2.0.0').isUpdateAvailable,
        isTrue,
      );
    });

    test('false when equal', () {
      expect(
        UpdateInfo(currentVersion: '1.0.0', latestVersion: '1.0.0').isUpdateAvailable,
        isFalse,
      );
    });

    test('false when current > latest', () {
      expect(
        UpdateInfo(currentVersion: '2.0.0', latestVersion: '1.0.0').isUpdateAvailable,
        isFalse,
      );
    });

    test('handles different version lengths', () {
      // 1.0.0 vs 1.0 → current is newer (patch > 0 vs 0)
      expect(
        UpdateInfo(currentVersion: '1.0.0', latestVersion: '1.0').isUpdateAvailable,
        isFalse,
      );
    });
  });
}
