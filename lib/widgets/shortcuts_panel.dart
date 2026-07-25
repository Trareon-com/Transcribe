import 'package:flutter/material.dart';

class ShortcutEntry {
  final String keys;
  final String description;
  /// Indonesian semantic label for accessibility
  final String semanticLabel;

  const ShortcutEntry(this.keys, this.description, this.semanticLabel);
}

const List<ShortcutEntry> appShortcuts = [
  ShortcutEntry('⌘/Ctrl + R', 'Mulai / Stop merekam', 'Mulai atau stop merekam'),
  ShortcutEntry('⌘/Ctrl + P', 'Jeda / Lanjutkan', 'Jeda atau lanjutkan sesi'),
  ShortcutEntry('⌘/Ctrl + L', 'Buka Library', 'Buka perpustakaan sesi'),
  ShortcutEntry('⌘/Ctrl + ,', 'Buka Pengaturan', 'Buka pengaturan aplikasi'),
  ShortcutEntry('⌘/Ctrl + /', 'Tampilkan panel shortcut ini', 'Tampilkan panel pintasan keyboard ini'),
];

Future<void> showShortcutsPanel(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Semantics(
        label: 'Pintasan keyboard',
        child: const Text('Keyboard Shortcuts'),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in appShortcuts)
              Semantics(
                label: entry.semanticLabel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.description)),
                      ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(entry.keys, style: Theme.of(context).textTheme.labelSmall),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        Semantics(
          label: 'Tutup panel pintasan',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ),
      ],
    ),
  );
}
