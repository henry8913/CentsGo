import 'package:latlong2/latlong.dart';

/// One fuel station from the MIMIT *Osservaprezzi* open data snapshot.
///
/// The bundled snapshot is deliberately compact (a JSON list per station) so
/// 21k+ stations load in a few hundred milliseconds even on low-end phones.
class Station {
  Station({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.comune,
    required this.prov,
    required this.lat,
    required this.lon,
    required this.highway,
    required this.updatedAt,
    required this.prices,
  });

  final String id;
  final String brand;
  final String name;
  final String address;
  final String comune;
  final String prov;
  final double lat;
  final double lon;

  /// Motorway code (A1, A4, ...) when the station is on a motorway.
  final String? highway;
  final DateTime? updatedAt;

  /// fuel -> [self, servito]; a missing entry means "not sold".
  final Map<String, List<double?>> prices;

  LatLng get position => LatLng(lat, lon);
  bool get isHighway => highway != null;

  /// First letter used by the round brand badge in the list.
  String get initial {
    final t = brand.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }

  Iterable<String> get fuels => prices.keys;

  double? selfPrice(String fuel) {
    final p = prices[fuel];
    if (p == null || p.isEmpty) return null;
    return p[0];
  }

  double? servitoPrice(String fuel) {
    final p = prices[fuel];
    if (p == null || p.length < 2) return null;
    return p[1];
  }

  /// Price honouring the self-service preference, falling back to the other
  /// mode when a station only publishes one of them.
  double? priceFor(String fuel, {required bool self}) {
    final s = selfPrice(fuel);
    final f = servitoPrice(fuel);
    if (self) return s ?? f;
    return f ?? s;
  }

  bool sells(String fuel) => priceFor(fuel, self: true) != null;

  String get displayName => name.isEmpty ? brand : name;

  String get fullAddress {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (comune.isNotEmpty) comune,
      if (prov.isNotEmpty) '($prov)',
    ];
    return parts.join(', ');
  }

  /// Static factory for the compact array layout produced by
  /// tool/build_seed_data.py:
  /// [id, brandIdx, name, address, comune, prov, lat, lon, highway, updated, prices]
  static Station fromCompact(List<dynamic> row, List<String> brands) {
    final id = row[0].toString();
    final brandIndex = row[1] as int;
    final rawPrices = (row[10] as Map).cast<String, dynamic>();
    final parsed = <String, List<double?>>{};
    rawPrices.forEach((fuel, value) {
      final list = (value as List).map((e) => e == null ? null : (e as num).toDouble()).toList();
      parsed[fuel] = list;
    });
    final updated = row[9] as int;
    return Station(
      id: id,
      brand: brandIndex >= 0 && brandIndex < brands.length ? brands[brandIndex] : 'Pompe Bianche',
      name: (row[2] as String).trim(),
      address: (row[3] as String).trim(),
      comune: (row[4] as String).trim(),
      prov: (row[5] as String).trim(),
      lat: (row[6] as num).toDouble(),
      lon: (row[7] as num).toDouble(),
      highway: row[8] as String?,
      updatedAt: updated > 0 ? DateTime.fromMillisecondsSinceEpoch(updated * 1000) : null,
      prices: parsed,
    );
  }
}

/// A station enriched with the values computed for the current query.
class StationHit {
  const StationHit({
    required this.station,
    required this.distanceKm,
    required this.price,
    required this.selfService,
    this.detourKm,
    this.alongRouteT,
  });

  final Station station;
  final double distanceKm;
  final double price;
  final bool selfService;

  /// Extra kilometres compared to the direct route (trip planner only).
  final double? detourKm;

  /// 0..1 position along the planned route (trip planner only).
  final double? alongRouteT;

  bool get isHighway => station.isHighway;
}
