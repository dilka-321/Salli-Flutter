import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';
import 'widgets.dart';

/// Share a file to another app (Gmail, Drive, WhatsApp…).
Future<void> shareBytes(Uint8List bytes, String name, String mime, {String? subject, String? text}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime, name: name)], subject: subject, text: text));
}

/// Let the person choose where to save the file on the phone (Downloads, Drive…). Returns false when cancelled.
Future<bool> saveBytes(Uint8List bytes, String name) async {
  final path = await FilePicker.platform.saveFile(dialogTitle: 'Save $name', fileName: name, bytes: bytes);
  return path != null;
}

/// Pick a text file (e.g. a backup) and return its contents, or null when cancelled.
Future<String?> pickTextFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  final f = r?.files.firstOrNull;
  if (f == null) return null;
  final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
  if (bytes == null) return null;
  return utf8.decode(bytes, allowMalformed: true);
}

/// Keeps the last few automatic backups inside the app's own storage.
Future<void> keepAutoBackup(String json, String name) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/Backups');
  if (!await dir.exists()) await dir.create(recursive: true);
  await File('${dir.path}/$name').writeAsString(json, flush: true);
  final files = dir.listSync().whereType<File>().toList()..sort((a, b) => b.path.compareTo(a.path));
  for (final f in files.skip(5)) {
    try {
      await f.delete();
    } catch (_) {}
  }
}

/// "Save to phone" / "Share to an app" chooser for one file.
Future<void> deliverFileSheet(BuildContext context, {required String title, required String subtitle, required Future<Uint8List> Function() build, required String name, required String mime, String? subject, String? text, VoidCallback? onDone}) {
  return showModalBottomSheet(
    context: context,
    builder: (c) {
      final p = Palette.of(c);
      Future<void> run(bool share) async {
        Navigator.pop(c);
        try {
          final bytes = await build();
          if (share) {
            await shareBytes(bytes, name, mime, subject: subject, text: text);
            onDone?.call();
          } else {
            final ok = await saveBytes(bytes, name);
            if (ok) {
              onDone?.call();
              if (context.mounted) toast(context, 'Saved $name');
            }
          }
        } catch (e) {
          if (context.mounted) toast(context, 'Could not create the file: $e');
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(backgroundColor: p.pos.withOpacity(.15), child: Icon(Icons.download_rounded, color: p.pos)),
              title: const Text('Save to phone', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Choose a folder such as Downloads'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => run(false),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFF5B8DEF).withOpacity(.15), child: const Icon(Icons.share_rounded, color: Color(0xFF5B8DEF))),
              title: const Text('Share to an app', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Gmail, Google Drive, WhatsApp and more'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => run(true),
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ]),
        ),
      );
    },
  );
}
