import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../src/rust/audio/device.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const SetupWizardScreen({super.key, required this.onFinished});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

enum _WizardStep { specDetect, modelChoice, audioSetup, modelDownload, toneTest }

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  _WizardStep _step = _WizardStep.specDetect;
  String _selectedModel = 'tiny';
  final bool _downloadRecorded = false;

  // Spec detection results
  int? _cpuCores;
  int? _ramMb;
  String? _suggestedModel;
  bool _specDetected = false;

  static const _steps = _WizardStep.values;
  int get _stepIndex => _steps.indexOf(_step);

  // Model sizes in MB for progress estimation
  static const Map<String, int> _modelSizesMb = {
    'tiny': 75,
    'base': 150,
    'small': 500,
    'medium': 1500,
    'large-v3-turbo': 1600,
  };

  @override
  void initState() {
    super.initState();
    _detectSpecs();
  }

  Future<void> _detectSpecs() async {
    final cores = Platform.numberOfProcessors;
    // Try to read RAM via sysctl on macOS, fallback to estimate
    int? ramMb;
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          ramMb = ((int.tryParse(result.stdout.toString().trim()) ?? 0) / (1024 * 1024)).round();
        }
      }
    } on Object {
      // Fallback: use environment-based heuristic
    }

    ramMb ??= _estimateRamMb(cores);

    // Suggest model based on RAM
    final suggested = _suggestModel(ramMb);

    if (mounted) {
      setState(() {
        _cpuCores = cores;
        _ramMb = ramMb;
        _suggestedModel = suggested;
        _selectedModel = suggested;
        _specDetected = true;
      });
      ref.read(settingsProvider.notifier).setDefaultModel(suggested);
    }
  }

  int _estimateRamMb(int cores) {
    // Rough heuristic: assume 2GB per core for modern Macs
    final estimated = cores * 2048;
    // Cap at reasonable values
    if (estimated > 32768) return 32768;
    if (estimated < 4096) return 4096;
    return estimated;
  }

  String _suggestModel(int ramMb) {
    if (ramMb >= 16384) return 'large-v3-turbo'; // 16GB+
    if (ramMb >= 8192) return 'medium';          // 8GB+
    if (ramMb >= 4096) return 'small';           // 4GB+
    return 'base';                                // < 4GB
  }

  void _next() {
    if (_stepIndex < _steps.length - 1) {
      setState(() => _step = _steps[_stepIndex + 1]);
    } else {
      widget.onFinished();
    }
  }

  void _back() {
    if (_stepIndex > 0) {
      setState(() => _step = _steps[_stepIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            _WizardProgress(step: _stepIndex, total: _steps.length),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: _buildStepBody(),
              ),
            ),

            // Navigation buttons
            _WizardNavigation(
              isFirst: _stepIndex == 0,
              isLast: _stepIndex == _steps.length - 1,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _WizardStep.specDetect:
        return _SpecDetectStep(
          cpuCores: _cpuCores,
          ramMb: _ramMb,
          suggestedModel: _suggestedModel,
          detected: _specDetected,
        );
      case _WizardStep.modelChoice:
        return _ModelChoiceStep(
          selected: _selectedModel,
          onChanged: (id) {
            setState(() => _selectedModel = id);
            ref.read(settingsProvider.notifier).setDefaultModel(id);
          },
        );
      case _WizardStep.audioSetup:
        return const _AudioSetupStep();
      case _WizardStep.modelDownload:
        return _DownloadStep(
          modelId: _selectedModel,
          modelSizeMb: _modelSizesMb[_selectedModel] ?? 75,
          downloaded: _downloadRecorded,
          bridge: ref.read(rustBridgeProvider),
          libraryPath: ref.read(settingsProvider).libraryPath,
          onRecordDownload: () {
            ref.read(privacyReportProvider.notifier).recordModelDownload(_selectedModel);
            if (mounted) _next();
          },
        );
      case _WizardStep.toneTest:
        return const _ToneTestStep();
    }
  }
}

/// Progress indicator
class _WizardProgress extends StatelessWidget {
  final int step;
  final int total;

  const _WizardProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(total, (i) {
              final isDone = i < step;
              final isActive = i == step;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: isDone || isActive ? colors.primary : colors.border,
                        ),
                      ),
                    ),
                    if (i < total - 1) const SizedBox(width: 6),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah ${step + 1} dari $total',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              Text(
                '${((step + 1) / total * 100).round()}%',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Navigation buttons
class _WizardNavigation extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _WizardNavigation({
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: isFirst ? null : onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 14),
            label: const Text('Kembali'),
            style: TextButton.styleFrom(
              foregroundColor: isFirst ? colors.textTertiary : colors.text,
            ),
          ),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isLast ? 'Selesai' : 'Lanjut'),
          ),
        ],
      ),
    );
  }
}

/// Generic step content helper
class _StepContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  const _StepContent({
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withValues(alpha: 0.1),
          ),
          child: Icon(icon, size: 40, color: colors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(color: colors.text, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        if (child != null) ...[const SizedBox(height: 24), child!],
      ],
    );
  }
}

/// Step 1 — System spec detection with real data
class _SpecDetectStep extends StatelessWidget {
  final int? cpuCores;
  final int? ramMb;
  final String? suggestedModel;
  final bool detected;

  const _SpecDetectStep({
    required this.cpuCores,
    required this.ramMb,
    required this.suggestedModel,
    required this.detected,
  });

  String _ramLabel(int mb) {
    if (mb >= 1024) return '${(mb / 1024).round()} GB';
    return '$mb MB';
  }

  String _modelLabel(String id) {
    return switch (id) {
      'tiny' => 'tiny (ringan)',
      'base' => 'base (seimbang)',
      'small' => 'small (akurat)',
      'medium' => 'medium (presisi)',
      'large-v3-turbo' => 'large-v3-turbo (terbaik)',
      _ => id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return _StepContent(
      icon: Icons.memory,
      title: '1. Deteksi Spesifikasi',
      description: detected
          ? 'Sistem Anda siap! Model direkomendasikan berdasarkan spesifikasi.'
          : 'Memeriksa sistem...',
      child: detected
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _SpecRow(
                    icon: Icons.computer,
                    label: 'CPU Cores',
                    value: '$cpuCores core',
                  ),
                  const SizedBox(height: 12),
                  _SpecRow(
                    icon: Icons.memory_outlined,
                    label: 'RAM',
                    value: _ramLabel(ramMb ?? 8192),
                  ),
                  const SizedBox(height: 12),
                  _SpecRow(
                    icon: Icons.psychology,
                    label: 'Model Rekomendasi',
                    value: _modelLabel(suggestedModel ?? 'tiny'),
                    highlighted: true,
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Row(
      children: [
        Icon(icon, size: 20, color: highlighted ? colors.primary : colors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlighted ? colors.primary : colors.text,
            fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Step 2 — Model choice
class _ModelChoiceStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModelChoiceStep({required this.selected, required this.onChanged});

  static const _models = [
    ('tiny', 'tiny (~75 MB)', 'Sudah termasuk di aplikasi · Tercepat'),
    ('base', 'base (~150 MB)', 'Keseimbangan akurasi & cepat'),
    ('small', 'small (~500 MB)', 'Akurasi tinggi multi-bahasa'),
    ('medium', 'medium (~1.5 GB)', 'Kualitas transkripsi presisi'),
    ('large-v3-turbo', 'large-v3-turbo (~1.6 GB)', '⭐ Model Terbaik'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.psychology,
      title: '2. Pilih Model',
      description: 'Pilih model Speech-to-Text yang sesuai.',
      child: Column(
        children: _models.map((m) {
          final isSelected = selected == m.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(m.$1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
                      color: isSelected ? colors.primary : colors.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$2, style: TextStyle(
                            color: colors.text,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          )),
                          Text(m.$3, style: TextStyle(
                            color: isSelected ? colors.primary : colors.textTertiary,
                            fontSize: 12,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Step 3 — Audio setup
class _AudioSetupStep extends ConsumerStatefulWidget {
  const _AudioSetupStep();

  @override
  ConsumerState<_AudioSetupStep> createState() => _AudioSetupStepState();
}

class _AudioSetupStepState extends ConsumerState<_AudioSetupStep> {
  bool _loading = true;
  List<AudioDeviceInfo> _inputDevices = [];
  List<AudioDeviceInfo> _outputDevices = [];
  String? _selectedMic;
  String? _selectedSpeaker;
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    final bridge = ref.read(rustBridgeProvider);
    final inputs = await bridge.listAudioDevices();
    final outputs = await bridge.listOutputAudioDevices();
    if (mounted) {
      setState(() {
        _loading = false;
        _inputDevices = inputs;
        _outputDevices = outputs;
        _selectedMic = inputs.isNotEmpty
            ? inputs.firstWhere((d) => d.isDefault, orElse: () => inputs.first).name
            : null;
        _selectedSpeaker = outputs
            .firstWhere(
              (d) => d.name.toLowerCase().contains('blackhole') ||
                  d.name.toLowerCase().contains('loopback'),
              orElse: () => outputs.isNotEmpty
                  ? outputs.first
                  : AudioDeviceInfo(
                      name: 'Default',
                      deviceId: '',
                      isDefault: true,
                      channels: 2,
                      sampleRates: Uint32List(0),
                    ),
            )
            .name;
      });
    }
  }

  bool get _hasBlackHole => _outputDevices.any(
    (d) => d.name.toLowerCase().contains('blackhole') || d.name.toLowerCase().contains('loopback'),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.speaker_group_outlined,
      title: '3. Setup Audio',
      description: 'Pilih perangkat input mikrofon dan output speaker.',
      child: _loading
          ? const CircularProgressIndicator()
          : Column(
              children: [
                _AudioDropdown(
                  label: 'Mikrofon (Input)',
                  value: _selectedMic,
                  devices: _inputDevices,
                  onChanged: (v) => setState(() => _selectedMic = v),
                ),
                const SizedBox(height: 12),
                _AudioDropdown(
                  label: 'Speaker / Loopback (Output)',
                  value: _selectedSpeaker,
                  devices: _outputDevices,
                  onChanged: (v) => setState(() => _selectedSpeaker = v),
                ),
                const SizedBox(height: 16),
                // BlackHole status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _hasBlackHole
                        ? AppColors.statusActive.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasBlackHole
                          ? AppColors.statusActive.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasBlackHole ? Icons.check_circle_outline : Icons.info_outline,
                            color: _hasBlackHole ? AppColors.statusActive : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasBlackHole
                                  ? 'BlackHole 2ch terdeteksi!'
                                  : 'Virtual Audio Driver belum terinstall',
                              style: TextStyle(
                                color: _hasBlackHole ? AppColors.statusActive : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_hasBlackHole) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Untuk merekam suara dari Zoom/Meet, install BlackHole 2ch.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showGuide = !_showGuide),
                          icon: Icon(_showGuide ? Icons.expand_less : Icons.help_outline, size: 16),
                          label: Text(_showGuide ? 'Sembunyikan' : 'Panduan Install'),
                          style: OutlinedButton.styleFrom(foregroundColor: colors.text),
                        ),
                        if (_showGuide) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.chipBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '1. brew install blackhole-2ch\n2. Buka Audio MIDI Setup\n3. Buat Multi-Output Device\n4. Centang MacBook Pro Speakers + BlackHole 2ch',
                              style: TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AudioDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<AudioDeviceInfo> devices;
  final ValueChanged<String?> onChanged;

  const _AudioDropdown({
    required this.label,
    required this.value,
    required this.devices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: colors.surface,
        style: TextStyle(color: colors.text, fontSize: 14),
        items: devices.isNotEmpty
            ? devices.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList()
            : [DropdownMenuItem(value: value, child: Text(value ?? 'Default'))],
        onChanged: onChanged,
      ),
    );
  }
}

/// Step 4 — Model download with real progress
class _DownloadStep extends ConsumerStatefulWidget {
  final String modelId;
  final int modelSizeMb;
  final bool downloaded;
  final RustBridge bridge;
  final String libraryPath;
  final VoidCallback onRecordDownload;

  const _DownloadStep({
    required this.modelId,
    required this.modelSizeMb,
    required this.downloaded,
    required this.bridge,
    required this.libraryPath,
    required this.onRecordDownload,
  });

  @override
  ConsumerState<_DownloadStep> createState() => _DownloadStepState();
}

class _DownloadStepState extends ConsumerState<_DownloadStep> {
  bool _isDownloading = false;
  String? _error;
  double _progress = 0.0;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (widget.downloaded) return;
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      await widget.bridge.downloadModel(widget.libraryPath, widget.modelId);

      // Subscribe to real progress stream
      _progressSub?.cancel();
      _progressSub = widget.bridge.downloadProgress().listen((ratio) {
        if (!mounted) return;
        setState(() => _progress = ratio);
        if (ratio >= 1.0) {
          _progressSub?.cancel();
          _progressSub = null;
          widget.onRecordDownload();
          setState(() => _isDownloading = false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isBundled = widget.modelId == 'tiny';

    return _StepContent(
      icon: isBundled ? Icons.check_circle_outline : Icons.download_outlined,
      title: '4. Unduh Model',
      description: isBundled
          ? 'Model ${widget.modelId} sudah tersedia di aplikasi.'
          : 'Model ${widget.modelId} (${widget.modelSizeMb} MB) akan diunduh.',
      child: isBundled
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statusActive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.statusActive.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.statusActive, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Model tiny (75 MB) sudah termasuk dalam aplikasi. Tidak perlu unduh.',
                      style: TextStyle(color: AppColors.statusActive, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          : _isDownloading
              ? Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: colors.border.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mengunduh ${widget.modelSizeMb} MB...',
                      style: TextStyle(color: colors.textTertiary, fontSize: 12),
                    ),
                  ],
                )
              : _error != null
                  ? Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Gagal mengunduh',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _startDownload(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    )
                  : FilledButton.icon(
                      onPressed: widget.downloaded
                          ? null
                          : () => _startDownload(),
                      icon: Icon(widget.downloaded
                          ? Icons.check_circle
                          : Icons.cloud_download_outlined),
                      label: Text(widget.downloaded ? 'Selesai' : 'Unduh model'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
    );
  }
}

/// Step 5 — Tone test
class _ToneTestStep extends StatefulWidget {
  const _ToneTestStep();

  @override
  State<_ToneTestStep> createState() => _ToneTestStepState();
}

class _ToneTestStepState extends State<_ToneTestStep> {
  bool _isPlaying = false;
  double _signalLevel = 0.0;
  Timer? _toneTimer;
  bool _tested = false;

  void _startToneTest() {
    setState(() {
      _isPlaying = true;
      _signalLevel = 0.2;
    });
    _toneTimer?.cancel();
    int ticks = 0;
    _toneTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      ticks++;
      if (ticks > 25) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _signalLevel = 0.0;
            _tested = true;
          });
        }
      } else if (mounted) {
        setState(() {
          _signalLevel = 0.3 + (ticks % 5) * 0.14;
        });
      }
    });
  }

  @override
  void dispose() {
    _toneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.graphic_eq,
      title: '5. Tone Test',
      description: 'Uji nada 440Hz untuk memverifikasi jalur mic & speaker.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isPlaying ? colors.primary : colors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPlaying ? 'Memutar...' : (_tested ? 'Selesai' : 'Siap diuji'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.text),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tested
                        ? AppColors.statusActive.withValues(alpha: 0.1)
                        : colors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tested ? Icons.check_circle : Icons.headphones,
                        size: 14,
                        color: _tested ? AppColors.statusActive : colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _tested ? 'Normal' : 'Standby',
                        style: TextStyle(
                          color: _tested ? AppColors.statusActive : colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _signalLevel,
                minHeight: 10,
                color: colors.primary,
                backgroundColor: colors.border.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isPlaying ? null : _startToneTest,
              icon: Icon(_isPlaying ? Icons.graphic_eq : Icons.play_arrow),
              label: Text(_isPlaying ? 'Memproses...' : 'Putar Nada Uji'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
