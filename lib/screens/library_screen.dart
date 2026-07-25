import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../state/models.dart';
import '../widgets/file_upload_zone.dart';
import 'transcript_player_screen.dart';

class SessionSummary {
  final String id;
  final String title;
  final String date;
  final double durationSeconds;
  final int segmentsCount;
  final List<TranscriptSegment> segments;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.date,
    required this.segmentsCount,
    this.segments = const [],
    this.durationSeconds = 0,
  });
}

class LibraryScreen extends StatefulWidget {
  final List<SessionSummary> sessions;

  const LibraryScreen({super.key, this.sessions = const []});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  late List<SessionSummary> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.of(widget.sessions);
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions) {
      _sessions = List.of(widget.sessions);
      if (_query.isNotEmpty) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SessionSummary> get _filteredSessions {
    if (_query.isEmpty) return _sessions;
    final q = _query.toLowerCase();
    return _sessions.where((s) => s.title.toLowerCase().contains(q)).toList();
  }

  /// Soft-delete: removes from the visible list immediately, but keeps the
  /// entry recoverable via the snackbar's Undo action. The 7-day retention
  /// window (moving the session folder to `.trash/`) is a filesystem
  /// operation on the Rust side, not yet wired — this owns the UI half.
  void _deleteSession(SessionSummary session) {
    final index = _sessions.indexOf(session);
    if (index == -1) return;

    setState(() => _sessions.removeAt(index));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${session.title}" dihapus. Akan dihapus permanen dalam 7 hari.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () {
            setState(() => _sessions.insert(index.clamp(0, _sessions.length), session));
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _updateSessionSegments(String sessionId, List<TranscriptSegment> segments) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) return;

    final updatedSession = SessionSummary(
      id: _sessions[index].id,
      title: _sessions[index].title,
      date: _sessions[index].date,
      durationSeconds: _sessions[index].durationSeconds,
      segmentsCount: segments.length,
      segments: segments,
    );

    setState(() {
      _sessions[index] = updatedSession;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: TabBar(
            tabs: [
              Semantics(label: 'Tab sesi tersimpan', child: const Tab(text: 'Sesi')),
              Semantics(label: 'Tab upload file', child: const Tab(text: 'Upload File')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    textField: true,
                    label: 'Cari sesi berdasarkan judul',
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari sesi berdasarkan judul…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : Semantics(
                                button: true,
                                label: 'Hapus pencarian',
                                child: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
                Expanded(
                  child: _sessions.isEmpty
                      ? Semantics(
                          label: 'Belum ada sesi tersimpan',
                          child: const Center(child: Text('Belum ada sesi tersimpan.')),
                        )
                      : filtered.isEmpty
                          ? Semantics(
                              label: 'Tidak ada sesi yang cocok dengan pencarian',
                              child: const Center(child: Text('Tidak ada sesi yang cocok.')),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _SessionCard(
                                session: filtered[index],
                                onDelete: () => _deleteSession(filtered[index]),
                                onSegmentsChanged: (segments) =>
                                    _updateSessionSegments(filtered[index].id, segments),
                              ),
                            ),
                ),
              ],
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
  final VoidCallback onDelete;
  final ValueChanged<List<TranscriptSegment>> onSegmentsChanged;

  const _SessionCard({
    required this.session,
    required this.onDelete,
    required this.onSegmentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSeconds / 60).floor();
    return Semantics(
      label: '${session.title}, ${session.date}, $minutes menit, ${session.segmentsCount} segmen',
      button: true,
      child: Card(
        child: ListTile(
          title: Text(session.title),
          subtitle: Text('${session.date} · $minutes menit · ${session.segmentsCount} segmen'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TranscriptPlayerScreen(
                title: session.title,
                durationSeconds: session.durationSeconds,
                segments: session.segments,
                onSegmentsChanged: onSegmentsChanged,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Export',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => showExportDialog(context, session),
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share),
                onPressed: () => shareSessionSummary(session),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shares a text summary via the OS-native share sheet. Sharing the actual
/// exported files (once export writes real bytes via the Rust bridge) is
/// a drop-in extension: `SharePlus.instance.share(ShareParams(files: ...))`.
Future<void> shareSessionSummary(SessionSummary session) {
  return SharePlus.instance.share(
    ShareParams(
      subject: session.title,
      text: buildSessionShareText(session),
    ),
  );
}

String buildSessionShareText(SessionSummary session) {
  final minutes = (session.durationSeconds / 60).floor();
  final transcript = session.segments.isEmpty
      ? 'Tidak ada transkrip yang tersimpan.'
      : session.segments.map((segment) => '${segment.speaker}: ${segment.text}').join('\n');
  return '${session.title}\n${session.date} · $minutes menit · '
      '${session.segmentsCount} segmen\n\n$transcript\n\nDitranskrip dengan Trascribe.';
}

Future<void> showExportDialog(BuildContext context, SessionSummary session) {
  final selected = <String>{'md'};
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Export "${session.title}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final format in const [
                  ('md', 'Markdown'),
                  ('txt', 'TXT'),
                  ('json', 'JSON'),
                  ('srt', 'SRT'),
                  ('vtt', 'VTT'),
                  ('html', 'HTML'),
                  ('docx', 'DOCX (Word)'),
                  ('wav', 'WAV (audio)'),
                ])
                  Semantics(
                    label: 'Format ${format.$2}, ${selected.contains(format.$1) ? 'terpilih' : 'tidak terpilih'}',
                    child: CheckboxListTile(
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
                  ),
              ],
            ),
          ),
        ),
        actions: [
          Semantics(
            label: 'Batal export',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ),
          Semantics(
            label: 'Konfirmasi export',
            button: true,
            child: FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.of(context).pop(),
              child: const Text('Export'),
            ),
          ),
        ],
      ),
    ),
  );
}
