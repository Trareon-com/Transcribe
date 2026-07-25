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
        return const _StepBody(
          title: '3. Setup Audio',
          description:
              'macOS: ScreenCaptureKit (tanpa install) atau BlackHole (fallback macOS lama).\n'
              'Windows: WASAPI loopback native, tanpa driver tambahan.',
          icon: Icons.speaker_group_outlined,
        );
      case _WizardStep.modelDownload:
        return _DownloadStep(
          modelId: _selectedModel,
          downloaded: _downloadRecorded,
          onDownload: () {
            if (_downloadRecorded) return;
            ref.read(privacyReportProvider.notifier).recordModelDownload(_selectedModel);
            setState(() => _downloadRecorded = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Model "$_selectedModel" dicatat sebagai unduhan.')),
            );
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

class _DownloadStep extends StatelessWidget {
  final String modelId;
  final bool downloaded;
  final VoidCallback onDownload;

  const _DownloadStep({
    required this.modelId,
    required this.downloaded,
    required this.onDownload,
  });

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
          'Model "$modelId" siap diunduh. Unduhan model ini akan tercatat di Privacy Report.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: downloaded ? null : onDownload,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(downloaded ? 'Sudah dicatat' : 'Unduh model'),
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
