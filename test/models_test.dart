import 'package:centsgo/core/geo.dart';
import 'package:centsgo/models/settings.dart';
import 'package:centsgo/models/station.dart';
import 'package:centsgo/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Geo', () {
    test('haversine matches known distance Milano-Roma', () {
      final km = Geo.distanceKm(const LatLng(45.4642, 9.19), const LatLng(41.9028, 12.4964));
      expect(km, closeTo(477, 3));
    });

    test('distance to path is zero on the line', () {
      final path = Geo.interpolate(const LatLng(45.0, 9.0), const LatLng(45.0, 10.0), steps: 10);
      final onLine = Geo.distanceToPath(const LatLng(45.0, 9.5), path);
      expect(onLine.km, lessThan(0.05));
      expect(onLine.t, closeTo(0.5, 0.02));
    });

    test('distance to path measures the detour', () {
      final path = Geo.interpolate(const LatLng(45.0, 9.0), const LatLng(45.0, 10.0), steps: 10);
      final offLine = Geo.distanceToPath(const LatLng(45.05, 9.5), path);
      expect(offLine.km, closeTo(5.56, 0.6));
    });
  });

  group('Station', () {
    final station = Station.fromCompact([
      '123',
      0,
      'Test Impianto',
      'Via Roma 1',
      'Milano',
      'MI',
      45.46,
      9.19,
      'A4',
      1792996472,
      {
        'Benzina': [1.899, 2.099],
        'Gasolio': [null, 1.999],
        'GPL': [0.799, null],
      },
    ], ['Q8']);

    test('parses the compact row', () {
      expect(station.id, '123');
      expect(station.brand, 'Q8');
      expect(station.isHighway, isTrue);
      expect(station.highway, 'A4');
      expect(station.updatedAt, isNotNull);
      expect(station.initial, 'Q');
    });

    test('self price falls back to servito and vice versa', () {
      expect(station.priceFor('Benzina', self: true), 1.899);
      expect(station.priceFor('Benzina', self: false), 2.099);
      expect(station.priceFor('Gasolio', self: true), 1.999);
      expect(station.priceFor('GPL', self: false), 0.799);
      expect(station.priceFor('Metano', self: true), isNull);
    });

    test('missing fuel is not sold', () {
      expect(station.sells('Metano'), isFalse);
      expect(station.sells('Benzina'), isTrue);
    });
  });

  group('Settings', () {
    test('round-trips through JSON including the optional brand', () {
      const settings = AppSettings(
        fuel: Fuels.gasolio,
        sort: SortMode.best,
        radiusKm: 22,
        brand: 'Eni',
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.fuel, Fuels.gasolio);
      expect(restored.sort, SortMode.best);
      expect(restored.radiusKm, 22);
      expect(restored.brand, 'Eni');
      expect(restored.copyWith(clearBrand: true).brand, isNull);
    });
  });

  group('Garage', () {
    test('tank cost and cost per km use the given price', () {
      final vehicle = Vehicle(
        id: 'v1',
        nickname: 'Panda',
        type: VehicleType.citycar,
        brand: 'Fiat',
        model: 'Panda',
        year: 2020,
        plate: 'AA000BB',
        fuel: Fuels.benzina,
        tankLiters: 40,
        consumption: 5.5,
        color: VehicleColor.blu,
        deadlines: const [],
      );
      expect(vehicle.tankCost(2), 80);
      expect(vehicle.costPerKm(2), closeTo(0.11, 0.001));
      expect(vehicle.rangeKm, closeTo(727.27, 0.1));
    });

    test('stats aggregate the month and the measured consumption', () {
      final now = DateTime.now();
      final refuels = [
        Refuel(
          id: '1',
          vehicleId: 'v1',
          date: now.subtract(const Duration(days: 20)),
          liters: 30,
          pricePerLiter: 2,
          odometerKm: 10000,
        ),
        Refuel(
          id: '2',
          vehicleId: 'v1',
          date: now,
          liters: 30,
          pricePerLiter: 2,
          odometerKm: 10500,
        ),
      ];
      final stats = GarageStats.from(refuels);
      expect(stats.totalLiters, 60);
      expect(stats.totalSpend, 120);
      expect(stats.avgPrice, 2);
      expect(stats.measuredConsumption, closeTo(6.0, 0.001));
    });

    test('deadline countdown is day based', () {
      final now = DateTime(2026, 10, 29);
      final deadline = VehicleDeadline(kind: 'Bollo auto', due: DateTime(2026, 11, 5));
      expect(deadline.daysLeft(now), 7);
      expect(deadline.isSoon(now), isTrue);
      expect(VehicleDeadline(kind: 'x', due: DateTime(2026, 10, 1)).isOverdue(now), isTrue);
    });
  });
}
