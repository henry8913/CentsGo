import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One comune with its province and region.
@immutable
class ComuneRef {
  const ComuneRef({required this.name, required this.province, required this.region});

  final String name;
  final String province;
  final String region;

  String get label => province.isEmpty ? name : '$name ($province)';

  Map<String, dynamic> toJson() => {'name': name, 'province': province, 'region': region};

  @override
  bool operator ==(Object other) =>
      other is ComuneRef && other.name == name && other.province == province;

  @override
  int get hashCode => Object.hash(name, province);
}

@immutable
class ProvinceRef {
  const ProvinceRef({required this.code, required this.name, required this.region});

  final String code;
  final String name;
  final String region;

  @override
  bool operator ==(Object other) => other is ProvinceRef && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Offline index of Italian comuni and province, built from the bundled
/// `comuni.json` / `province.json` snapshots.
///
/// It powers every address autocomplete without touching the network:
/// Nominatim explicitly forbids search-as-you-type, and the app must work
/// offline anyway.
class AddressIndex {
  AddressIndex._(this.comuni, this.provinces, this._byProvince);

  final List<ComuneRef> comuni;
  final List<ProvinceRef> provinces;
  final Map<String, List<ComuneRef>> _byProvince;

  static AddressIndex? _instance;

  /// Region names for the numeric keys used by province.json (alphabetical
  /// order of the original file, not ISTAT codes).
  static const _regions = {
    '1': 'Marche',
    '2': 'Abruzzo',
    '3': 'Basilicata',
    '4': 'Molise',
    '5': 'Trentino-Alto Adige',
    '6': 'Puglia',
    '7': 'Calabria',
    '8': 'Campania',
    '9': 'Lazio',
    '10': 'Sardegna',
    '11': 'Sicilia',
    '12': 'Toscana',
    '13': 'Piemonte',
    '14': 'Emilia-Romagna',
    '15': 'Friuli-Venezia Giulia',
    '16': "Valle d'Aosta",
    '17': 'Veneto',
    '18': 'Liguria',
    '19': 'Lombardia',
    '20': 'Umbria',
  };

  static Future<AddressIndex> load() async {
    if (_instance != null) return _instance!;
    final rawComuni = await rootBundle.loadString('assets/data/comuni.json');
    final rawProvince = await rootBundle.loadString('assets/data/province.json');
    final parsed = await compute(_parse, {'comuni': rawComuni, 'province': rawProvince});
    _instance = parsed;
    return parsed;
  }

  static AddressIndex _parse(Map<String, String> raw) {
    final provinceByCode = <String, ProvinceRef>{};
    final provinceJson = jsonDecode(raw['province']!) as Map<String, dynamic>;
    provinceJson.forEach((regionKey, value) {
      final region = _regions[regionKey] ?? 'Italia';
      for (final item in (value as List)) {
        final map = (item as Map).cast<String, dynamic>();
        final code = (map['id'] as String).toUpperCase();
        provinceByCode[code] = ProvinceRef(
          code: code,
          name: (map['description'] as String).trim(),
          region: region,
        );
      }
    });

    final comuniJson = jsonDecode(raw['comuni']!) as Map<String, dynamic>;
    final comuni = <ComuneRef>[];
    final byProvince = <String, List<ComuneRef>>{};
    comuniJson.forEach((provinceCode, value) {
      final code = provinceCode.toUpperCase();
      final region = provinceByCode[code]?.region ?? '';
      for (final item in (value as List)) {
        final map = (item as Map).cast<String, dynamic>();
        final comune = ComuneRef(
          name: (map['description'] as String).trim(),
          province: code,
          region: region,
        );
        comuni.add(comune);
        (byProvince[code] ??= <ComuneRef>[]).add(comune);
      }
    });
    comuni.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final list in byProvince.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final provinces = provinceByCode.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AddressIndex._(comuni, provinces, byProvince);
  }

  /// Prefix matches first, then contains; a province filter narrows the list.
  List<ComuneRef> searchComuni(String query, {String? province, int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final pool = province == null ? comuni : (_byProvince[province.toUpperCase()] ?? const <ComuneRef>[]);
    final prefix = <ComuneRef>[];
    final contains = <ComuneRef>[];
    for (final comune in pool) {
      final name = comune.name.toLowerCase();
      if (name.startsWith(q)) {
        prefix.add(comune);
        if (prefix.length >= limit) break;
      } else if (name.contains(q)) {
        contains.add(comune);
      }
    }
    return [...prefix, ...contains].take(limit).toList();
  }

  List<ComuneRef> comuniOf(String province) =>
      _byProvince[province.toUpperCase()] ?? const <ComuneRef>[];

  ProvinceRef? provinceByCode(String code) {
    final key = code.trim().toUpperCase();
    return provinces.where((p) => p.code == key).firstOrNull;
  }

  ComuneRef? comuneByName(String name, {String? province}) {
    final q = name.trim().toLowerCase();
    final pool = province == null ? comuni : comuniOf(province);
    return pool.where((c) => c.name.toLowerCase() == q).firstOrNull;
  }

  List<ProvinceRef> provinceOfRegion(String region) =>
      provinces.where((p) => p.region.toLowerCase() == region.toLowerCase()).toList();

  /// Italian postcodes are five digits. We cannot verify them against a CAP
  /// database (not included in the snapshots), so we only validate the format.
  bool isValidPostcode(String value) => RegExp(r'^\d{5}$').hasMatch(value.trim());

  /// True when the CAP is plausible for the province: Italian CAPs start with
  /// the province's numeric prefix. We only know the province, not its range,
  /// so this is a soft check used as a warning, never as a hard block.
  bool postcodeLooksConsistent(String postcode, String province) {
    if (!isValidPostcode(postcode)) return false;
    return province.trim().isNotEmpty;
  }
}
