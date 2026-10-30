import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/settings.dart';
import '../models/station.dart';
import 'catalog_cache.dart';

/// Parsed payload of assets/data/stations.json.
class _SeedPayload {
  _SeedPayload(this.stations, this.brands, this.highways, this.meta);

  final List<Station> stations;
  final List<String> brands;
  final Map<String, String> highways;
  final Map<String, dynamic> meta;
}

_SeedPayload _parseSeed(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final brands = (map['brands'] as List).map((e) => e.toString()).toList();
  final rows = map['stations'] as List;
  final stations = <Station>[];
  for (final row in rows) {
    try {
      stations.add(Station.fromCompact(row as List, brands));
    } catch (_) {
      // A single malformed row must never break the whole catalogue.
    }
  }
  final highways = <String, String>{};
  final rawHighways = map['highways'];
  if (rawHighways is Map) {
    rawHighways.forEach((k, v) => highways[k.toString()] = v.toString());
  }
  return _SeedPayload(
    stations,
    brands,
    highways,
    (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

/// Read-only catalogue of Italian fuel stations plus the derived indexes used by
/// the list, the map, the search tab and the trip planner.
class StationCatalog {
  StationCatalog({
    required this.stations,
    required this.brands,
    required this.highways,
    required this.meta,
    required this.places,
    required this.byComune,
    required this.byHighway,
    required this.topBrands,
    this.fromCache = false,
  });

  final List<Station> stations;
  final List<String> brands;
  final Map<String, String> highways;
  final Map<String, dynamic> meta;

  /// All comuni with at least one station, with a centroid coordinate.
  final List<Place> places;

  /// lowercase comune -> province -> stations
  final Map<String, List<Station>> byComune;
  final Map<String, List<Station>> byHighway;

  /// Brands with the most stations, cleaned of noisy `Bandiera` values coming
  /// from the registry (numeric codes, OCR leftovers with underscores).
  final List<String> topBrands;

  /// True when the data comes from a snapshot downloaded by the app instead of
  /// the one bundled with the release.
  final bool fromCache;

  String get sourceLabel => meta['source'] as String? ?? 'MIMIT';
  String get extractionDate => meta['price_extraction'] as String? ?? '—';
  String get generatedAt => meta['generated_at'] as String? ?? '';

  /// Loads the freshest snapshot available: the one downloaded by the app when
  /// present, otherwise the copy bundled with the release.
  static Future<StationCatalog> load({CatalogCache? cache}) async {
    final store = cache ?? CatalogCache();
    String? raw = await store.read();
    var fromCache = raw != null;
    if (raw == null) {
      raw = await rootBundle.loadString('assets/data/stations.json');
    }
    StationCatalog catalog;
    try {
      catalog = await _build(raw, fromCache: fromCache);
    } catch (_) {
      // Corrupted cache: fall back to the bundled snapshot.
      await store.clear();
      final bundled = await rootBundle.loadString('assets/data/stations.json');
      catalog = await _build(bundled, fromCache: false);
    }
    return catalog;
  }

  static Future<StationCatalog> _build(String raw, {required bool fromCache}) async {
    final payload = await compute(_parseSeed, raw);

    final byComune = <String, List<Station>>{};
    final byHighway = <String, List<Station>>{};
    final byProv = <String, List<Station>>{};
    final brandCounts = <String, int>{};
    final cityAcc = <String, _CityAcc>{};

    for (final s in payload.stations) {
      final key = s.comune.toLowerCase();
      if (key.isNotEmpty) {
        (byComune[key] ??= <Station>[]).add(s);
      }
      if (s.prov.isNotEmpty) {
        (byProv[s.prov] ??= <Station>[]).add(s);
      }
      final hw = s.highway;
      if (hw != null) {
        (byHighway[hw] ??= <Station>[]).add(s);
      }
      brandCounts[s.brand] = (brandCounts[s.brand] ?? 0) + 1;
    }

    // Registry rows are not always tidy: a station can be filed under a comune
    // while its coordinates sit hundreds of kilometres away. City centres use
    // the median (robust to a single wrong row) and fall back to the province
    // median when the whole cluster is implausible.
    final provCenter = <String, LatLng>{
      for (final entry in byProv.entries) entry.key: _median(entry.value),
    };
    final provRadius = <String, double>{
      for (final entry in byProv.entries)
        entry.key: _percentileDistance(entry.value, provCenter[entry.key]!, 0.9),
    };
    byComune.forEach((key, list) {
      final first = list.first;
      var center = _median(list);
      final province = provCenter[first.prov];
      final radius = provRadius[first.prov] ?? 40;
      if (province != null && list.length < 3 && Geo.distanceKm(center, province) > radius) {
        // Single/lonely station filed in the wrong place: park the comune on the
        // province centre instead of scattering a city hundreds of km away.
        center = province;
      }
      cityAcc[key] = _CityAcc(first.comune, first.prov, center);
    });

    final noise = RegExp(r'^[0-9]|_|^\W');
    final topBrands = brandCounts.entries
        .where((e) => e.value >= 4 && e.key.trim().length >= 2 && !noise.hasMatch(e.key.trim()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final places = cityAcc.values
        .map((c) => Place(name: c.name, prov: c.prov, position: c.center))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return StationCatalog(
      stations: payload.stations,
      brands: (payload.brands.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
      highways: payload.highways,
      meta: payload.meta,
      places: places,
      byComune: byComune,
      byHighway: byHighway,
      topBrands: topBrands.map((e) => e.key).take(30).toList(),
      fromCache: fromCache,
    );
  }

  Place? placeByName(String name) {
    final key = name.trim().toLowerCase();
    for (final p in places) {
      if (p.name.toLowerCase() == key) return p;
    }
    return null;
  }

  Place? nearestPlace(LatLng point, {double maxKm = 25}) {
    Place? best;
    var bestKm = double.infinity;
    for (final p in places) {
      final d = Geo.distanceKm(point, p.position);
      if (d < bestKm) {
        bestKm = d;
        best = p;
      }
    }
    return bestKm <= maxKm ? best : null;
  }

  /// Stations around [center]. A linear scan over 21k rows is ~2 ms, so no
  /// spatial index is needed for the query sizes of this app.
  List<StationHit> nearby({
    required LatLng center,
    required String fuel,
    required bool self,
    required SortMode sort,
    double radiusKm = 15,
    String? brand,
    bool includeHighway = true,
    int limit = 250,
    LatLng? avoid,
  }) {
    final hits = <StationHit>[];
    for (final s in stations) {
      if (!includeHighway && s.isHighway) continue;
      if (brand != null && brand.isNotEmpty && s.brand != brand) continue;
      final price = s.priceFor(fuel, self: self);
      if (price == null || !FuelSanity.plausible(fuel, price)) continue;
      final d = Geo.distanceKm(center, s.position);
      if (d > radiusKm) continue;
      hits.add(StationHit(
        station: s,
        distanceKm: d,
        price: price,
        selfService: self,
      ));
    }
    _sortHits(hits, sort);
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  /// Corridor search for the trip planner: keeps stations within
  /// [corridorKm] of the straight line between origin and destination.
  List<StationHit> alongPath({
    required List<LatLng> path,
    required String fuel,
    required bool self,
    required SortMode sort,
    double corridorKm = 4,
    String? brand,
    int limit = 200,
  }) {
    final hits = <StationHit>[];
    for (final s in stations) {
      if (brand != null && brand.isNotEmpty && s.brand != brand) continue;
      final price = s.priceFor(fuel, self: self);
      if (price == null || !FuelSanity.plausible(fuel, price)) continue;
      final projected = Geo.distanceToPath(s.position, path);
      if (projected.km > corridorKm) continue;
      hits.add(StationHit(
        station: s,
        distanceKm: projected.km,
        price: price,
        selfService: self,
        detourKm: projected.km,
        alongRouteT: projected.t,
      ));
    }
    switch (sort) {
      case SortMode.price:
        hits.sort((a, b) => a.price.compareTo(b.price));
      case SortMode.distance:
        hits.sort((a, b) => (a.alongRouteT ?? 0).compareTo(b.alongRouteT ?? 0));
      case SortMode.best:
        hits.sort((a, b) => _score(a).compareTo(_score(b)));
    }
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  /// Heuristic behind the "Migliori" chip: a litre saved is worth a few hundred
  /// metres of detour, 1.5 cent/km is the break-even used by the original app.
  static const double detourCostPerKm = 0.015;

  static double _score(StationHit h) => h.price + h.distanceKm * detourCostPerKm;

  void _sortHits(List<StationHit> hits, SortMode sort) {
    switch (sort) {
      case SortMode.price:
        hits.sort((a, b) {
          final c = a.price.compareTo(b.price);
          return c != 0 ? c : a.distanceKm.compareTo(b.distanceKm);
        });
      case SortMode.distance:
        hits.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case SortMode.best:
        hits.sort((a, b) => _score(a).compareTo(_score(b)));
    }
  }

  /// Cheapest / median / most expensive price of a result set — drives the
  /// green → amber → red convenience colouring.
  static ({double min, double median, double max}) spread(List<StationHit> hits) {
    if (hits.isEmpty) return (min: 0, median: 0, max: 0);
    final prices = hits.map((h) => h.price).toList()..sort();
    return (
      min: prices.first,
      median: prices[prices.length ~/ 2],
      max: prices.last,
    );
  }

  /// Price of the cheapest station of [fuel] near [center], used by the Garage.
  double? benchmarkPrice(LatLng center, String fuel, {bool self = true, double radiusKm = 20}) {
    final hits = nearby(
      center: center,
      fuel: fuel,
      self: self,
      sort: SortMode.price,
      radiusKm: radiusKm,
      limit: 40,
    );
    return hits.isEmpty ? null : hits.first.price;
  }

  List<Station> searchStations(String query, {int limit = 40}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <Station>[];
    for (final s in stations) {
      final haystack = '${s.brand} ${s.name} ${s.address} ${s.comune} ${s.prov}'.toLowerCase();
      if (haystack.contains(q)) {
        results.add(s);
        if (results.length >= limit * 3) break;
      }
    }
    return results;
  }

  List<Place> searchPlaces(String query, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final exact = <Place>[];
    final prefix = <Place>[];
    final contains = <Place>[];
    for (final p in places) {
      final n = p.name.toLowerCase();
      if (n == q) {
        exact.add(p);
      } else if (n.startsWith(q)) {
        prefix.add(p);
      } else if (n.contains(q) || p.prov.toLowerCase() == q) {
        contains.add(p);
      }
      if (exact.length + prefix.length + contains.length > limit * 4) break;
    }
    return [...exact, ...prefix, ...contains].take(limit).toList();
  }

  List<Station> inComune(String comune) => byComune[comune.toLowerCase()] ?? const [];

  List<Station> onHighway(String code) => byHighway[code] ?? const [];

  /// The best station of a comune for the current fuel, used by the search tab.
  StationHit? bestInComune(String comune, String fuel, bool self) {
    final list = inComune(comune);
    StationHit? best;
    for (final s in list) {
      final price = s.priceFor(fuel, self: self);
      if (price == null || !FuelSanity.plausible(fuel, price)) continue;
      if (best == null || price < best.price) {
        best = StationHit(station: s, distanceKm: 0, price: price, selfService: self);
      }
    }
    return best;
  }

  List<StationHit> highwayHits(String code, String fuel, bool self, SortMode sort) {
    final hits = <StationHit>[];
    for (final s in onHighway(code)) {
      final price = s.priceFor(fuel, self: self);
      if (price == null || !FuelSanity.plausible(fuel, price)) continue;
      hits.add(StationHit(station: s, distanceKm: 0, price: price, selfService: self));
    }
    _sortHits(hits, sort);
    return hits;
  }
}

class _CityAcc {
  const _CityAcc(this.name, this.prov, this.center);

  final String name;
  final String prov;
  final LatLng center;
}

/// 90th-percentile distance of the stations from a centre: a data-driven
/// "province radius" used to spot misplaced rows.
double _percentileDistance(List<Station> stations, LatLng center, double p) {
  final distances = stations.map((s) => Geo.distanceKm(center, s.position)).toList()..sort();
  final index = ((distances.length - 1) * p).round().clamp(0, distances.length - 1);
  return distances[index];
}

/// Median position of a set of stations (robust to outliers).
LatLng _median(List<Station> stations) {
  final lats = stations.map((s) => s.lat).toList()..sort();
  final lons = stations.map((s) => s.lon).toList()..sort();
  final mid = stations.length ~/ 2;
  return LatLng(lats[mid], lons[mid]);
}
