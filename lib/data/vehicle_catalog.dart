import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Car and motorbike makes/models bundled with the app (used by the Garage form
/// instead of a free-text field).
class VehicleCatalog {
  VehicleCatalog._(this.cars, this.bikes);

  final Map<String, List<String>> cars;
  final Map<String, List<String>> bikes;

  static VehicleCatalog? _instance;

  static Future<VehicleCatalog> load() async {
    if (_instance != null) return _instance!;
    final carsRaw = await rootBundle.loadString('assets/data/auto_marche_modelli.json');
    final bikesRaw = await rootBundle.loadString('assets/data/moto_marche_modelli.json');
    Map<String, List<String>> parse(String raw) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()));
    }

    _instance = VehicleCatalog._(parse(carsRaw), parse(bikesRaw));
    return _instance!;
  }

  Map<String, List<String>> forType(bool twoWheels) => twoWheels ? bikes : cars;

  List<String> brands(bool twoWheels) => forType(twoWheels).keys.toList()..sort();
}
