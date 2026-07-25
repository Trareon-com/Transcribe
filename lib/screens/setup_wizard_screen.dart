import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';

/// First-run setup wizard: spec detection -> model choice -> audio setup
/// -> model download -> tone test. Steps 1/3/4 call into the Rust engine
/// (system spec, audio device/loopback checks, model download) once FRB
/// codegen is wired (Fase 5) — this screen owns the step flow and UI state
/// now so that wiring is a drop-in later.
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
    final nextIndex = _stepIndex + 1;
    if (nextIndex >= _steps.length) {
      widget.onFinished();
      return;
    }
    setState(() => _step = _steps[nextIndex]);
  }

  void _back() {
    final prevIndex = _stepIndex - 1;
    if (prevIndex < 0) return;
    setState(() => _step = _steps[prevIndex]);
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
            LinearProgressIndicator(value: (_stepIndex + 1) / _steps.length),
            const SizedBox(height: 24),
            Expanded(child: _buildStepBody()),
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
        return const _StepBody(
          title: '5. Tone Test',
          description: 'Uji nada untuk memverifikasi jalur mic dan speaker berfungsi dengan baik.',
          icon: Icons.graphic_eq,
        );
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
  String? _selectedMic;
  String? _selectedSpeaker;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final bridge = ref.read(rustBridgeProvider);
    final devices = await bridge.listAudioDevices();
    if (mounted) {
      setState(() {
        _loading = false;
        _selectedMic = devices.isNotEmpty ? devices.first.name : 'Built-in Microphone';
        _selectedSpeaker = 'System Speaker Loopback';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.speaker_group_outlined, size: 64),
        const SizedBox(height: 16),
        Text('3. Setup Audio', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Deteksi otomatis perangkat mic dan loopback speaker sistem.',
          textAlign: TextAlign.center,
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
                items: [
                  DropdownMenuItem(value: _selectedMic, child: Text(_selectedMic ?? 'Built-in Microphone')),
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
                  DropdownMenuItem(value: _selectedSpeaker, child: Text(_selectedSpeaker ?? 'System Speaker Loopback')),
                ],
                onChanged: (val) => setState(() => _selectedSpeaker = val),
              ),
            ],
          ),
      ],
    );
  }
}

class _DownloadStep extends StatefulWidget {
  final String modelId;
  final bool downloaded;
  final Future<void> Function() onDownload;

  const _DownloadStep({
    required this.modelId,
    required this.downloaded,
    required this.onDownload,
  });

  @override
  State<_DownloadStep> createState() => _DownloadStepState();
}

class _DownloadStepState extends State<_DownloadStep> {
  bool _isDownloading = false;
  String? _error;

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });
    try {
      await widget.onDownload();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
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
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Mengunduh model ${widget.modelId}...', style: Theme.of(context).textTheme.bodySmall),
        ] else if (_error != null) ...[
          Text('Gagal mengunduh: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _handleDownload,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('2. Pilih Model', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          child: Column(
            children: [
              for (final model in _models)
                RadioListTile<String>(value: model.$1, title: Text(model.$2)),
            ],
          ),
        ),
      ],
    );
  }
}
