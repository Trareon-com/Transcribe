import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no trascribe typo remains in platform/config files', () {
    final repo = Directory.current;
    final files = <File>[
      File('${repo.path}/.idea/modules.xml'),
      File('${repo.path}/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'),
      File('${repo.path}/macos/Runner/Configs/AppInfo.xcconfig'),
      File('${repo.path}/macos/Runner.xcodeproj/project.pbxproj'),
      File('${repo.path}/linux/runner/my_application.cc'),
      File('${repo.path}/windows/runner/main.cpp'),
    ];
    for (final file in files) {
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      expect(
        content.toLowerCase().contains('trascribe'),
        isFalse,
        reason: '${file.path} still contains "trascribe"',
      );
    }
  });
}
