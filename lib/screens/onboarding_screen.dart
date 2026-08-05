import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/model_download_card.dart';

/// First-launch onboarding — model download screen.
///
/// Shows progress for the two required models (Indonesian ASR + Indonesian LLM).
/// No model identifiers exposed; only Indonesian descriptions:
///   - "Model Pengenalan Suara" (Whisper large-v3-turbo, ~1.5 GB)
///   - "Model Bahasa Indonesia" (Qwen2.5-7B-Instruct 4-bit, ~4.5 GB)
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.asrStatus,
    required this.asrProgress,
    required this.asrTitle,
    required this.asrSubtitle,
    required this.asrSize,
    this.asrError,
    required this.llmStatus,
    required this.llmProgress,
    required this.llmTitle,
    required this.llmSubtitle,
    required this.llmSize,
    this.llmError,
    required this.allReady,
    required this.onContinue,
    required this.onRetryAsr,
    required this.onRetryLlm,
  });

  final DownloadStatus asrStatus;
  final double asrProgress;
  final String asrTitle;
  final String asrSubtitle;
  final String asrSize;
  final String? asrError;
  final DownloadStatus llmStatus;
  final double llmProgress;
  final String llmTitle;
  final String llmSubtitle;
  final String llmSize;
  final String? llmError;
  final bool allReady;
  final VoidCallback onContinue;
  final VoidCallback onRetryAsr;
  final VoidCallback onRetryLlm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat datang di Traeon Transcribe',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aplikasi ini bekerja 100% offline. Kami perlu mengunduh dua model ke perangkat Anda — proses ini hanya terjadi sekali.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              ModelDownloadCard(
                title: asrTitle,
                subtitle: asrSubtitle,
                sizeLabel: asrSize,
                progress: asrProgress,
                status: asrStatus,
                errorText: asrError,
              ),
              const SizedBox(height: 12),
              ModelDownloadCard(
                title: llmTitle,
                subtitle: llmSubtitle,
                sizeLabel: llmSize,
                progress: llmProgress,
                status: llmStatus,
                errorText: llmError,
              ),
              const Spacer(),
              if (asrStatus == DownloadStatus.error || llmStatus == DownloadStatus.error)
                TextButton.icon(
                  onPressed: () {
                    if (asrStatus == DownloadStatus.error) onRetryAsr();
                    if (llmStatus == DownloadStatus.error) onRetryLlm();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba lagi'),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: allReady ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  allReady ? 'Mulai menggunakan' : 'Mengunduh...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                allReady
                    ? 'Siap. Model tidak akan pernah dikirim ke cloud.'
                    : 'Anda boleh menutup aplikasi — unduhan akan dilanjutkan di latar belakang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pure-data state object for the screen above; lets the state holder be a
/// Riverpod `Notifier` without leaking UI imports.
class OnboardingState {
  const OnboardingState({
    required this.asr,
    required this.llm,
  });

  final DownloadProgress asr;
  final DownloadProgress llm;

  bool get allReady =>
      asr.status == DownloadStatus.ready && llm.status == DownloadStatus.ready;

  static const empty = OnboardingState(
    asr: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: 'Model Pengenalan Suara',
      subtitle: 'Mengubah gelombang suara menjadi teks bahasa Indonesia',
      size: '~1,5 GB',
    ),
    llm: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: 'Model Bahasa Indonesia',
      subtitle: 'Memperbaiki teks hasil transkrip dan membuat ringkasan',
      size: '~4,5 GB',
    ),
  );
}

class DownloadProgress {
  const DownloadProgress({
    required this.status,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.size,
    this.error,
  });

  final DownloadStatus status;
  final double progress;
  final String title;
  final String subtitle;
  final String size;
  final String? error;
}