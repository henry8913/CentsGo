import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON-on-disk cache shared by routing, geocoding and open-data
/// downloads. Entries are keyed by URL (hashed) and carry their own expiry.
class DiskCache {
  DiskCache({this.folderName = 'centsgo_cache'});

  final String folderName;
  Directory? _dir;

  Future<Directory> _directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Stable, filesystem-safe key: FNV-1a 64 bit of the full URL.
  static String keyFor(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(url)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  Future<CacheEntry?> read(String url) async {
    try {
      final file = File('${(await _directory()).path}/${keyFor(url)}.json');
      if (!await file.exists()) return null;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (map['url'] != url) return null;
      return CacheEntry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String url, CacheEntry entry) async {
    try {
      final file = File('${(await _directory()).path}/${keyFor(url)}.json');
      await file.writeAsString(jsonEncode(entry.toJson(url)), flush: true);
    } catch (_) {
      // Cache is best effort: a full disk must never break the app.
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<int> sizeBytes() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}

class CacheEntry {
  const CacheEntry({
    required this.url,
    required this.body,
    required this.statusCode,
    required this.storedAt,
  });

  final String url;
  final String body;
  final int statusCode;
  final DateTime storedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(storedAt) < ttl;

  Map<String, dynamic> toJson(String url) => {
        'url': url,
        'body': body,
        'status': statusCode,
        'storedAt': storedAt.toIso8601String(),
      };

  static CacheEntry fromJson(Map<String, dynamic> json) => CacheEntry(
        url: json['url'] as String? ?? '',
        body: json['body'] as String? ?? '',
        statusCode: (json['status'] as num?)?.toInt() ?? 0,
        storedAt: DateTime.tryParse(json['storedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
