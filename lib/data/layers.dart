import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/map_layers.dart';

/// Lazy loader for the optional map layers. Each data set lives in its own
/// asset so the first frame only pays for the fuel catalogue.
class MapLayers {
  List<EvCharger>? _ev;
  List<ZtlZone>? _ztl;
  List<PlacePoi>? _pois;
  Map<String, dynamic>? _evTariffs;

  bool get evLoaded => _ev != null;
  bool get ztlLoaded => _ztl != null;
  bool get poisLoaded => _pois != null;

  List<EvCharger> get ev => _ev ?? const [];
  List<ZtlZone> get ztl => _ztl ?? const [];
  List<PlacePoi> get pois => _pois ?? const [];

  Future<List<EvCharger>> ensureEv() async {
    if (_ev != null) return _ev!;
    final raw = await rootBundle.loadString('assets/data/elettrico.json');
    _ev = await compute(_parseEv, raw);
    return _ev!;
  }

  Future<List<ZtlZone>> ensureZtl() async {
    if (_ztl != null) return _ztl!;
    final raw = await rootBundle.loadString('assets/data/ztl_dump.json');
    _ztl = await compute(_parseZtl, raw);
    return _ztl!;
  }

  Future<List<PlacePoi>> ensurePois() async {
    if (_pois != null) return _pois!;
    final raw = await rootBundle.loadString('assets/data/osm_pois_seed.json');
    _pois = await compute(_parsePois, raw);
    return _pois!;
  }

  Future<Map<String, dynamic>> ensureEvTariffs() async {
    if (_evTariffs != null) return _evTariffs!;
    final raw = await rootBundle.loadString('assets/data/ev_tariffe.json');
    _evTariffs = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return _evTariffs!;
  }

  /// Tariff estimate for a charging operator, by power class (ac/dc/hpc).
  /// Returns the €/kWh value and where it comes from, so the UI can label it as
  /// an estimate instead of a live price.
  EvTariff estimateEvTariff(String brand, double kw) {
    final t = _evTariffs;
    final className = kw >= 150 ? 'hpc' : (kw >= 50 ? 'dc' : 'ac');
    if (t == null) return const EvTariff(value: null, source: 'non disponibile', operatorName: '');
    final market = (t['market'] as Map?)?.cast<String, dynamic>();
    final operators = (t['operators'] as List?) ?? const [];
    final lower = brand.toLowerCase();
    for (final op in operators) {
      final map = (op as Map).cast<String, dynamic>();
      final matches = ((map['match'] as List?) ?? const []).map((e) => e.toString().toLowerCase());
      if (matches.any(lower.contains)) {
        return EvTariff(
          value: (map[className] as num?)?.toDouble(),
          source: (map['source'] as String?) ?? '',
          operatorName: (map['name'] as String?) ?? brand,
          checked: (map['checked'] as String?) ?? '',
        );
      }
    }
    return EvTariff(
      value: (market?[className] as num?)?.toDouble(),
      source: (market?['source'] as String?) ?? 'media di mercato',
      operatorName: 'Media di mercato',
      checked: (market?['checked'] as String?) ?? '',
    );
  }

  /// Chargers around a point, cheapest power class first.
  List<EvCharger> evNear(LatLng center, {double radiusKm = 10, int limit = 120, bool fastOnly = false}) {
    final hits = <(double, EvCharger)>[];
    for (final c in ev) {
      if (fastOnly && !c.isFast) continue;
      final d = _distance(center, c.position);
      if (d <= radiusKm) hits.add((d, c));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return hits.take(limit).map((e) => e.$2).toList();
  }

  List<ZtlZone> ztlNear(LatLng center, {double radiusKm = 15}) {
    return ztl.where((z) => _distance(center, z.center) <= radiusKm).toList();
  }

  List<PlacePoi> poisNear(LatLng center, Set<String> kinds, {double radiusKm = 8, int limit = 150}) {
    if (kinds.isEmpty) return const [];
    final hits = <(double, PlacePoi)>[];
    for (final p in pois) {
      if (!kinds.contains(p.kind)) continue;
      final d = _distance(center, p.position);
      if (d <= radiusKm) hits.add((d, p));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return hits.take(limit).map((e) => e.$2).toList();
  }

  static double _distance(LatLng a, LatLng b) {
    const r = 6371.0088;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }
}

class EvTariff {
  const EvTariff({
    required this.value,
    required this.source,
    this.operatorName = '',
    this.checked = '',
  });

  final double? value;
  final String source;
  final String operatorName;
  final String checked;

  bool get hasValue => value != null;
}

List<EvCharger> _parseEv(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final rows = (map['data'] as List?) ?? const [];
  final out = <EvCharger>[];
  for (final row in rows) {
    final c = EvCharger.fromJson((row as Map).cast<String, dynamic>());
    if (c != null) out.add(c);
  }
  return out;
}

List<ZtlZone> _parseZtl(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final rows = (map['zones'] as List?) ?? const [];
  final out = <ZtlZone>[];
  for (final row in rows) {
    final z = ZtlZone.fromJson((row as Map).cast<String, dynamic>());
    if (z != null) out.add(z);
  }
  return out;
}

List<PlacePoi> _parsePois(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final rows = (map['pois'] as List?) ?? const [];
  final out = <PlacePoi>[];
  for (final row in rows) {
    final p = PlacePoi.fromJson((row as Map).cast<String, dynamic>());
    if (p != null) out.add(p);
  }
  return out;
}
