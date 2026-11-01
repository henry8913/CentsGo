import 'package:centsgo/core/fuel_units.dart';
import 'package:centsgo/core/units.dart';
import 'package:centsgo/models/settings.dart';
import 'package:centsgo/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fuel units', fuelUnitsTests);

  group('Units', () {
    test('consumption converts both ways', () {
      const l100 = Consumption.per100km(5.6);
      expect(l100.kmPerUnit, closeTo(17.857, 0.01));
      final kmPerLiter = Consumption.fromKmPerUnit(17.857);
      expect(kmPerLiter.per100, closeTo(5.6, 0.01));
      expect(l100.valueIn(ConsumptionUnit.kmPerLiter), closeTo(17.857, 0.01));
      expect(Consumption.fromValue(20, ConsumptionUnit.kmPerLiter).per100, closeTo(5, 0.001));
    });

    test('volume and distance feed consumption', () {
      const consumption = Consumption.per100km(6);
      final volume = consumption.volumeFor(const Distance(250));
      expect(volume.liters, closeTo(15, 0.001));
      expect(volume.costAt(2).euro, closeTo(30, 0.001));
      expect(const Distance(0.4).format(), '400 m');
      expect(const Distance(9.4).format(), '9,4 km');
      expect(const Distance(12.4).format(), '12 km');
    });

    test('money splits and formats', () {
      const money = Money(75.5);
      expect(money.dividedBy(3).euro, closeTo(25.1666, 0.0001));
      expect(money.format(), contains('75,50'));
      expect(Money.zero.isZero, isTrue);
      expect((const Money(1.2) - const Money(0.2)).euro, closeTo(1.0, 1e-9));
    });
  });

  group('Refuel diary', () {
    Refuel fuel({
      required String id,
      required int day,
      required double liters,
      double? odo,
      bool full = true,
    }) =>
        Refuel(
          id: id,
          vehicleId: 'v1',
          date: DateTime(2026, 1, day),
          liters: liters,
          pricePerLiter: 2,
          odometerKm: odo,
          fullTank: full,
        );

    test('consumption is measured between full tanks, counting partials', () {
      final stats = GarageStats.from([
        fuel(id: '1', day: 1, liters: 40, odo: 10000),
        fuel(id: '2', day: 10, liters: 20, odo: 10300, full: false),
        fuel(id: '3', day: 20, liters: 25, odo: 10750),
      ]);
      // 300 km between the two full tanks, but 20 L were added in between:
      // the measurable interval is 750 km with 45 L.
      expect(stats.fullTanks, 2);
      expect(stats.partialRefuels, 1);
      expect(stats.measuredConsumption, closeTo(6.0, 0.001));
      expect(stats.measuredKm, closeTo(750, 0.001));
      expect(stats.measuredCost?.euro, closeTo(90 / 750, 0.0001));
      expect(stats.consumptionIsApproximate, isFalse);
    });

    test('a single full tank falls back to the approximate method', () {
      final stats = GarageStats.from([
        fuel(id: '1', day: 1, liters: 30, odo: 1000),
        fuel(id: '2', day: 5, liters: 30, odo: 1500, full: false),
      ]);
      expect(stats.measuredConsumption, closeTo(6.0, 0.001));
      expect(stats.consumptionIsApproximate, isTrue);
    });

    test('refuels without odometer never produce a measurement', () {
      final stats = GarageStats.from(
        [
          fuel(id: '1', day: 1, liters: 30),
          fuel(id: '2', day: 5, liters: 30),
        ],
        now: DateTime(2026, 1, 20),
      );
      expect(stats.measuredConsumption, isNull);
      expect(stats.totalLiters, 60);
      expect(stats.totalSpend, 120);
      expect(stats.monthSpend, 120);
    });
  });
}

void fuelUnitsTests() {
  test('volume unit follows the fuel', () {
    expect(FuelUnits.volume(Fuels.benzina), 'L');
    expect(FuelUnits.volume(Fuels.metano), 'kg');
    expect(FuelUnits.volume(Fuels.elettrico), 'kWh');
    expect(FuelUnits.per100(Fuels.metano), 'kg/100');
    expect(FuelUnits.perDistance(Fuels.elettrico), 'km/kWh');
    expect(FuelUnits.price(Fuels.metano), '€/kg');
    expect(FuelUnits.per100Label(Fuels.elettrico), 'kWh/100 km');
  });
}
