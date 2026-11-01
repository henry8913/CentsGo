/// Value objects for the units used across CentsGo.
///
/// They exist so that "5,6 L/100 km", "17,9 km/L" and "0,095 €/km" are never
/// stored as loose doubles: conversions and formatting live in one place and
/// the UI can switch unit without touching the data.
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Unit chosen by the user for fuel consumption.
enum ConsumptionUnit {
  litersPer100km('L/100 km'),
  kmPerLiter('km/L');

  const ConsumptionUnit(this.label);
  final String label;
}

@immutable
class Money implements Comparable<Money> {
  const Money(this.euro);

  static const zero = Money(0);

  final double euro;

  Money operator +(Money other) => Money(euro + other.euro);
  Money operator -(Money other) => Money(euro - other.euro);
  Money operator *(double factor) => Money(euro * factor);
  Money dividedBy(int people) => Money(people <= 0 ? euro : euro / people);

  bool get isZero => euro.abs() < 0.005;
  bool get isNegative => euro < 0;

  String format({int decimals = 2}) {
    final n = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: decimals);
    return n.format(euro);
  }

  /// Format without the currency symbol, for tables and tiles.
  String amount({int decimals = 2}) {
    final n = NumberFormat('#,##0.00', 'it_IT');
    return n.format(euro);
  }

  @override
  int compareTo(Money other) => euro.compareTo(other.euro);

  @override
  bool operator ==(Object other) => other is Money && (other.euro - euro).abs() < 0.000001;

  @override
  int get hashCode => euro.hashCode;

  @override
  String toString() => format();
}

@immutable
class Distance {
  const Distance(this.km);

  static const zero = Distance(0);

  final double km;

  Distance operator +(Distance other) => Distance(km + other.km);
  Distance operator -(Distance other) => Distance(km - other.km);
  Distance operator *(double factor) => Distance(km * factor);

  bool get isZero => km.abs() < 0.0005;
  double get meters => km * 1000;

  String format() {
    if (km < 0.95) return '${(km * 1000).round()} m';
    if (km < 10) return '${NumberFormat('#,##0.0', 'it_IT').format(km)} km';
    return '${NumberFormat('#,##0', 'it_IT').format(km.round())} km';
  }

  @override
  bool operator ==(Object other) => other is Distance && (other.km - km).abs() < 0.000001;

  @override
  int get hashCode => km.hashCode;

  @override
  String toString() => format();
}

@immutable
class Volume {
  const Volume(this.liters);

  static const zero = Volume(0);

  final double liters;

  Volume operator +(Volume other) => Volume(liters + other.liters);
  Volume operator -(Volume other) => Volume(liters - other.liters);
  Volume operator *(double factor) => Volume(liters * factor);

  /// Cost of this volume at [pricePerLiter] (€ per litre).
  Money costAt(double pricePerLiter) => Money(liters * pricePerLiter);

  String format({int decimals = 1}) => '${NumberFormat('#,##0.${'0' * decimals}', 'it_IT').format(liters)} L';

  @override
  bool operator ==(Object other) => other is Volume && (other.liters - liters).abs() < 0.000001;

  @override
  int get hashCode => liters.hashCode;

  @override
  String toString() => format();
}

/// Fuel (or energy) consumption. The canonical value is always per 100 km, in
/// litres or kWh depending on the vehicle.
@immutable
class Consumption {
  const Consumption.per100km(this.per100);

  final double per100;

  /// km per litre (or km per kWh for electric vehicles).
  double get kmPerUnit => per100 <= 0 ? 0 : 100 / per100;

  factory Consumption.fromKmPerUnit(double value) =>
      Consumption.per100km(value <= 0 ? 0 : 100 / value);

  static const zero = Consumption.per100km(0);

  bool get isZero => per100 <= 0;

  /// Energy/fuel needed for a distance.
  double unitsFor(Distance distance) => per100 / 100 * distance.km;

  Volume volumeFor(Distance distance) => Volume(unitsFor(distance));

  /// €/km at [pricePerUnit] (€ per litre or kWh).
  Money costPerKm(double pricePerUnit) => Money(per100 / 100 * pricePerUnit);

  double valueIn(ConsumptionUnit unit) =>
      unit == ConsumptionUnit.litersPer100km ? per100 : kmPerUnit;

  static Consumption fromValue(double value, ConsumptionUnit unit) =>
      unit == ConsumptionUnit.litersPer100km
          ? Consumption.per100km(value)
          : Consumption.fromKmPerUnit(value);

  String format(ConsumptionUnit unit, {String unitSuffix = 'L/100'}) {
    if (isZero) return '—';
    if (unit == ConsumptionUnit.litersPer100km) {
      return '${NumberFormat('#,##0.0', 'it_IT').format(per100)} $unitSuffix';
    }
    return '${NumberFormat('#,##0.0', 'it_IT').format(kmPerUnit)} km/${unitSuffix.split('/').first}';
  }

  @override
  String toString() => format(ConsumptionUnit.litersPer100km);
}
