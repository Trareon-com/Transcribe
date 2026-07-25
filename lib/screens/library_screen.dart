import 'package:flutter/material.dart';

import '../widgets/file_upload_zone.dart';
import 'transcript_player_screen.dart';

class SessionSummary {
  final String id;
  final String title;
  final String date;
  final double durationSeconds;
  final int segmentsCount;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.date,
    required this.durationSeconds,
    required this.segmentsCount,
  });
}

class LibraryScreen extends StatelessWidget {
  final List<SessionSummary> sessions;

  const LibraryScreen({super.key, this.sessions = const []});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sesi'),
              Tab(text: 'Upload File'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            sessions.isEmpty
                ? const Center(child: Text('Belum ada sesi tersimpan.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _SessionCard(session: sessions[index]),
                  ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: FileUploadZone(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionSummary session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSeconds / 60).floor();
    return Card(
      child: ListTile(
        title: Text(session.title),
        subtitle: Text('${session.date} · $minutes menit · ${session.segmentsCount} segmen'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TranscriptPlayerScreen(
              title: session.title,
              durationSeconds: session.durationSeconds,
              segments: const [],
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share),
              onPressed: () => showExportDialog(context, session),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showExportDialog(BuildContext context, SessionSummary session) {
  final selected = <String>{'md'};
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Export "${session.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final format in const [
              ('md', 'Markdown'),
              ('txt', 'TXT'),
              ('json', 'JSON'),
              ('srt', 'SRT'),
              ('vtt', 'VTT'),
              ('wav', 'WAV (audio)'),
            ])
              CheckboxListTile(
                title: Text(format.$2),
                value: selected.contains(format.$1),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selected.add(format.$1);
                    } else {
                      selected.remove(format.$1);
                    }
                  });
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: selected.isEmpty ? null : () => Navigator.of(context).pop(),
            child: const Text('Export'),
          ),
        ],
      ),
    ),
  );
}
