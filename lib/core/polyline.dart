import 'package:latlong2/latlong.dart';

/// Google encoded polyline (precision 5), the format OSRM returns when
/// `geometries=polyline` is requested. Kept dependency-free and tested.
class PolylineCodec {
  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        if (index >= encoded.length) return points;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) return points;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  static String encode(List<LatLng> points) {
    final buffer = StringBuffer();
    var prevLat = 0;
    var prevLng = 0;
    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();
      _write(buffer, lat - prevLat);
      _write(buffer, lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return buffer.toString();
  }

  static void _write(StringBuffer buffer, int value) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    buffer.writeCharCode(v + 63);
  }
}
