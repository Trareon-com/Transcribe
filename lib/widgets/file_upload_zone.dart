import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/batch_upload_model.dart';
import '../theme/app_colors.dart';

class FileUploadZone extends ConsumerStatefulWidget {
  const FileUploadZone({super.key});

  @override
  ConsumerState<FileUploadZone> createState() => _FileUploadZoneState();
}

class _FileUploadZoneState extends ConsumerState<FileUploadZone> {
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'opus', 'mp4', 'mov', 'mkv',
      ],
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    _addFiles(paths);
  }

  void _addFiles(List<String> paths) {
    final rejected = ref.read(batchUploadProvider.notifier).addFiles(paths);
    if (rejected.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rejected.length} file dengan format tidak didukung dilewati.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(batchUploadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            _addFiles(details.files.map((f) => f.path).toList());
          },
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: _dragging ? AppColors.micAccent : Theme.of(context).dividerColor,
                width: _dragging ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _dragging ? AppColors.micAccent.withValues(alpha: 0.08) : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upload_file_outlined, size: 32),
                  const SizedBox(height: 8),
                  const Text('Tarik & lepas file audio/video ke sini'),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _pickFiles, child: const Text('Pilih File')),
                ],
              ),
            ),
          ),
        ),
        if (queue.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: queue.any((entry) => entry.status == BatchFileStatus.done)
                    ? () => ref.read(batchUploadProvider.notifier).removeDone()
                    : null,
                icon: const Icon(Icons.clear_all),
                label: const Text('Hapus selesai'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => ref.read(batchUploadProvider.notifier).clear(),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Kosongkan'),
              ),
            ],
          ),
          ...queue.map((entry) => _QueueTile(entry: entry)),
        ],
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  final BatchFileEntry entry;

  const _QueueTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _statusIcon(entry.status),
      title: Text(entry.filename, overflow: TextOverflow.ellipsis),
      subtitle: entry.error != null ? Text(entry.error!) : null,
    );
  }

  Widget _statusIcon(BatchFileStatus status) {
    return switch (status) {
      BatchFileStatus.queued => const Icon(Icons.schedule),
      BatchFileStatus.decoding => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      BatchFileStatus.transcribing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      BatchFileStatus.done => const Icon(Icons.check_circle, color: AppColors.micAccent),
      BatchFileStatus.error => const Icon(Icons.error, color: AppColors.warning),
    };
  }
}
