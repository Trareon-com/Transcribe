import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';

class UsageDashboardScreen extends ConsumerWidget {
  const UsageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dasbor Penggunaan'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _StatCard(
            icon: Icons.timer,
            label: 'Total Waktu Rekam',
            value: '0 jam',
            color: colors.primary,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.chat_bubble,
            label: 'Total Segmen',
            value: '0',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.save,
            label: 'Total Ekspor',
            value: '0',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.model_training,
            label: 'Model Sering Dipakai',
            value: 'base',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          Text('Grafik Mingguan', style: TextStyle(color: colors.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.divider),
            ),
            child: Center(
              child: Text(
                'Belum ada data penggunaan',
                style: TextStyle(color: colors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: colors.text, fontSize: 24, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}