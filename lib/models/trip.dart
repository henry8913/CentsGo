import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../core/geo.dart';
import 'station.dart';

/// A place the user can pick as origin/destination (city centroid derived from
/// the station registry, so it always has a real coordinate).
class Place {
  const Place({required this.name, required this.prov, required this.position});

  final String name;
  final String prov;
  final LatLng position;

  String get label => prov.isEmpty ? name : '$name ($prov)';

  Map<String, dynamic> toJson() => {
        'name': name,
        'prov': prov,
        'lat': position.latitude,
        'lon': position.longitude,
      };

  static Place fromJson(Map<String, dynamic> json) => Place(
        name: json['name'] as String,
        prov: json['prov'] as String? ?? '',
        position: LatLng((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble()),
      );
}

/// Saved or recent trip.
class TripPlan {
  const TripPlan({
    required this.id,
    required this.origin,
    required this.destination,
    required this.createdAt,
    this.corridorKm = 4,
  });

  final String id;
  final Place origin;
  final Place destination;
  final DateTime createdAt;
  final double corridorKm;

  String get label => '${origin.name} → ${destination.name}';

  double get distanceKm => Geo.distanceKm(origin.position, destination.position);

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'corridorKm': corridorKm,
      };

  static TripPlan fromJson(Map<String, dynamic> json) => TripPlan(
        id: json['id'] as String,
        origin: Place.fromJson((json['origin'] as Map).cast<String, dynamic>()),
        destination: Place.fromJson((json['destination'] as Map).cast<String, dynamic>()),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        corridorKm: (json['corridorKm'] as num?)?.toDouble() ?? 4,
      );
}

/// Result of a trip corridor search.
class TripResult {
  const TripResult({
    required this.trip,
    required this.path,
    required this.hits,
    required this.fuel,
    required this.selfService,
  });

  final TripPlan trip;
  final List<LatLng> path;
  final List<StationHit> hits;
  final String fuel;
  final bool selfService;

  StationHit? get cheapest => hits.isEmpty ? null : hits.first;

  /// Extra cost of a 50 L fill compared to the cheapest station on the route.
  double savingsVsMedian() {
    if (hits.length < 2) return 0;
    final prices = hits.map((h) => h.price).toList()..sort();
    final median = prices[prices.length ~/ 2];
    return (median - prices.first) * 50;
  }

  String get summary {
    final c = cheapest;
    if (c == null) return 'Nessun distributore sul percorso';
    return '${hits.length} distributori · più conveniente ${Fmt.price(c.price)} a ${c.station.comune}';
  }
}
