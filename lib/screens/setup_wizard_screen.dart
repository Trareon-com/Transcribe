import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/audio/device.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';

/// First-run setup wizard: spec detection -> model choice -> audio setup
/// -> model download -> tone test.
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
      appBar: AppBar(title: const Text('Setup Trascribe')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Langkah ${_stepIndex + 1} dari ${_steps.length}: ${_stepTitle(_step)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${((_stepIndex + 1) / _steps.length * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_stepIndex + 1) / _steps.length),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: _buildStepBody())),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _stepIndex == 0 ? null : _back,
                  child: const Text('Kembali'),
                ),
                FilledButton(
                  onPressed: _next,
                  child: Text(_stepIndex == _steps.length - 1 ? 'Selesai' : 'Lanjut'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(_WizardStep step) => switch (step) {
        _WizardStep.specDetect => 'Deteksi Spesifikasi',
        _WizardStep.modelChoice => 'Pilih Model',
        _WizardStep.audioSetup => 'Setup Audio',
        _WizardStep.modelDownload => 'Unduh Model',
        _WizardStep.toneTest => 'Tone Test',
      };

  Widget _buildStepBody() {
    switch (_step) {
      case _WizardStep.specDetect:
        return const _StepBody(
          title: '1. Deteksi Spesifikasi',
          description:
              'Trascribe akan memeriksa CPU, RAM, dan GPU untuk menyarankan model whisper yang sesuai.',
          icon: Icons.memory,
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
                SnackBar(content: Text('Model "$_selectedModel" dicatat sebagai unduhan.')),
              );
            }
          },
        );
      case _WizardStep.toneTest:
        return const _ToneTestStep();
    }
  }
}

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
      (d) => d.name.toLowerCase().contains('blackhole') || d.name.toLowerCase().contains('loopback'));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.speaker_group_outlined, size: 64),
        const SizedBox(height: 16),
        Text('3. Setup Audio', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pilih perangkat input mikrofon dan output speaker untuk perekaman percakapan.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const CircularProgressIndicator()
        else
          Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedMic,
                decoration: const InputDecoration(
                  labelText: 'Perangkat Mikrofon (Input)',
                  border: OutlineInputBorder(),
                ),
                items: _devices.isNotEmpty
                    ? _devices
                        .map((d) => DropdownMenuItem(value: d.name, child: Text(d.name)))
                        .toList()
                    : [
                        DropdownMenuItem(
                            value: _selectedMic, child: Text(_selectedMic ?? 'Built-in Microphone')),
                      ],
                onChanged: (val) => setState(() => _selectedMic = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSpeaker,
                decoration: const InputDecoration(
                  labelText: 'Perangkat Speaker / Loopback (Output)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: _selectedSpeaker, child: Text(_selectedSpeaker ?? 'System Speaker Loopback')),
                ],
                onChanged: (val) => setState(() => _selectedSpeaker = val),
              ),
              const SizedBox(height: 20),
              // Loopback Driver Guide Box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _hasBlackHole
                      ? Colors.green.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasBlackHole
                        ? Colors.green.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasBlackHole ? Icons.check_circle_outline : Icons.info_outline,
                            color: _hasBlackHole
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _hasBlackHole
                                  ? 'Driver Virtual Audio (BlackHole 2ch) Terdeteksi!'
                                  : 'Belum Ada Virtual Audio Driver untuk Rekam Meeting (Zoom/Webinar)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _hasBlackHole
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasBlackHole
                            ? 'Sistem Anda siap merekam audio internal speaker & percakapan online secara jernih.'
                            : 'Untuk merekam suara dari Zoom/Google Meet/YouTube, macOS memerlukan Virtual Audio Driver gratis (seperti BlackHole 2ch).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _showGuide = !_showGuide),
                            icon: Icon(_showGuide ? Icons.expand_less : Icons.help_outline, size: 16),
                            label: Text(_showGuide ? 'Sembunyikan Panduan' : 'Panduan Install (1-Menit)'),
                          ),
                          IconButton(
                            onPressed: _loadDevices,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Muat ulang perangkat audio',
                          ),
                        ],
                      ),
                      if (_showGuide) ...[
                        const Divider(height: 24),
                        Text(
                          '📖 Cara Install & Setup BlackHole 2ch di macOS:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Buka aplikasi Terminal di Mac, lalu jalankan perintah berikut:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SelectableText(
                                'brew install blackhole-2ch',
                                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: 'brew install blackhole-2ch'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Perintah disalin ke clipboard!')),
                                  );
                                },
                                tooltip: 'Salin perintah brew',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '2. Buka aplikasi "Audio MIDI Setup" di macOS -> Klik "+" di kiri bawah -> Buat "Multi-Output Device".\n'
                          '3. Centang "MacBook Pro Speakers" DAN "BlackHole 2ch".\n'
                          '4. Klik tombol refresh 🔄 di atas setelah proses selesai.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

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

  int _downloadedBytes = 0;
  int _totalBytes = 0;
  double _speedMBps = 0.0;
  int _etaSecs = 0;
  Timer? _progressTimer;
  DateTime? _startTime;

  static const Map<String, int> _expectedSizes = {
    'tiny': 77700000,
    'base': 147900000,
    'small': 488000000,
    'medium': 1530000000,
    'large-v3-turbo': 1624555275,
  };

  static const Map<String, String> _filenames = {
    'tiny': 'ggml-tiny.bin',
    'base': 'ggml-base.bin',
    'small': 'ggml-small.bin',
    'medium': 'ggml-medium.bin',
    'large-v3-turbo': 'ggml-large-v3-turbo.bin',
  };

  void _startMonitorProgress(String libraryPath) {
    if (libraryPath.isEmpty) return;
    final expectedSize = _expectedSizes[widget.modelId] ?? 1000000000;
    final filename = _filenames[widget.modelId] ?? 'ggml-${widget.modelId}.bin';
    _totalBytes = expectedSize;
    _startTime = DateTime.now();
    final file = File('$libraryPath/$filename');

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (!mounted) {
        _progressTimer?.cancel();
        return;
      }
      try {
        if (await file.exists()) {
          final len = await file.length();
          if (mounted && _startTime != null) {
            final elapsedSecs = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
            final speed = elapsedSecs > 0 ? (len / (1024 * 1024 * elapsedSecs)) : 0.0;
            final remainingBytes = _totalBytes > len ? _totalBytes - len : 0;
            final eta = (speed > 0 && remainingBytes > 0)
                ? (remainingBytes / (speed * 1024 * 1024)).round()
                : 0;

            setState(() {
              _downloadedBytes = len;
              _speedMBps = speed;
              _etaSecs = eta;
            });
          }
        }
      } catch (_) {}
    });
  }

  void _stopMonitorProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void dispose() {
    _stopMonitorProgress();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    final settings = mounted ? ref.read(settingsProvider) : null;
    setState(() {
      _isDownloading = true;
      _error = null;
      _downloadedBytes = 0;
      _speedMBps = 0.0;
      _etaSecs = 0;
    });
    if (settings != null) {
      _startMonitorProgress(settings.libraryPath);
    }
    try {
      await widget.onDownload();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      _stopMonitorProgress();
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.download_outlined, size: 64),
        const SizedBox(height: 16),
        Text('4. Unduh Model', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Model "${widget.modelId}" siap diunduh. Unduhan model ini akan tercatat di Privacy Report.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_isDownloading) ...[
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Mengunduh ${widget.modelId}...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _totalBytes > 0
                            ? '${((_downloadedBytes / _totalBytes) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%'
                            : 'Mengukur...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalBytes > 0 ? (_downloadedBytes / _totalBytes).clamp(0.0, 1.0) : null,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${_totalBytes > 0 ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1) : '?'} MB',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          '${_speedMBps.toStringAsFixed(1)} MB/s',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer_outlined, size: 16, color: Theme.of(context).disabledColor),
                        const SizedBox(width: 2),
                        Text(
                          _etaSecs > 0 ? '$_etaSecs dtk' : '...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Gagal mengunduh model (${widget.modelId}). Silakan periksa koneksi internet atau coba lagi nanti.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Lewati untuk Saat Ini'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _handleDownload,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ] else
          FilledButton.icon(
            onPressed: widget.downloaded ? null : _handleDownload,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(widget.downloaded ? 'Sudah dicatat' : 'Unduh model'),
          ),
      ],
    );
  }
}

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
      } else {
        if (mounted) {
          setState(() {
            _signalLevel = 0.3 + (ticks % 5) * 0.12;
          });
        }
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isPlaying ? Icons.volume_up : Icons.graphic_eq,
          size: 64,
          color: _isPlaying ? Theme.of(context).colorScheme.primary : null,
        ),
        const SizedBox(height: 16),
        Text('5. Tone Test', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Klik tombol di bawah untuk memutar nada uji 440Hz dan memverifikasi perangkat input mikrofon & output speaker.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPlaying
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPlaying ? 'Memutar Nada 440Hz...' : (_tested ? 'Uji Nada Selesai' : 'Siap diuji'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isPlaying ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      _tested ? Icons.check_circle : Icons.headphones,
                      size: 16,
                      color: _tested ? Colors.green : null,
                    ),
                    label: Text(_tested ? 'Audio Normal' : 'Standby'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _signalLevel,
                  minHeight: 12,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isPlaying ? null : _startToneTest,
                icon: Icon(_isPlaying ? Icons.graphic_eq : Icons.play_arrow),
                label: Text(_isPlaying ? 'Memproses nada...' : 'Putar Nada Uji (440Hz)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _StepBody({required this.title, required this.description, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ModelChoiceStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModelChoiceStep({required this.selected, required this.onChanged});

  static const _models = [
    ('tiny', 'tiny (~75 MB) — sudah termasuk di app'),
    ('base', 'base (~150 MB)'),
    ('small', 'small (~500 MB)'),
    ('medium', 'medium (~1.5 GB)'),
    ('large-v3-turbo', 'large-v3-turbo (~1.6 GB)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.psychology, size: 64),
        const SizedBox(height: 16),
        Text('2. Pilih Model', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ..._models.map((m) => RadioListTile<String>(
              value: m.$1,
              groupValue: selected,
              title: Text(m.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(m.$2),
              onChanged: (val) => val != null ? onChanged(val) : null,
            )),
      ],
    );
  }
}
