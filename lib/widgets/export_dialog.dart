import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bridge_service.dart';
import '../src/rust/export.dart' as rust_export;
import '../state/models.dart';
import '../theme/app_colors.dart';

/// Dialog for selecting export formats and output directory.
/// Returns true if the export was initiated, false if cancelled.
Future<bool> showExportDialog(
  BuildContext context,
  SessionSummary session, {
  required RustBridge bridge,
  String defaultOutputDir = '',
}) async {
  final selected = <String>{'md', 'json', 'txt'};

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) {
        final colors = Theme.of(dialogCtx).extension<AppColorSet>() ?? AppColors.light;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Icon(Icons.upload_outlined, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Export "${session.title}"',
                  style: TextStyle(color: colors.text, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih format export:',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final format in const [
                    ('md', 'Markdown', 'Dengan timestamp & label speaker', Icons.description_outlined),
                    ('txt', 'TXT', 'Plain text tanpa timestamp', Icons.text_snippet_outlined),
                    ('json', 'JSON', 'Full metadata terstruktur', Icons.data_object_outlined),
                    ('srt', 'SRT', 'Subtitle format', Icons.closed_caption_outlined),
                    ('vtt', 'VTT', 'Web subtitle', Icons.language_outlined),
                    ('html', 'HTML', 'Dokumen dengan styling', Icons.web_outlined),
                  ])
                    CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(format.$2, style: TextStyle(color: colors.text, fontSize: 14)),
                      subtitle: Text(format.$3, style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                      secondary: Icon(format.$4, size: 18, color: selected.contains(format.$1) ? colors.primary : colors.textTertiary),
                      value: selected.contains(format.$1),
                      activeColor: colors.primary,
                      checkColor: colors.onPrimary,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(format.$1);
                          } else {
                            selected.remove(format.$1);
                          }
                        });
                      },
                    ),
                  const Divider(height: 16),
                  Text(
                    'Semua file dalam 1 folder',
                    style: TextStyle(color: colors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton.icon(
              onPressed: selected.isEmpty ? null : () => Navigator.of(dialogCtx).pop(true),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Pilih Folder'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  final outputDir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Pilih folder ekspor untuk "${session.title}"',
    initialDirectory: defaultOutputDir.isNotEmpty ? defaultOutputDir : null,
  );
  if (outputDir == null || !context.mounted) return false;

  final formats = <rust_export.ExportFormat>[
    if (selected.contains('md')) rust_export.ExportFormat.markdown,
    if (selected.contains('txt')) rust_export.ExportFormat.txt,
    if (selected.contains('json')) rust_export.ExportFormat.json,
    if (selected.contains('srt')) rust_export.ExportFormat.srt,
    if (selected.contains('vtt')) rust_export.ExportFormat.vtt,
    if (selected.contains('html')) rust_export.ExportFormat.html,
  ];

  try {
    await bridge.exportSession(
      segments: session.segments,
      outputDir: outputDir,
      title: session.title,
      formats: formats,
    );
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export berhasil ke: $outputDir'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export gagal: $e'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
}
