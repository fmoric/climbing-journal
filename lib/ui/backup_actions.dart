import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/local_journal_repository.dart';
import '../domain/stats.dart';

/// Backup export and import for local mode (FR-10).
class BackupActions {
  BackupActions(this.repo);

  final LocalJournalRepository repo;

  /// Opens the share sheet with the backup file, so it can be saved to
  /// Drive, emailed or sent to another phone.
  Future<void> export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      final json = await repo.exportBackup(now: now);
      final name = 'climbing-journal-backup-'
          '${now.year}-${_two(now.month)}-${_two(now.day)}.json';
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(json)),
            mimeType: 'application/json',
            name: name,
          ),
        ],
        fileNameOverrides: [name],
        subject: 'Climbing Journal backup',
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not export the backup: $e')));
    }
  }

  /// Picks a backup file, shows what it contains, and replaces the
  /// logbook after confirmation.
  Future<void> import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final String json;
    final BackupInfo info;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      json = utf8.decode(await file.readAsBytes());
      info = LocalJournalRepository.inspectBackup(json);
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not read the file: $e')));
      return;
    }
    if (!context.mounted) return;

    final made = info.exportedAt == null
        ? ''
        : ' from ${formatDate(info.exportedAt!.toLocal())}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace your logbook?'),
        content: Text(
          'The backup$made has ${info.ascents} ascents, '
          '${info.routes} routes and ${info.crags} crags.\n\n'
          'Everything currently in the app will be replaced. '
          'Export a backup first if you want to keep it.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.importBackup(json);
      messenger.showSnackBar(SnackBar(
          content: Text('Backup restored: ${info.ascents} ascents.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not restore the backup: $e')));
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
