// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
// Pre-flight checks — validates system readiness before a recording session.
// Runs synchronously and returns a list of blocking/warning issues.
// No audio content, transcripts, or PII is accessed or stored here.

import 'dart:io';

import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart' as ui;

enum PreflightSeverity {
  /// Issue that blocks recording from starting. User must resolve before proceeding.
  blocking,
  /// Non-critical issue; recording can proceed but user should be informed.
  warning,
}

class PreflightIssue {
  final String id;
  final PreflightSeverity severity;
  final String title;
  final String description;
  final String? fixAction;

  const PreflightIssue({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    this.fixAction,
  });

  @override
  String toString() => '[$severity] $title: $description';
}

/// Unified result from a full pre-flight run.
class PreflightReport {
  /// Blocking issues — recording MUST NOT start until all are resolved.
  final List<PreflightIssue> blocking;
  /// Warning issues — recording can proceed but user should see these.
  final List<PreflightIssue> warnings;

  const PreflightReport({required this.blocking, required this.warnings});

  bool get isReady => blocking.isEmpty;

  List<PreflightIssue> get all => [...blocking, ...warnings];

  int get totalCount => blocking.length + warnings.length;

  String get summary {
    if (isReady) {
      return warnings.isEmpty
          ? 'Semua sistem siap.'
          : '${warnings.length} peringatan — rekaman dapat dilanjutkan.';
    }
    return '${blocking.length} masalah pemblokir harus diperbaiki.';
  }
}

/// Runs all pre-flight checks and returns a structured report.
/// Call this BEFORE calling `sessionProvider.notifier.start()`.
Future<PreflightReport> runPreflightChecks({
  required RustBridge bridge,
  required ui.SessionConfig config,
  required String modelPath,
  /// Minimum free disk space in bytes before blocking (default: 500 MB).
  int minimumFreeBytes = 512 * 1024 * 1024,
}) async {
  final blocking = <PreflightIssue>[];
  final warnings = <PreflightIssue>[];

  // ── 1. Mic device ────────────────────────────────────────────────
  if (config.micEnabled) {
    final inputs = await bridge.listAudioDevices();
    if (inputs.isEmpty) {
      blocking.add(const PreflightIssue(
        id: 'no_mic',
        severity: PreflightSeverity.blocking,
        title: 'Tidak ada perangkat mikrofon',
        description: 'Perangkat mikrofon tidak ditemukan. '
            'Pastikan mikrofon terhubung dan diizinkan oleh sistem.',
        fixAction: 'Sambungkan mikrofon atau pilih perangkat input di Pengaturan.',
      ));
    }
  }

  // ── 2. Speaker loopback device (when recording speaker audio) ─────
  if (config.speakerEnabled) {
    final outputs = await bridge.listOutputAudioDevices();
    // Prefer explicitly-named loopback devices (BlackHole, Soundflower, WASAPI)
    final hasLoopback = outputs.any((d) =>
        d.name.toLowerCase().contains('blackhole') ||
        d.name.toLowerCase().contains('soundflower') ||
        d.name.toLowerCase().contains('loopback'));
    if (!hasLoopback && outputs.isEmpty) {
      // Speaker recording requested but no output devices at all
      warnings.add(const PreflightIssue(
        id: 'no_speaker_output',
        severity: PreflightSeverity.warning,
        title: 'Tidak ada perangkat output audio',
        description: 'Speaker audio tidak terdeteksi — perekaman suara '
            'speaker mungkin tidak tersedia.',
        fixAction: 'Pasang BlackHole atau periksa ulang pengaturan audio.',
      ));
    } else if (!hasLoopback) {
      // Outputs exist but no known loopback — user might not get speaker audio
      warnings.add(const PreflightIssue(
        id: 'no_loopback_device',
        severity: PreflightSeverity.warning,
        title: 'Loopback speaker tidak ditemukan',
        description: 'Tidak ada perangkat loopback audio (BlackHole/Soundflower) '
            '— rekaman suara speaker kemungkinan tidak akan aktif.',
        fixAction: 'Pasang BlackHole 2ch dan pilih sebagai perangkat output.',
      ));
    }
  }

  // ── 3. Model file existence ───────────────────────────────────────
  if (modelPath.isNotEmpty) {
    // Resolve tilde manually (File.resolve won't on all platforms)
    final resolved = modelPath.startsWith('~')
        ? modelPath.replaceFirst('~', Platform.environment['HOME'] ?? '')
        : modelPath;
    final modelFile = File(resolved);
    if (!modelFile.existsSync()) {
      blocking.add(PreflightIssue(
        id: 'model_missing',
        severity: PreflightSeverity.blocking,
        title: 'Model STT tidak ditemukan',
        description: 'File model "$modelPath" tidak ada di sistem.',
        fixAction: 'Unduh model dari Pengaturan > Perpustakaan.',
      ));
    } else {
      final stat = modelFile.statSync();
      if (stat.size < 10 * 1024) {
        // Suspicious — likely a placeholder or corrupt file
        blocking.add(PreflightIssue(
          id: 'model_too_small',
          severity: PreflightSeverity.blocking,
          title: 'File model terlalu kecil',
          description: 'Model "$modelPath" hanya ${stat.size} bytes — '
              'file mungkin rusak atau bukan model STT.',
          fixAction: 'Unduh ulang model dari Pengaturan > Perpustakaan.',
        ));
      }
    }
  }

  // ── 4. Disk space ─────────────────────────────────────────────────
  try {
    // SessionConfig has no libraryPath field — check the user's home dir,
    // which is where recordings land by default.
    final libPath = Platform.environment['HOME'] ?? '/tmp';
    // Walk up to find an accessible mount point for disk space
    Directory current = Directory(libPath);
    while (!await current.exists() && current.path != '/') {
      current = Directory(current.path.substring(0, current.path.lastIndexOf('/')));
    }
    if (await current.exists()) {
      // On Linux/macOS, check available bytes via Process.run df
      final result = await Process.run(
        'df', ['-B1', current.path],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          // df -B1 output: Filesystem  512-blocks  Used  Available  Capacity  Mounted
          // Available is in 512-byte blocks, multiply by 512 for bytes
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final availableBlocks = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableBlocks * 512;
            if (availableBytes < minimumFreeBytes) {
              final freeMB = (availableBytes / 1024 / 1024).round();
              blocking.add(PreflightIssue(
                id: 'low_disk',
                severity: PreflightSeverity.blocking,
                title: 'Ruang disk hampir habis',
                description: 'Hanya $freeMB MB tersedia di "$libPath". '
                    'Minimal 512 MB diperlukan untuk menyimpan rekaman.',
                fixAction: 'Kosongkan ruang disk atau ubah folder perpustakaan.',
              ));
            } else if (availableBytes < minimumFreeBytes * 4) {
              final freeMB = (availableBytes / 1024 / 1024).round();
              warnings.add(PreflightIssue(
                id: 'low_disk_warning',
                severity: PreflightSeverity.warning,
                title: 'Ruang disk terbatas',
                description: '$freeMB MB tersedia — pertimbangkan '
                    'mengosongkan disk jika merekam lama.',
                fixAction: 'Simpan file lama ke cloud atau hapus rekaman lama.',
              ));
            }
          }
        }
      }
    }
  } catch (_) {
    // Disk space check is non-critical; ignore errors
  }

  // ── 5. Memory pressure ────────────────────────────────────────────
  // Platform-specific: /proc/meminfo on Linux, vm_stat on macOS.
  try {
    final availableMB = await _availableMemoryMB();
    if (availableMB != null) {
      if (availableMB < 256) {
        blocking.add(PreflightIssue(
          id: 'memory_critical',
          severity: PreflightSeverity.blocking,
          title: 'Memori sangat rendah',
          description: 'Hanya ~$availableMB MB tersedia. '
              'Aplikasi mungkin tidak stabil saat merekam.',
          fixAction: 'Tutup aplikasi lain atau restart sistem.',
        ));
      } else if (availableMB < 1024) {
        warnings.add(PreflightIssue(
          id: 'memory_low',
          severity: PreflightSeverity.warning,
          title: 'Memori terbatas',
          description: '~$availableMB MB tersedia. '
              'Rekaman panjang mungkin terpengaruh.',
          fixAction: 'Tutup aplikasi lain untuk hasil optimal.',
        ));
      }
    }
  } catch (_) {
    // Non-critical — ignore memory check errors
  }

  return PreflightReport(blocking: blocking, warnings: warnings);
}

/// Returns approximate available memory in MB, or null if undeterminable.
Future<int?> _availableMemoryMB() async {
  if (Platform.isLinux) {
    final result = await Process.run('sh', ['-c', "awk '/MemAvailable/ {print int(\$2/1024)}' /proc/meminfo"]);
    if (result.exitCode == 0) return int.tryParse((result.stdout as String).trim());
  } else if (Platform.isMacOS) {
    final result = await Process.run('vm_stat', []);
    if (result.exitCode == 0) {
      final freePages = RegExp(r'Pages free:\s+(\d+)')
          .firstMatch(result.stdout as String)?.group(1);
      if (freePages != null) {
        final mb = int.parse(freePages) * 4096 ~/ (1024 * 1024);
        return mb;
      }
    }
  }
  return null;
}
