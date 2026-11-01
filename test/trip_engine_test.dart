import 'package:centsgo/core/polyline.dart';
import 'package:centsgo/core/trip/toll_engine.dart';
import 'package:centsgo/core/trip/trip_cost.dart';
import 'package:centsgo/core/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

RoutePlan plan(double km, {List<RouteStepInfo> steps = const []}) => RoutePlan(
      points: const [LatLng(45.46, 9.19), LatLng(45.44, 9.28)],
      km: km,
      minutes: km / 80 * 60,
      steps: steps,
      provider: 'test',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polyline', () {
    test('decodes the canonical Google example', () {
      final points = PolylineCodec.decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.length, 3);
      expect(points.first.latitude, closeTo(38.5, 0.001));
      expect(points.first.longitude, closeTo(-120.2, 0.001));
      expect(points.last.latitude, closeTo(43.252, 0.001));
    });

    test('encode and decode are inverse', () {
      const original = [LatLng(45.4642, 9.19), LatLng(45.0703, 7.6869), LatLng(41.9028, 12.4964)];
      final encoded = PolylineCodec.encode(original);
      final decoded = PolylineCodec.decode(encoded);
      expect(decoded.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(decoded[i].latitude, closeTo(original[i].latitude, 0.0001));
        expect(decoded[i].longitude, closeTo(original[i].longitude, 0.0001));
      }
    });
  });

  group('Toll engine', () {
    late TollEngine engine;
    setUpAll(() async => engine = await TollEngine.load());

    test('sums motorway km per concession and rounds to 10 cents', () {
      final toll = engine.estimate([
        const MotorwayLeg(ref: 'A1', km: 100, concession: null),
        const MotorwayLeg(ref: 'A1', km: 50, concession: null),
        const MotorwayLeg(ref: 'A22', km: 50, concession: null),
      ]);
      expect(toll.lines.length, 3);
      expect(toll.total.euro, greaterThan(10));
      expect((toll.total.euro * 100).round() % 10, 0, reason: 'rounded to 0.10');
      expect(toll.verified, isFalse, reason: 'dataset is an estimate');
      expect(toll.minimumApplied, isFalse);
    });

    test('class B costs more than class A', () {
      final a = engine.estimate([const MotorwayLeg(ref: 'A4', km: 200, concession: null)]);
      final b = engine.estimate([const MotorwayLeg(ref: 'A4', km: 200, concession: null)], vehicleClass: 'B');
      expect(b.total.euro, greaterThan(a.total.euro));
    });

    test('no motorway means no toll', () {
      final toll = engine.estimate(const []);
      expect(toll.isEmpty, isTrue);
      expect(toll.total.isZero, isTrue);
    });

    test('minimum toll applies to short sections', () {
      final toll = engine.estimate([const MotorwayLeg(ref: 'A55', km: 1, concession: null)]);
      expect(toll.minimumApplied, isTrue);
      expect(toll.total.euro, greaterThanOrEqualTo(0.30));
    });
  });

  group('Trip cost', () {
    late TollEngine engine;
    setUpAll(() async => engine = await TollEngine.load());

    test('fuel, toll and split are consistent', () {
      final route = plan(300, steps: [
        const RouteStepInfo(km: 250, road: 'A1', ref: 'A1', instruction: 'continue', motorway: true),
        const RouteStepInfo(km: 50, road: 'SP1', ref: '', instruction: 'turn', motorway: false),
      ]);
      final cost = computeTripCost(
        route: route,
        tollEngine: engine,
        consumptionPer100: 6,
        pricePerLiter: 2,
        occupants: 4,
        parking: const Money(5),
      );
      expect(cost.fuelLiters, closeTo(18, 0.001));
      expect(cost.fuelCost.euro, closeTo(36, 0.001));
      expect(cost.hasToll, isTrue);
      expect(cost.toll.km, closeTo(250, 0.001));
      expect(cost.total.euro, closeTo(36 + cost.toll.total.euro + 5, 0.001));
      expect(cost.perPerson.euro, closeTo(cost.total.euro / 4, 0.001));
    });

    test('free route comparison produces a delta', () {
      final highway = plan(300, steps: [
        const RouteStepInfo(km: 300, road: 'A1', ref: 'A1', instruction: 'continue', motorway: true),
      ]);
      final free = RoutePlan(
        points: highway.points,
        km: 340,
        minutes: highway.minutes + 40,
        steps: const [],
        provider: 'test',
        avoidMotorways: true,
      );
      final cost = computeTripCost(
        route: highway,
        freeRoute: free,
        tollEngine: engine,
        consumptionPer100: 6,
        pricePerLiter: 2,
      );
      expect(cost.minutesSaved, closeTo(40, 0.001));
      expect(cost.tollVsFree, isNotNull);
    });
  });
}
