import '../theme/app_theme.dart';
import 'trip.dart';

export 'trip.dart';

/// Sorting of the results list (mirrors the three chips of the original app).
enum SortMode {
  price('Prezzo'),
  distance('Distanza'),
  best('Migliori');

  const SortMode(this.label);
  final String label;
}

/// Fuel selector choices. The list is the canonical set the seed builder
/// normalises into (see tool/build_seed_data.py).
class Fuels {
  static const benzina = 'Benzina';
  static const gasolio = 'Gasolio';
  static const gpl = 'GPL';
  static const metano = 'Metano';
  static const hvo = 'HVO';
  static const elettrico = 'Elettrico';

  static const all = [benzina, gasolio, gpl, metano, hvo];

  static String unit(String fuel) => fuel == metano ? 'kg' : 'L';

  static String label(String fuel) => fuel;

  static const icons = <String, String>{};
}


/// Plausibility bands used to drop implausible prices from the registry (typos,
/// shifted decimals, dead stations). € per litre, € per kg for methane.
class FuelSanity {
  static const _bands = <String, (double, double)>{
    'Benzina': (1.20, 3.60),
    'Gasolio': (1.20, 3.60),
    'GPL': (0.40, 1.70),
    'Metano': (0.60, 3.20),
    'HVO': (1.20, 3.80),
  };

  static bool plausible(String fuel, double price) {
    final band = _bands[fuel];
    if (band == null) return price > 0;
    return price >= band.$1 && price <= band.$2;
  }
}

/// User preferences, persisted as JSON in shared_preferences.
class AppSettings {
  const AppSettings({
    this.fuel = Fuels.benzina,
    this.selfService = true,
    this.sort = SortMode.price,
    this.radiusKm = 15,
    this.themeMode = AppThemeMode.system,
    this.homePlace,
    this.layers = const MapLayerSettings(),
    this.homeCity = 'Milano',
    this.onboarded = false,
    this.brand,
    this.followGps = true,
  });

  final String fuel;
  final bool selfService;
  final SortMode sort;
  final double radiusKm;
  final AppThemeMode themeMode;

  /// Optional brand filter (Bandiera) applied to list and map.
  final String? brand;

  /// Manual location, used when GPS is denied or unavailable (desktop).
  final Place? homePlace;
  final MapLayerSettings layers;
  final String homeCity;
  final bool onboarded;

  /// When true the app follows the GPS at startup; when false it stays on the
  /// area the user picked manually.
  final bool followGps;

  AppSettings copyWith({
    String? fuel,
    bool? selfService,
    SortMode? sort,
    double? radiusKm,
    AppThemeMode? themeMode,
    Place? homePlace,
    MapLayerSettings? layers,
    String? homeCity,
    bool? onboarded,
    String? brand,
    bool clearBrand = false,
    bool? followGps,
  }) {
    return AppSettings(
      fuel: fuel ?? this.fuel,
      selfService: selfService ?? this.selfService,
      sort: sort ?? this.sort,
      radiusKm: radiusKm ?? this.radiusKm,
      themeMode: themeMode ?? this.themeMode,
      homePlace: homePlace ?? this.homePlace,
      layers: layers ?? this.layers,
      homeCity: homeCity ?? this.homeCity,
      onboarded: onboarded ?? this.onboarded,
      brand: clearBrand ? null : (brand ?? this.brand),
      followGps: followGps ?? this.followGps,
    );
  }

  Map<String, dynamic> toJson() => {
        'fuel': fuel,
        'selfService': selfService,
        'sort': sort.name,
        'radiusKm': radiusKm,
        'themeMode': themeMode.name,
        'homePlace': homePlace?.toJson(),
        'layers': layers.toJson(),
        'homeCity': homeCity,
        'onboarded': onboarded,
        'brand': brand,
        'followGps': followGps,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fuel: json['fuel'] as String? ?? Fuels.benzina,
      selfService: json['selfService'] as bool? ?? true,
      sort: SortMode.values.firstWhere(
        (s) => s.name == json['sort'],
        orElse: () => SortMode.price,
      ),
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 15,
      themeMode: AppThemeMode.values.firstWhere(
        (t) => t.name == json['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      homePlace: json['homePlace'] == null
          ? null
          : Place.fromJson((json['homePlace'] as Map).cast<String, dynamic>()),
      layers: json['layers'] == null
          ? const MapLayerSettings()
          : MapLayerSettings.fromJson((json['layers'] as Map).cast<String, dynamic>()),
      homeCity: json['homeCity'] as String? ?? 'Milano',
      onboarded: json['onboarded'] as bool? ?? false,
      brand: json['brand'] as String?,
      followGps: json['followGps'] as bool? ?? true,
    );
  }
}

class MapLayerSettings {
  const MapLayerSettings({
    this.ev = false,
    this.ztl = false,
    this.pois = false,
    this.poiKinds = const {'car_repair', 'car_wash', 'tyres'},
    this.highways = false,
  });

  final bool ev;
  final bool ztl;
  final bool pois;
  final Set<String> poiKinds;
  final bool highways;

  MapLayerSettings copyWith({
    bool? ev,
    bool? ztl,
    bool? pois,
    Set<String>? poiKinds,
    bool? highways,
  }) {
    return MapLayerSettings(
      ev: ev ?? this.ev,
      ztl: ztl ?? this.ztl,
      pois: pois ?? this.pois,
      poiKinds: poiKinds ?? this.poiKinds,
      highways: highways ?? this.highways,
    );
  }

  Map<String, dynamic> toJson() => {
        'ev': ev,
        'ztl': ztl,
        'pois': pois,
        'poiKinds': poiKinds.toList(),
        'highways': highways,
      };

  static MapLayerSettings fromJson(Map<String, dynamic> json) => MapLayerSettings(
        ev: json['ev'] as bool? ?? false,
        ztl: json['ztl'] as bool? ?? false,
        pois: json['pois'] as bool? ?? false,
        poiKinds: ((json['poiKinds'] as List?) ?? const ['car_repair', 'car_wash', 'tyres'])
            .map((e) => e.toString())
            .toSet(),
        highways: json['highways'] as bool? ?? false,
      );
}
