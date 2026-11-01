import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../core/net/api_client.dart';
import '../../core/polyline.dart';
import '../../core/trip/trip_cost.dart';

/// Routing behind an interface so the provider can be swapped.
///
/// The public OSRM demo server is fine for development only: its usage policy
/// forbids production traffic. The base URL is configurable so a self-hosted
/// OSRM instance can be used without code changes; when the service is
/// unavailable the app degrades to the straight-line corridor.
class RoutingService {
  RoutingService({ApiClient? client, String? baseUrl})
      : _client = client ??
            ApiClient(userAgent: 'CentsGo/1.0 (+https://github.com/henry8913/CentsGo)'),
        baseUrl = baseUrl ?? defaultBaseUrl;

  static const defaultBaseUrl = 'https://router.project-osrm.org';
  static const demoProviderName = 'OSRM demo (solo sviluppo)';

  final ApiClient _client;
  final String baseUrl;

  bool get isDemoServer => baseUrl.contains('project-osrm.org');
  String get providerName => isDemoServer ? demoProviderName : 'OSRM ($baseUrl)';

  Future<RoutePlan?> route(
    LatLng from,
    LatLng to, {
    bool avoidMotorways = false,
    bool forceRefresh = false,
  }) async {
    final coords = '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final query = <String, String>{
      'overview': 'full',
      'geometries': 'polyline',
      'steps': 'true',
      'alternatives': 'false',
      if (avoidMotorways) 'exclude': 'motorway',
    };
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coords').replace(queryParameters: query);
    try {
      final response = await _client.get(
        uri,
        cacheTtl: const Duration(days: 3),
        forceRefresh: forceRefresh,
      );
      if (!response.isValid) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;
      final routes = (json['routes'] as List?) ?? const [];
      if (routes.isEmpty) return null;
      return _parse(routes.first as Map<String, dynamic>, avoidMotorways, response.fromCache);
    } catch (_) {
      return null;
    }
  }

  RoutePlan _parse(Map<String, dynamic> route, bool avoidMotorways, bool fromCache) {
    final geometry = route['geometry'] as String? ?? '';
    final points = PolylineCodec.decode(geometry);
    final steps = <RouteStepInfo>[];
    final legs = (route['legs'] as List?) ?? const [];
    for (final leg in legs) {
      final legSteps = ((leg as Map)['steps'] as List?) ?? const [];
      for (final raw in legSteps) {
        final step = (raw as Map).cast<String, dynamic>();
        final maneuver = (step['maneuver'] as Map?)?.cast<String, dynamic>() ?? const {};
        final ref = (step['ref'] as String? ?? '');
        final name = (step['name'] as String? ?? '').trim();
        steps.add(RouteStepInfo(
          km: ((step['distance'] as num?)?.toDouble() ?? 0) / 1000,
          road: name,
          ref: ref,
          instruction: (maneuver['type'] as String? ?? '').replaceAll('_', ' '),
          motorway: RegExp(r'\bA\d{1,2}\b').hasMatch(ref) ||
              name.toLowerCase().contains('autostrada') ||
              (step['class'] as String? ?? '') == 'motorway',
        ));
      }
    }
    return RoutePlan(
      points: points,
      km: ((route['distance'] as num?)?.toDouble() ?? 0) / 1000,
      minutes: ((route['duration'] as num?)?.toDouble() ?? 0) / 60,
      steps: steps,
      provider: providerName,
      fromCache: fromCache,
      avoidMotorways: avoidMotorways,
    );
  }
}
