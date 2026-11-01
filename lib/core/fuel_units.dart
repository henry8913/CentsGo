import '../models/settings.dart';

/// Units depend on what the fuel is sold by: litres for petrol/diesel/LPG/HVO,
/// kilograms for methane, kWh for electricity. Keeping this in one place avoids
/// "L/100 km" labels on a methane or electric vehicle.
class FuelUnits {
  static String volume(String fuel) {
    switch (fuel) {
      case Fuels.metano:
        return 'kg';
      case Fuels.elettrico:
        return 'kWh';
      default:
        return 'L';
    }
  }

  /// "L/100 km", "kg/100 km", "kWh/100 km"
  static String per100(String fuel) => '${volume(fuel)}/100';

  /// "km/L", "km/kg", "km/kWh"
  static String perDistance(String fuel) => 'km/${volume(fuel)}';

  /// "€/L", "€/kg", "€/kWh"
  static String price(String fuel) => '€/${volume(fuel)}';

  /// Unit label for a consumption value, honouring the chosen display unit.
  static String consumption(String fuel, {required bool per100}) =>
      per100 ? per100Label(fuel) : perDistance(fuel);

  static String per100Label(String fuel) => '${volume(fuel)}/100 km';
}
