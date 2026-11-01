import 'package:latlong2/latlong.dart' hide Distance;

import '../units.dart';
import 'toll_engine.dart';

/// One navigable step of the route as returned by the router.
class RouteStepInfo {
  const RouteStepInfo({
    required this.km,
    required this.road,
    required this.ref,
    required this.instruction,
    required this.motorway,
  });

  final double km;
  final String road;
  final String ref;
  final String instruction;
  final bool motorway;

  bool get isMotorway => motorway || RegExp(r'^A\d{1,2}$').hasMatch(ref);
}

class RoutePlan {
  const RoutePlan({
    required this.points,
    required this.km,
    required this.minutes,
    required this.steps,
    required this.provider,
    this.fromCache = false,
    this.avoidMotorways = false,
  });

  final List<LatLng> points;
  final double km;
  final double minutes;
  final List<RouteStepInfo> steps;

  /// Name of the routing provider used, shown in the UI.
  final String provider;
  final bool fromCache;
  final bool avoidMotorways;

  Distance get distance => Distance(km);
  Duration get duration => Duration(seconds: (minutes * 60).round());

  /// Motorway sections grouped by ref, in order of appearance.
  List<MotorwayLeg> get motorwayLegs {
    final legs = <MotorwayLeg>[];
    for (final step in steps) {
      if (!step.isMotorway || step.km <= 0) continue;
      final ref = step.ref.isEmpty ? 'A?' : step.ref.toUpperCase();
      if (legs.isNotEmpty && legs.last.ref == ref) {
        legs[legs.length - 1] = MotorwayLeg(ref: ref, km: legs.last.km + step.km, concession: legs.last.concession);
      } else {
        legs.add(MotorwayLeg(ref: ref, km: step.km, concession: null));
      }
    }
    return legs;
  }
}

/// Full cost breakdown of a trip, computed on device.
class TripCostResult {
  const TripCostResult({
    required this.route,
    required this.toll,
    required this.consumptionPer100,
    required this.pricePerLiter,
    required this.fuelLiters,
    required this.occupants,
    required this.parking,
    this.freeRoute,
    this.priceStationName,
    this.priceIsEstimate = false,
  });

  final RoutePlan route;
  final RoutePlan? freeRoute;
  final TollEstimate toll;
  final double consumptionPer100;
  final double pricePerLiter;
  final double fuelLiters;
  final int occupants;
  final Money parking;
  final String? priceStationName;
  final bool priceIsEstimate;

  Money get fuelCost => Money(fuelLiters * pricePerLiter);
  Money get total => fuelCost + toll.total + parking;
  Money get perPerson => total.dividedBy(occupants);

  bool get hasToll => !toll.isEmpty && toll.total.euro > 0;

  /// Extra cost of the motorway route versus the free one.
  Money? get tollVsFree {
    final free = freeRoute;
    if (free == null) return null;
    return Money(total.euro - (fuelLiters * pricePerLiter + parking.euro));
  }

  /// Time saved by the motorway route, in minutes.
  double? get minutesSaved {
    final free = freeRoute;
    if (free == null) return null;
    return free.minutes - route.minutes;
  }
}

/// Pure cost engine: given a route, the consumption and the price paid at the
/// pump, it returns the full breakdown. Kept free of Flutter so it is testable.
TripCostResult computeTripCost({
  required RoutePlan route,
  required TollEngine tollEngine,
  required double consumptionPer100,
  required double pricePerLiter,
  int occupants = 1,
  Money parking = Money.zero,
  RoutePlan? freeRoute,
  String? priceStationName,
  bool priceIsEstimate = false,
  String vehicleClass = 'A',
}) {
  final liters = consumptionPer100 / 100 * route.km;
  final toll = tollEngine.estimate(route.motorwayLegs, vehicleClass: vehicleClass);
  return TripCostResult(
    route: route,
    freeRoute: freeRoute,
    toll: toll,
    consumptionPer100: consumptionPer100,
    pricePerLiter: pricePerLiter,
    fuelLiters: liters,
    occupants: occupants <= 0 ? 1 : occupants,
    parking: parking,
    priceStationName: priceStationName,
    priceIsEstimate: priceIsEstimate,
  );
}
