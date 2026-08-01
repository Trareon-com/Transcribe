import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';

class PrivacyReportScreen extends ConsumerWidget {
  const PrivacyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Privasi'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Ringkasan', style: TextStyle(color: colors.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _PrivacyRow(
            icon: Icons.mic_off,
            title: 'Audio tidak keluar perangkat',
            subtitle: 'Semua pemrosesan speech-to-text berjalan lokal via whisper.cpp. Tidak ada data audio yang dikirim ke server eksternal.',
          ),
          _PrivacyRow(
            icon: Icons.cloud_off,
            title: 'Tanpa koneksi internet wajib',
            subtitle: 'Aplikasi berfungsi penuh offline. Hanya cek update & telemetri opt-in yang butuh jaringan.',
          ),
          _PrivacyRow(
            icon: Icons.lock,
            title: 'Enkripsi penyimpanan lokal',
            subtitle: 'File transkrip & metadata disimpan di folder Library pengguna. Tidak ada cloud sync default.',
          ),
          const SizedBox(height: 24),
          Text('Detail Teknis', style: TextStyle(color: colors.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _PrivacyRow(
            icon: Icons.model_training,
            title: 'Model AI bundled',
            subtitle: 'Model Whisper (base + large-v3-turbo-q5 548MB) dikemas di assets aplikasi. Tidak di-download saat runtime.',
          ),
          _PrivacyRow(
            icon: Icons.settings,
            title: 'Pengaturan dikontrol user',
            subtitle: 'Library path, model default, mode progresif, telemetri — semuanya di tangan Anda via Pengaturan.',
          ),
          _PrivacyRow(
            icon: Icons.delete_forever,
            title: 'Hapus data kapan saja',
            subtitle: 'Hapus folder Library atau gunakan "Bersihkan Semua" di Perpustakaan. Tidak ada jejak tersembunyi.',
          ),
        ],
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.text, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}