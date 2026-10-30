import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Small geodesy toolkit used by the list, the map and the trip planner.
/// Everything is kept dependency-free so it also runs on desktop/web.
class Geo {
  static const double earthRadiusKm = 6371.0088;

  /// Great-circle distance in kilometres.
  static double distanceKm(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Projected distance (metres) from [p] to the closest point of segment [a]-[b].
  /// Uses the local equirectangular approximation, accurate well below 100 km.
  static double _segmentDistanceKm(LatLng p, LatLng a, LatLng b, double kmPerDegLat, double kmPerDegLon) {
    final px = (p.longitude - a.longitude) * kmPerDegLon;
    final py = (p.latitude - a.latitude) * kmPerDegLat;
    final bx = (b.longitude - a.longitude) * kmPerDegLon;
    final by = (b.latitude - a.latitude) * kmPerDegLat;
    final len2 = bx * bx + by * by;
    if (len2 == 0) return math.sqrt(px * px + py * py);
    var t = (px * bx + py * by) / len2;
    t = t.clamp(0.0, 1.0);
    final dx = px - bx * t;
    final dy = py - by * t;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Distance from [p] to a polyline, plus the normalised position (0..1) of the
  /// closest projection along the route.
  static ({double km, double t}) distanceToPath(LatLng p, List<LatLng> path) {
    if (path.isEmpty) return (km: double.infinity, t: 0);
    if (path.length == 1) return (km: distanceKm(p, path.first), t: 0);
    final kmPerDegLat = 111.32;
    final kmPerDegLon = 111.32 * math.cos(_rad(p.latitude)).abs().clamp(0.05, 1.0);
    var best = double.infinity;
    var bestT = 0.0;
    final lengths = <double>[];
    for (var i = 0; i < path.length - 1; i++) {
      final l = distanceKm(path[i], path[i + 1]);
      lengths.add(l);
    }
    final total = lengths.fold<double>(0, (a, b) => a + b);
    var prefix = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final d = _segmentDistanceKm(p, path[i], path[i + 1], kmPerDegLat, kmPerDegLon);
      if (d < best) {
        best = d;
        final segT = _projectionT(p, path[i], path[i + 1], kmPerDegLat, kmPerDegLon);
        bestT = total == 0 ? 0 : (prefix + lengths[i] * segT) / total;
      }
      prefix += lengths[i];
    }
    return (km: best, t: bestT.clamp(0.0, 1.0));
  }

  static double _projectionT(LatLng p, LatLng a, LatLng b, double kmPerDegLat, double kmPerDegLon) {
    final px = (p.longitude - a.longitude) * kmPerDegLon;
    final py = (p.latitude - a.latitude) * kmPerDegLat;
    final bx = (b.longitude - a.longitude) * kmPerDegLon;
    final by = (b.latitude - a.latitude) * kmPerDegLat;
    final len2 = bx * bx + by * by;
    if (len2 == 0) return 0;
    return ((px * bx + py * by) / len2).clamp(0.0, 1.0);
  }

  /// Densifies the great-circle between two points into [steps] segments.
  /// Good enough for a corridor search and for drawing the route line.
  static List<LatLng> interpolate(LatLng a, LatLng b, {int steps = 48}) {
    final points = <LatLng>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ));
    }
    return points;
  }

  /// Degrees of latitude/longitude for a radius in km (for cheap bbox filtering).
  static ({double dLat, double dLon}) bboxDelta(double radiusKm, double atLatitude) {
    final dLat = radiusKm / 111.32;
    final cos = math.cos(_rad(atLatitude)).abs();
    final dLon = radiusKm / (111.32 * (cos < 0.02 ? 0.02 : cos));
    return (dLat: dLat, dLon: dLon);
  }

  /// Nearest-neighbour simplification (Douglas-Peucker) for polygon rendering.
  static List<LatLng> simplify(List<LatLng> points, double toleranceKm) {
    if (points.length < 3) return points;
    var maxDist = 0.0;
    var index = 0;
    final first = points.first;
    final last = points.last;
    for (var i = 1; i < points.length - 1; i++) {
      final d = _segmentDistanceKm(points[i], first, last, 111.32, 111.32);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist > toleranceKm) {
      final left = simplify(points.sublist(0, index + 1), toleranceKm);
      final right = simplify(points.sublist(index), toleranceKm);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [first, last];
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
