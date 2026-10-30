import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Keeps the last downloaded snapshot on disk, so the app starts instantly and
/// works offline with the freshest data it has seen.
class CatalogCache {
  static const _fileName = 'stations_live_v1.json';

  File? _file;

  Future<File> _resolve() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    _file = file;
    return file;
  }

  Future<String?> read() async {
    try {
      final file = await _resolve();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> lastModified() async {
    try {
      final file = await _resolve();
      if (!await file.exists()) return null;
      return await file.lastModified();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String json) async {
    final file = await _resolve();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }

  Future<void> clear() async {
    try {
      final file = await _resolve();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best effort
    }
  }
}
