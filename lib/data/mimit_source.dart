import 'dart:convert';
import 'dart:io';

/// Downloads and normalises the official Italian fuel-price open data.
///
/// The Ministry publishes two CSV files once a day (around 08:00):
///   • anagrafica_impianti_attivi.csv  — stations, addresses, coordinates
///   • prezzo_alle_8.csv               — prices per station, self/servito
///
/// CentsGo fetches both, joins them and produces the same compact JSON layout
/// used by the bundled snapshot, so the rest of the app does not care where the
/// data came from.
class MimitSource {
  MimitSource({HttpClient? client}) : _client = client ?? HttpClient();

  static const anagraficaUrl =
      'https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv';
  static const prezziUrl = 'https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv';

  static const fuels = ['Benzina', 'Gasolio', 'GPL', 'Metano', 'HVO'];

  final HttpClient _client;

  /// Downloads the two CSV files. Kept separate so the caller can move the CSV
  /// parsing to a background isolate.
  Future<(String, String)> download({void Function(double progress)? onProgress}) async {
    onProgress?.call(0.02);
    final anagrafica = await _get(anagraficaUrl);
    onProgress?.call(0.45);
    final prezzi = await _get(prezziUrl);
    onProgress?.call(0.8);
    return (anagrafica, prezzi);
  }

  /// Download + parse in one call (used by scripts and tests).
  Future<SyncResult> fetch({void Function(double progress)? onProgress}) async {
    final raw = await download(onProgress: onProgress);
    final result = parse(raw.$1, raw.$2);
    onProgress?.call(1);
    return result;
  }

  /// Isolate entry point: parses a (anagrafica, prezzi) pair.
  static SyncResult parsePair((String, String) input) => parse(input.$1, input.$2);

  /// Cheap check: reads the Last-Modified header without downloading the file.
  /// Returns null when the server does not expose it.
  Future<DateTime?> remoteLastModified() async {
    try {
      final request = await _client.headUrl(Uri.parse(anagraficaUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'CentsGo/1.0 (fuel prices client)');
      request.followRedirects = true;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final value = response.headers.value(HttpHeaders.lastModifiedHeader);
      await response.drain<void>();
      if (value == null) return null;
      return HttpDate.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<String> _get(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, 'CentsGo/1.0 (fuel prices client)');
    request.followRedirects = true;
    final response = await request.close().timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} per $url');
    }
    final bytes = await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    // The ministry files are mostly UTF-8 with rare Latin-1 leftovers.
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Pure parser, exposed for tests and for the offline rebuild script.
  static SyncResult parse(String anagraficaCsv, String prezziCsv) {
    final extraction = _extractionDate(anagraficaCsv) ?? _extractionDate(prezziCsv);
    final anagrafica = _rows(anagraficaCsv, ['idImpianto']);
    final prezzi = _rows(prezziCsv, ['idImpianto']);

    // id -> fuel -> [self, servito]
    final priceById = <String, Map<String, List<double?>>>{};
    final updatedById = <String, int>{};

    for (final row in prezzi) {
      final id = row['idImpianto']?.trim();
      final fuel = _canonicalFuel(row['descCarburante'] ?? '');
      if (id == null || id.isEmpty || fuel == null) continue;
      final value = double.tryParse((row['prezzo'] ?? '').replaceAll(',', '.'));
      if (value == null || value <= 0 || value > 20) continue;

      final entry = priceById.putIfAbsent(id, () => <String, List<double?>>{});
      final slot = entry.putIfAbsent(fuel, () => <double?>[null, null]);
      final isSelf = (row['isSelf'] ?? '').trim() == '1';
      final index = isSelf ? 0 : 1;
      if (slot[index] == null || value < slot[index]!) slot[index] = value;

      final ts = _parseTimestamp(row['dtComu']);
      if (ts != null && ts > (updatedById[id] ?? 0)) updatedById[id] = ts;
    }

    final brands = <String>[];
    final brandIndex = <String, int>{};
    final highways = <String, String>{};
    final stations = <List<dynamic>>[];
    var skipped = 0;

    for (final row in anagrafica) {
      final id = row['idImpianto']?.trim();
      if (id == null || id.isEmpty) continue;
      final prices = priceById[id];
      if (prices == null || prices.isEmpty) {
        skipped++;
        continue;
      }
      final lat = double.tryParse(row['Latitudine'] ?? '');
      final lon = double.tryParse(row['Longitudine'] ?? '');
      if (lat == null || lon == null || lat == 0 || lon == 0) {
        skipped++;
        continue;
      }
      var brand = (row['Bandiera'] ?? '').trim();
      if (brand.isEmpty) brand = 'Pompe Bianche';
      final index = brandIndex.putIfAbsent(brand, () {
        brands.add(brand);
        return brands.length - 1;
      });

      final address = _clean(row['Indirizzo']);
      String? highway;
      if ((row['Tipo Impianto'] ?? '').trim() == 'Autostradale') {
        final match = RegExp(r'\b(A\d{1,2})\b').firstMatch('$address ${_clean(row['Nome Impianto'])}');
        highway = match?.group(1) ?? 'A0';
        highways[highway] = '';
      }

      stations.add(<dynamic>[
        id,
        index,
        _titleCase(_clean(row['Nome Impianto'])),
        address,
        _titleCase(_clean(row['Comune'])),
        (row['Provincia'] ?? '').trim(),
        double.parse(lat.toStringAsFixed(5)),
        double.parse(lon.toStringAsFixed(5)),
        highway,
        updatedById[id] ?? 0,
        prices,
      ]);
    }

    stations.sort((a, b) {
      final prov = (a[5] as String).compareTo(b[5] as String);
      if (prov != 0) return prov;
      return (a[4] as String).compareTo(b[4] as String);
    });

    final payload = {
      'meta': {
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'price_extraction': extraction ?? DateTime.now().toIso8601String().split('T').first,
        'source': 'MIMIT - Osservaprezzi carburanti (open data)',
        'station_count': stations.length,
        'skipped': skipped,
      },
      'fuels': fuels,
      'brands': brands,
      'highways': _highwayNames(highways.keys),
      'stations': stations,
    };

    return SyncResult(
      json: jsonEncode(payload),
      stationCount: stations.length,
      priceDate: extraction ?? '',
    );
  }

  static List<Map<String, String>> _rows(String csv, List<String> requiredHeaders) {
    // The first line is "Estrazione del YYYY-MM-DD", then the header row, then data.
    final lines = const LineSplitter().convert(csv);
    var headerIndex = -1;
    for (var i = 0; i < lines.length && i < 5; i++) {
      if (lines[i].contains('|') && requiredHeaders.every(lines[i].contains)) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) return const [];
    final header = lines[headerIndex].split('|');
    final rows = <Map<String, String>>[];
    for (var i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final parts = line.split('|');
      if (parts.length < header.length) continue;
      rows.add({for (var j = 0; j < header.length; j++) header[j]: parts[j]});
    }
    return rows;
  }

  static String? _canonicalFuel(String raw) {
    final f = raw.trim().toLowerCase();
    if (f.isEmpty) return null;
    if (f.contains('hvo') || f.contains('rehvo') || f.contains('bchvo') || f.startsWith('f101') || f.startsWith('f-101')) {
      return 'HVO';
    }
    if (f.contains('gnl') || f.contains('gnc') || f.contains('metano')) return 'Metano';
    if (f.contains('gpl')) return 'GPL';
    if (f.contains('gasolio') || f.contains('diesel')) return 'Gasolio';
    if (f.contains('benzina') || f.contains('verde') || f.contains('ottani')) return 'Benzina';
    return null;
  }

  static String? _extractionDate(String csv) {
    final match = RegExp(r'Estrazione del (\d{4}-\d{2}-\d{2})').firstMatch(csv);
    return match?.group(1);
  }

  static int? _parseTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(' ');
    if (parts.length != 2) return null;
    final date = parts[0].split('/');
    final time = parts[1].split(':');
    if (date.length != 3 || time.length != 3) return null;
    final parsed = DateTime.tryParse(
      '${date[2]}-${date[1]}-${date[0]}T${time[0]}:${time[1]}:${time[2]}',
    );
    return parsed == null ? null : parsed.millisecondsSinceEpoch ~/ 1000;
  }

  static String _clean(String? value) => (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  static Map<String, String> _highwayNames(Iterable<String> codes) {
    const names = {
      'A1': 'Milano - Napoli',
      'A2': 'Autostrada del Mediterraneo',
      'A3': 'Napoli - Salerno',
      'A4': 'Torino - Trieste',
      'A5': 'Torino - Aosta - Monte Bianco',
      'A6': 'Torino - Savona',
      'A7': 'Milano - Serravalle - Genova',
      'A8': 'Milano - Varese',
      'A9': 'Lainate - Como - Chiasso',
      'A10': 'Genova - Ventimiglia',
      'A11': 'Firenze - Pisa Nord',
      'A12': 'Genova - Roma',
      'A13': 'Bologna - Padova',
      'A14': 'Bologna - Taranto',
      'A15': 'Parma - La Spezia',
      'A16': 'Napoli - Canosa',
      'A18': 'Messina - Catania',
      'A19': 'Palermo - Catania',
      'A20': 'Messina - Palermo',
      'A21': 'Torino - Brescia',
      'A22': 'Modena - Brennero',
      'A23': 'Udine - Tarvisio',
      'A24': "Roma - L'Aquila - Teramo",
      'A25': 'Torino - Pescara',
      'A26': 'Genova - Gravellona Toce',
      'A27': 'Venezia - Belluno',
      'A28': 'Conegliano - Portogruaro',
      'A29': 'Palermo - Mazara del Vallo',
      'A30': 'Caserta - Salerno',
      'A31': 'Vicenza - Piovene Rocchette',
      'A32': 'Torino - Bardonecchia',
      'A33': 'Asti - Cuneo',
      'A34': 'Villesse - Gorizia',
      'A35': 'Brebemi',
      'A36': 'Pedemontana Lombarda',
      'A50': 'Tangenziale Ovest di Milano',
      'A51': 'Tangenziale Est di Milano',
      'A52': 'Tangenziale Nord di Milano',
      'A54': 'Tangenziale di Pavia',
      'A55': 'Tangenziale di Torino',
      'A56': 'Tangenziale di Napoli',
      'A57': 'Tangenziale di Venezia',
      'A58': 'Tangenziale Est Esterna di Milano',
      'A60': 'Tangenziale di Varese',
      'A90': 'Grande Raccordo Anulare di Roma',
      'A91': 'Roma - Fiumicino',
    };
    final sorted = codes.toList()..sort((a, b) => a.length == b.length ? a.compareTo(b) : a.length - b.length);
    return {for (final code in sorted) code: names[code] ?? code};
  }
}

class SyncResult {
  const SyncResult({required this.json, required this.stationCount, required this.priceDate});

  final String json;
  final int stationCount;
  final String priceDate;
}
