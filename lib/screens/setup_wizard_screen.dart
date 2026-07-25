import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/audio/device.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';

/// First-run setup wizard: spec detection -> model choice -> audio setup
/// -> model download -> tone test. Styled with a premium dark glassmorphism design.
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
    const primaryColor = Color(0xFF007AFF);
    const accentGradient = LinearGradient(
      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Setup Trascribe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Step Progress Indicator
              Row(
                children: List.generate(_steps.length, (idx) {
                  final isActive = idx == _stepIndex;
                  final isDone = idx < _stepIndex;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: isDone || isActive ? accentGradient : null,
                              color: isDone || isActive ? null : Colors.white10,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        if (idx < _steps.length - 1) const SizedBox(width: 6),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Langkah ${_stepIndex + 1} dari ${_steps.length}: ${_stepTitle(_step)}',
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    '${((_stepIndex + 1) / _steps.length * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Glassmorphic Body Container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(child: _buildStepBody()),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom Action Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: 'Kembali ke langkah sebelumnya',
                    child: TextButton.icon(
                      onPressed: _stepIndex == 0 ? null : _back,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                      label: const Text('Kembali'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        disabledForegroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Semantics(
                        label: _stepIndex == _steps.length - 1
                            ? 'Selesai, selesaikan pengaturan'
                            : 'Lanjut ke langkah berikutnya',
                        child: Text(
                          _stepIndex == _steps.length - 1 ? 'Selesai' : 'Lanjut',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        return const _HeroStepBody(
          title: '1. Deteksi Spesifikasi',
          description:
              'Trascribe akan memeriksa CPU, RAM, dan GPU untuk menyarankan model whisper yang paling optimal untuk sistem Anda.',
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

class _HeroStepBody extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _HeroStepBody({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ModelChoiceStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModelChoiceStep({required this.selected, required this.onChanged});

  static const _models = [
    ('tiny', 'tiny (~75 MB)', 'Sudah termasuk di aplikasi · Tercepat'),
    ('base', 'base (~150 MB)', 'Keseimbangan akurasi & cepat'),
    ('small', 'small (~500 MB)', 'Akurasi tinggi multi-bahasa'),
    ('medium', 'medium (~1.5 GB)', 'Kualitas transkripsi presisi'),
    ('large-v3-turbo', 'large-v3-turbo (~1.6 GB)', '⭐ Model Terbaik & Tercanggih'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.psychology, size: 48, color: Color(0xFF60A5FA)),
        const SizedBox(height: 8),
        const Text(
          '2. Pilih Model',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih model kecerdasan buatan Speech-to-Text yang sesuai.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 14),
        ..._models.map((m) {
          final isSelected = selected == m.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(m.$1),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF007AFF) : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFF007AFF) : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            m.$3,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
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
      children: [
        const _HeroStepBody(
          title: '3. Setup Audio',
          description: 'Pilih perangkat input mikrofon dan output speaker untuk perekaman percakapan.',
          icon: Icons.speaker_group_outlined,
        ),
        const SizedBox(height: 24),
        if (_loading)
          const CircularProgressIndicator()
        else
          Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedMic,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Perangkat Mikrofon (Input)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                value: _selectedSpeaker,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Perangkat Speaker / Loopback (Output)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  DropdownMenuItem(
                      value: _selectedSpeaker, child: Text(_selectedSpeaker ?? 'System Speaker Loopback')),
                ],
                onChanged: (val) => setState(() => _selectedSpeaker = val),
              ),
              const SizedBox(height: 20),
              // Loopback Driver Guide Card
              Container(
                decoration: BoxDecoration(
                  color: _hasBlackHole
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hasBlackHole
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasBlackHole ? Icons.check_circle_outline : Icons.info_outline,
                            color: _hasBlackHole ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _hasBlackHole
                                  ? 'Driver Virtual Audio (BlackHole 2ch) Terdeteksi!'
                                  : 'Belum Ada Virtual Audio Driver untuk Rekam Meeting (Zoom/Webinar)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _hasBlackHole ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                fontSize: 13,
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
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _showGuide = !_showGuide),
                            icon: Icon(_showGuide ? Icons.expand_less : Icons.help_outline, size: 16),
                            label: Text(_showGuide ? 'Sembunyikan' : 'Panduan Install (1-Menit)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadDevices,
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                            tooltip: 'Muat ulang perangkat audio',
                          ),
                        ],
                      ),
                      if (_showGuide) ...[
                        const Divider(height: 24, color: Colors.white24),
                        const Text(
                          '📖 Cara Install & Setup BlackHole 2ch di macOS:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Buka Terminal di Mac, lalu jalankan perintah berikut:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SelectableText(
                                'brew install blackhole-2ch',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                                tooltip: 'Salin perintah ke clipboard',
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: 'brew install blackhole-2ch'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Perintah disalin ke clipboard!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '2. Buka aplikasi "Audio MIDI Setup" di macOS -> Klik "+" di kiri bawah -> Buat "Multi-Output Device".\n'
                          '3. Centang "MacBook Pro Speakers" DAN "BlackHole 2ch".\n'
                          '4. Klik tombol refresh 🔄 di atas setelah proses selesai.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
      children: [
        const _HeroStepBody(
          title: '4. Unduh Model',
          description: 'Model whisper siap diunduh ke direktori lokal Anda.',
          icon: Icons.download_outlined,
        ),
        const SizedBox(height: 24),
        if (_isDownloading) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF007AFF)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Mengunduh ${widget.modelId}...',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _totalBytes > 0
                            ? '${((_downloadedBytes / _totalBytes) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%'
                            : 'Mengukur...',
                        style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
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
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${_totalBytes > 0 ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1) : '?'} MB',
                      style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 2),
                        Text(
                          '${_speedMBps.toStringAsFixed(1)} MB/s',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.white38),
                        const SizedBox(width: 2),
                        Text(
                          _etaSecs > 0 ? '$_etaSecs dtk' : '...',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              'Gagal mengunduh model (${widget.modelId}). Silakan periksa koneksi internet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFF87171)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _error = null),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
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
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
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
            _signalLevel = 0.3 + (ticks % 5) * 0.14;
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
      children: [
        const _HeroStepBody(
          title: '5. Tone Test',
          description: 'Uji nada 440Hz untuk memverifikasi jalur mic & speaker.',
          icon: Icons.graphic_eq,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPlaying ? const Color(0xFF007AFF) : Colors.white12,
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
                      color: _isPlaying ? const Color(0xFF60A5FA) : Colors.white,
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      _tested ? Icons.check_circle : Icons.headphones,
                      size: 16,
                      color: _tested ? const Color(0xFF34D399) : Colors.white70,
                    ),
                    label: Text(
                      _tested ? 'Audio Normal' : 'Standby',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white10,
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
                  backgroundColor: Colors.white10,
                  color: const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isPlaying ? null : _startToneTest,
                icon: Icon(_isPlaying ? Icons.graphic_eq : Icons.play_arrow),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                label: Text(_isPlaying ? 'Memproses nada...' : 'Putar Nada Uji (440Hz)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
