import 'dart:async';

import 'package:flutter/material.dart';

import '../services/bridge_service.dart';
import '../theme/app_colors.dart';

Future<bool> showModelDownloadDialog({
  required BuildContext context,
  required RustBridge bridge,
  required String modelId,
  required String modelsDir,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ModelDownloadDialog(
          bridge: bridge,
          modelId: modelId,
          modelsDir: modelsDir,
        ),
      ) ??
      false;
}

class _ModelDownloadDialog extends StatefulWidget {
  final RustBridge bridge;
  final String modelId;
  final String modelsDir;

  const _ModelDownloadDialog({
    required this.bridge,
    required this.modelId,
    required this.modelsDir,
  });

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  double _progress = 0.0;
  String _status = 'Memulai unduhan...';
  bool _done = false;
  bool _failed = false;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    _sub = widget.bridge.downloadProgress().listen(
      (ratio) {
        if (!mounted) return;
        setState(() {
          _progress = ratio.clamp(0.0, 1.0);
          _status = 'Mengunduh ${(ratio * 100).round()}%';
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _status = 'Gagal: $e';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _done = true;
          _progress = 1.0;
          _status = 'Selesai';
        });
      },
    );

    try {
      await widget.bridge.downloadModel(widget.modelsDir, widget.modelId);
      if (mounted) {
        setState(() {
          _done = true;
          _progress = 1.0;
          _status = 'Selesai';
        });
      }
      await _sub?.cancel();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await _sub?.cancel();
      if (mounted) {
        setState(() {
          _failed = true;
          _status = 'Gagal: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Mengunduh model ${widget.modelId}...',
        style: TextStyle(color: colors.text, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_status,
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _done || _failed ? () => Navigator.of(context).pop(!_failed) : null,
          child: Text(_failed ? 'Tutup' : 'Selesai',
              style: TextStyle(color: colors.primary)),
        ),
      ],
    );
  }
}
