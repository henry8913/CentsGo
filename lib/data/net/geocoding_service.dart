import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../core/net/api_client.dart';
import '../../models/address.dart';
import '../address_index.dart';

class GeocodeResult {
  const GeocodeResult({required this.address, required this.label, required this.position});

  final Address address;
  final String label;
  final LatLng position;
}

/// Free geocoding through Nominatim, used only for **explicit** searches and
/// reverse geocoding. Search-as-you-type is forbidden by the usage policy and
/// is handled offline by [AddressIndex] instead.
///
/// Compliance: identifiable User-Agent, max one request per second (enforced by
/// [ApiClient]), results cached on disk, attribution shown in the UI.
class GeocodingService {
  GeocodingService({ApiClient? client, this.index})
      : _client = client ??
            ApiClient(
              userAgent: 'CentsGo/1.0 (+https://github.com/henry8913/CentsGo)',
              rateLimits: const {'nominatim.openstreetmap.org': Duration(seconds: 1)},
            );

  static const baseUrl = 'https://nominatim.openstreetmap.org';
  final ApiClient _client;
  final AddressIndex? index;

  Future<List<GeocodeResult>> search(Address address, {int limit = 5}) async {
    final query = _queryFor(address);
    if (query.trim().length < 3) return const [];
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'it',
      'limit': '$limit',
      'accept-language': 'it',
    });
    try {
      final response = await _client.get(uri, cacheTtl: const Duration(days: 30));
      if (!response.isValid) return const [];
      final list = jsonDecode(response.body) as List;
      return list
          .whereType<Map>()
          .map((e) => _toResult(e.cast<String, dynamic>()))
          .whereType<GeocodeResult>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Address?> reverse(LatLng point) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(queryParameters: {
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'it',
      'zoom': '18',
    });
    try {
      final response = await _client.get(uri, cacheTtl: const Duration(days: 30));
      if (!response.isValid) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['error'] != null) return null;
      final tags = (json['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      return _addressFromTags(tags, lat: point.latitude, lon: point.longitude);
    } catch (_) {
      return null;
    }
  }

  GeocodeResult? _toResult(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) return null;
    final tags = (json['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GeocodeResult(
      address: _addressFromTags(tags, lat: lat, lon: lon),
      label: (json['display_name'] as String? ?? '').trim(),
      position: LatLng(lat, lon),
    );
  }

  Address _addressFromTags(Map<String, dynamic> tags, {required double lat, required double lon}) {
    final city = (tags['city'] ?? tags['town'] ?? tags['village'] ?? tags['municipality'] ?? '').toString();
    final county = (tags['county'] ?? tags['state_district'] ?? '').toString();
    return Address(
      street: (tags['road'] ?? tags['pedestrian'] ?? tags['footway'] ?? '').toString(),
      houseNumber: (tags['house_number'] ?? '').toString(),
      postcode: (tags['postcode'] ?? '').toString(),
      city: city,
      province: _provinceCode(county, city),
      lat: lat,
      lon: lon,
    ).normalized();
  }

  /// Nominatim returns the province name ("Provincia di Milano"): map it back to
  /// the two-letter code used by the app.
  String _provinceCode(String county, String city) {
    final index = this.index;
    if (index == null) return '';
    final cleaned = county
        .replaceAll('Provincia di ', '')
        .replaceAll('Provincia della ', '')
        .replaceAll('Provincia del ', '')
        .replaceAll('Città metropolitana di ', '')
        .replaceAll('Libero consorzio comunale di ', '')
        .trim()
        .toLowerCase();
    for (final province in index.provinces) {
      if (province.name.toLowerCase() == cleaned) return province.code;
    }
    return index.comuneByName(city)?.province ?? '';
  }

  String _queryFor(Address address) {
    final parts = <String>[
      if (address.street.isNotEmpty) address.street,
      if (address.houseNumber.isNotEmpty) address.houseNumber,
      if (address.postcode.isNotEmpty) address.postcode,
      if (address.city.isNotEmpty) address.city,
      if (address.province.isNotEmpty) address.province,
      'Italia',
    ];
    return parts.join(', ');
  }
}
