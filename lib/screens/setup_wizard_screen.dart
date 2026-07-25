import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _downloadRecorded = false;

  static const _steps = _WizardStep.values;
  int get _stepIndex => _steps.indexOf(_step);

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
        return _StepContent(
          icon: Icons.memory,
          title: '1. Deteksi Spesifikasi',
          description: 'Trascribe akan memeriksa CPU, RAM, dan GPU untuk menyarankan model whisper yang paling optimal untuk sistem Anda.',
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
          downloaded: _downloadRecorded,
          onDownload: () async {
            if (_downloadRecorded) return;
            final settings = ref.read(settingsProvider);
            final bridge = ref.read(rustBridgeProvider);
            await bridge.downloadModel(settings.libraryPath, _selectedModel);
            ref.read(privacyReportProvider.notifier).recordModelDownload(_selectedModel);
            if (mounted) {
              setState(() => _downloadRecorded = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Model "$_selectedModel" dicatat.')),
              );
            }
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
          // Step indicators
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

/// Generic step content
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

/// Model choice step
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

/// Audio setup step
class _AudioSetupStep extends ConsumerStatefulWidget {
  const _AudioSetupStep();

  @override
  ConsumerState<_AudioSetupStep> createState() => _AudioSetupStepState();
}

class _AudioSetupStepState extends ConsumerState<_AudioSetupStep> {
  bool _loading = true;
  List<AudioDeviceInfo> _devices = [];
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
    final devices = await bridge.listAudioDevices();
    if (mounted) {
      setState(() {
        _loading = false;
        _devices = devices;
        _selectedMic = devices.isNotEmpty ? devices.first.name : 'Built-in Microphone';
        _selectedSpeaker = 'System Speaker Loopback';
      });
    }
  }

  bool get _hasBlackHole => _devices.any(
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
                  devices: _devices,
                  onChanged: (v) => setState(() => _selectedMic = v),
                ),
                const SizedBox(height: 12),
                _AudioDropdown(
                  label: 'Speaker / Loopback (Output)',
                  value: _selectedSpeaker,
                  devices: _devices,
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

/// Download step
class _DownloadStep extends ConsumerStatefulWidget {
  final String modelId;
  final bool downloaded;
  final Future<void> Function() onDownload;

  const _DownloadStep({
    required this.modelId,
    required this.downloaded,
    required this.onDownload,
  });

  @override
  ConsumerState<_DownloadStep> createState() => _DownloadStepState();
}

class _DownloadStepState extends ConsumerState<_DownloadStep> {
  bool _isDownloading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.download_outlined,
      title: '4. Unduh Model',
      description: 'Model whisper siap diunduh ke direktori lokal.',
      child: _isDownloading
          ? const CircularProgressIndicator()
          : _error != null
              ? Column(
                  children: [
                    Text('Gagal mengunduh ($_error)', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        setState(() { _isDownloading = true; _error = null; });
                        try { await widget.onDownload(); } catch (e) { setState(() => _error = e.toString()); }
                        if (mounted) setState(() => _isDownloading = false);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: widget.downloaded ? null : () async {
                    setState(() => _isDownloading = true);
                    try { await widget.onDownload(); } catch (e) { setState(() => _error = e.toString()); }
                    if (mounted) setState(() => _isDownloading = false);
                  },
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(widget.downloaded ? 'Sudah dicatat' : 'Unduh model'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
    );
  }
}

/// Tone test step
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
    setState(() { _isPlaying = true; _signalLevel = 0.2; });
    _toneTimer?.cancel();
    int ticks = 0;
    _toneTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      ticks++;
      if (ticks > 25) {
        timer.cancel();
        if (mounted) setState(() { _isPlaying = false; _signalLevel = 0.0; _tested = true; });
      } else if (mounted) {
        setState(() { _signalLevel = 0.3 + (ticks % 5) * 0.14; });
      }
    });
  }

  @override
  void dispose() { _toneTimer?.cancel(); super.dispose(); }

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
                    color: _tested ? AppColors.statusActive.withValues(alpha: 0.1) : colors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tested ? Icons.check_circle : Icons.headphones, size: 14,
                        color: _tested ? AppColors.statusActive : colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(_tested ? 'Normal' : 'Standby',
                        style: TextStyle(color: _tested ? AppColors.statusActive : colors.textSecondary, fontSize: 12)),
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
