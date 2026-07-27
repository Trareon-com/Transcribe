/// Lightweight Dart-only persistence for settings that are not sent to Rust.
///
/// Stores a JSON file at `<app-support>/dart_prefs.json`. Callers are
/// responsible for calling [load] before accessing values and [save] after
/// mutating them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DartPrefs {
  DartPrefs._();

  static final DartPrefs instance = DartPrefs._();

  Map<String, dynamic> _data = {};

  Future<File> _prefsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/dart_prefs.json');
  }

  /// Load prefs from disk. Safe to call multiple times.
  Future<void> load() async {
    try {
      final file = await _prefsFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _data = decoded;
        }
      }
    } catch (_) {
      // Corrupt / missing file — start fresh.
      _data = {};
    }
  }

  /// Persist current in-memory data to disk.
  Future<void> save() async {
    try {
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode(_data));
    } catch (_) {
      // Best-effort; silently ignore write errors.
    }
  }

  String? getString(String key) => _data[key] as String?;

  void setString(String key, String value) => _data[key] = value;
}
