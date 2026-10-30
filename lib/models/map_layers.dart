import 'package:latlong2/latlong.dart';

/// Electric charging point (bundled snapshot of the Italian charging registry).
class EvCharger {
  EvCharger({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.prov,
    required this.kw,
    required this.plugs,
    required this.evse,
    required this.h24,
    required this.position,
  });

  final int id;
  final String brand;
  final String name;
  final String address;
  final String prov;
  final double kw;
  final List<String> plugs;
  final int evse;
  final bool h24;
  final LatLng position;

  bool get isFast => kw >= 50;
  bool get isHpc => kw >= 150;

  /// Power class used by the bundled EV tariff table.
  String get powerClass => kw >= 150 ? 'hpc' : (kw >= 50 ? 'dc' : 'ac');

  String get label => brand.isEmpty ? 'Colonnina' : brand;

  static EvCharger? fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lon = (json['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return EvCharger(
      id: (json['id'] as num?)?.toInt() ?? 0,
      brand: (json['brand'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      prov: (json['prov'] as String? ?? '').trim(),
      kw: (json['kw'] as num?)?.toDouble() ?? 0,
      plugs: ((json['plugs'] as List?) ?? const []).map((e) => e.toString()).toList(),
      evse: (json['evse'] as num?)?.toInt() ?? 1,
      h24: json['h24'] as bool? ?? false,
      position: LatLng(lat, lon),
    );
  }
}

/// Limited traffic zone polygon (ZTL).
class ZtlZone {
  ZtlZone({
    required this.id,
    required this.name,
    required this.comune,
    required this.prov,
    required this.rings,
    required this.hours,
    required this.alwaysActive,
    required this.category,
    required this.infoUrl,
  });

  final String id;
  final String name;
  final String comune;
  final String prov;
  final List<List<LatLng>> rings;
  final String hours;
  final bool alwaysActive;
  final String category;
  final String infoUrl;

  LatLng get center {
    final first = rings.first;
    return LatLng(
      first.map((p) => p.latitude).reduce((a, b) => a + b) / first.length,
      first.map((p) => p.longitude).reduce((a, b) => a + b) / first.length,
    );
  }

  static ZtlZone? fromJson(Map<String, dynamic> json) {
    final raw = (json['polygon'] as List?) ?? const [];
    final rings = <List<LatLng>>[];
    for (final ring in raw) {
      if (ring is! List) continue;
      final pts = <LatLng>[];
      for (final pair in ring) {
        if (pair is List && pair.length >= 2) {
          final lon = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          pts.add(LatLng(lat, lon));
        }
      }
      if (pts.length >= 3) rings.add(pts);
    }
    if (rings.isEmpty) return null;
    return ZtlZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ZTL',
      comune: json['comune'] as String? ?? '',
      prov: json['provincia'] as String? ?? '',
      rings: rings,
      hours: json['hours'] as String? ?? '',
      alwaysActive: json['always_active'] as bool? ?? false,
      category: json['category'] as String? ?? '',
      infoUrl: json['info_url'] as String? ?? '',
    );
  }
}

/// Service POI shown on the map (garages, car washes, tyre shops, inspections).
class PoiKind {
  static const repair = 'car_repair';
  static const wash = 'car_wash';
  static const tyres = 'tyres';
  static const inspection = 'inspection';

  static const all = [repair, wash, tyres, inspection];

  static String label(String kind) => switch (kind) {
        repair => 'Officine / Meccanici',
        wash => 'Autolavaggi',
        tyres => 'Gommisti',
        inspection => 'Centri Revisione',
        _ => kind,
      };

  static String shortLabel(String kind) => switch (kind) {
        repair => 'Officina',
        wash => 'Autolavaggio',
        tyres => 'Gommista',
        inspection => 'Revisione',
        _ => kind,
      };
}

/// Turns OSM `opening_hours` codes into something readable in Italian.
String prettyOsmHours(String raw) {
  const days = {
    'Mo': 'Lun',
    'Tu': 'Mar',
    'We': 'Mer',
    'Th': 'Gio',
    'Fr': 'Ven',
    'Sa': 'Sab',
    'Su': 'Dom',
    'PH': 'festivi',
  };
  var text = raw;
  days.forEach((code, label) {
    text = text.replaceAll(RegExp('\\b$code\\b'), label);
  });
  return text
      .replaceAll('off', 'chiuso')
      .replaceAll('open', 'aperto')
      .replaceAll('24/7', 'sempre aperto');
}

class PlacePoi {
  PlacePoi({
    required this.osmId,
    required this.kind,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.website,
    required this.openingHours,
    required this.position,
  });

  final String osmId;
  final String kind;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String website;
  final String openingHours;
  final LatLng position;

  static PlacePoi? fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lng'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final street = [
      (json['address'] as String? ?? '').trim(),
      (json['housenumber'] as String? ?? '').trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    final name = (json['name'] as String? ?? '').trim();
    return PlacePoi(
      osmId: json['osm_id'] as String? ?? '',
      kind: json['type'] as String? ?? PoiKind.repair,
      name: name.isEmpty ? PoiKind.shortLabel(json['type'] as String? ?? '') : name,
      address: street,
      city: (json['city'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
      website: (json['website'] as String? ?? '').trim(),
      openingHours: (json['opening_hours'] as String? ?? '').trim(),
      position: LatLng(lat, lon),
    );
  }
}
