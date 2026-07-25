import 'package:flutter/material.dart';

class ShortcutEntry {
  final String keys;
  final String description;

  const ShortcutEntry(this.keys, this.description);
}

const List<ShortcutEntry> appShortcuts = [
  ShortcutEntry('⌘/Ctrl + R', 'Mulai / Stop merekam'),
  ShortcutEntry('⌘/Ctrl + P', 'Jeda / Lanjutkan'),
  ShortcutEntry('⌘/Ctrl + L', 'Buka Library'),
  ShortcutEntry('⌘/Ctrl + ,', 'Buka Pengaturan'),
  ShortcutEntry('⌘/Ctrl + /', 'Tampilkan panel shortcut ini'),
];

Future<void> showShortcutsPanel(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in appShortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(entry.description)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(entry.keys, style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}
