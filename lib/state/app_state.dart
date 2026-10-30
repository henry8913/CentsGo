import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../core/geo.dart';
import '../data/catalog.dart';
import '../data/catalog_cache.dart';
import '../data/layers.dart';
import '../data/mimit_source.dart';
import '../data/local_store.dart';
import '../models/settings.dart';
import '../models/station.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import 'location_service.dart';

class PricePoint {
  PricePoint({required this.at, required this.self, required this.servito});

  final DateTime at;
  final double? self;
  final double? servito;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'self': self,
        'servito': servito,
      };

  static PricePoint fromJson(Map<String, dynamic> j) => PricePoint(
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        self: (j['self'] as num?)?.toDouble(),
        servito: (j['servito'] as num?)?.toDouble(),
      );
}

class CountryDayPrice {
  const CountryDayPrice({
    required this.day,
    required this.fuel,
    required this.min,
    required this.median,
    required this.max,
  });

  final DateTime day;
  final String fuel;
  final double min;
  final double median;
  final double max;

  Map<String, dynamic> toJson() => {
        'd': day.toIso8601String(),
        'f': fuel,
        'min': min,
        'med': median,
        'max': max,
      };

  static CountryDayPrice fromJson(Map<String, dynamic> j) => CountryDayPrice(
        day: DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now(),
        fuel: j['f'] as String? ?? '',
        min: (j['min'] as num?)?.toDouble() ?? 0,
        median: (j['med'] as num?)?.toDouble() ?? 0,
        max: (j['max'] as num?)?.toDouble() ?? 0,
      );
}

class PriceAlert {
  const PriceAlert({
    required this.stationId,
    required this.stationName,
    required this.fuel,
    required this.selfService,
    required this.from,
    required this.to,
    required this.at,
  });

  final String stationId;
  final String stationName;
  final String fuel;
  final bool selfService;
  final double from;
  final double to;
  final DateTime at;

  double get delta => to - from;
  bool get isDrop => delta < 0;

  Map<String, dynamic> toJson() => {
        'id': stationId,
        'name': stationName,
        'fuel': fuel,
        'self': selfService,
        'from': from,
        'to': to,
        'at': at.toIso8601String(),
      };

  static PriceAlert fromJson(Map<String, dynamic> j) => PriceAlert(
        stationId: j['id'] as String? ?? '',
        stationName: j['name'] as String? ?? '',
        fuel: j['fuel'] as String? ?? '',
        selfService: j['self'] as bool? ?? true,
        from: (j['from'] as num?)?.toDouble() ?? 0,
        to: (j['to'] as num?)?.toDouble() ?? 0,
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// National min/median/max for one fuel, computed once per data revision.
class NationalStat {
  const NationalStat({required this.fuel, required this.min, required this.median, required this.max, required this.count});
  final String fuel;
  final double min;
  final double median;
  final double max;
  final int count;
}

/// Result of the "smart fill": the station that saves the most once the detour
/// is paid for, compared with the closest station.
class SmartFill {
  const SmartFill({
    required this.hit,
    required this.liters,
    required this.nearest,
    required this.grossSaving,
    required this.detourCost,
    required this.extraKm,
  });

  final StationHit hit;
  final double liters;
  final StationHit nearest;
  final double grossSaving;
  final double detourCost;
  final double extraKm;

  double get netSaving => grossSaving - detourCost;
  bool get worthIt => netSaving > 0.05;
}

/// Single source of truth for the UI: catalogue, settings, garage, favourites
/// and locally recorded price history.
class AppState extends ChangeNotifier {
  AppState({this.autoLocate = true, this.autoSyncEnabled = true});

  final bool autoLocate;
  final bool autoSyncEnabled;

  LocalStore? _store;
  final CatalogCache _cache = CatalogCache();
  StationCatalog? _catalog;
  final MapLayers layers = MapLayers();

  AppSettings settings = const AppSettings();
  bool loading = true;
  String? error;
  String dataVersionLabel = '';

  LatLng _center = const LatLng(45.4642, 9.19); // Milano, Duomo
  LatLng? _gps;
  String _centerLabel = 'Milano (MI)';
  bool _usingGps = false;
  bool _locating = false;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  int _revision = 0;

  // --- live data -----------------------------------------------------------
  /// Prices change once a day, so checking every 20 minutes in the foreground
  /// is plenty and keeps the app effectively always up to date.
  static const syncInterval = Duration(minutes: 30);
  static const _minRetryGap = Duration(minutes: 5);

  bool autoSync = true;
  bool _syncing = false;
  double _syncProgress = 0;
  String? _syncError;
  DateTime? _lastSync;
  DateTime? _lastAttempt;
  Timer? _syncTimer;
  AppLifecycleListener? _lifecycle;

  final Set<String> _favorites = <String>{};
  final List<PriceAlert> _alerts = <PriceAlert>[];

  List<Vehicle> _vehicles = <Vehicle>[];
  List<Refuel> _refuels = <Refuel>[];
  List<TripPlan> _trips = <TripPlan>[];
  String? _activeVehicleId;

  final Map<String, List<PricePoint>> _stationHistory = <String, List<PricePoint>>{};
  final Map<String, List<CountryDayPrice>> _nationalHistory = <String, List<CountryDayPrice>>{};
  final Map<String, double> _lastSeen = <String, double>{};
  final Map<String, NationalStat> _national = <String, NationalStat>{};
  int _nationalRevision = -1;

  StationCatalog get catalog => _catalog!;
  bool get ready => !loading && _catalog != null;
  LatLng get center => _center;

  /// Last GPS fix, when available. The map draws the "you are here" dot only
  /// when this is not null, so it never lies about the user position.
  LatLng? get gpsPosition => _gps;
  bool get hasGps => _gps != null;
  String get centerLabel => _centerLabel;
  bool get usingGps => _usingGps;
  bool get locating => _locating;
  bool get permissionDenied => _permissionDenied;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;

  /// Bumped whenever the underlying data changes so views can invalidate their
  /// cached query results.
  int get revision => _revision;

  bool get syncing => _syncing;
  double get syncProgress => _syncProgress;
  String? get syncError => _syncError;
  DateTime? get lastSync => _lastSync;
  bool get dataIsDownloaded => _catalog?.fromCache ?? false;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<Refuel> get refuels => List.unmodifiable(_refuels);
  List<TripPlan> get trips => List.unmodifiable(_trips);
  Set<String> get favorites => Set.unmodifiable(_favorites);
  List<PriceAlert> get alerts => List.unmodifiable(_alerts);
  List<PriceAlert> get unreadAlerts =>
      _alerts.where((a) => a.at.isAfter(_alertsReadAt)).toList().reversed.toList();
  DateTime _alertsReadAt = DateTime.fromMillisecondsSinceEpoch(0);

  Vehicle? get activeVehicle {
    if (_vehicles.isEmpty) return null;
    final id = _activeVehicleId;
    if (id == null) return _vehicles.first;
    return _vehicles.firstWhere((v) => v.id == id, orElse: () => _vehicles.first);
  }

  List<Refuel> refuelsFor(String vehicleId) =>
      _refuels.where((r) => r.vehicleId == vehicleId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  GarageStats statsFor(String vehicleId) => GarageStats.from(refuelsFor(vehicleId));

  Future<void> init() async {
    try {
      _store = await LocalStore.open();
      _restore(_store!.read());
      _catalog = await StationCatalog.load(cache: _cache);
      _lastSync ??= await _cache.lastModified();
      dataVersionLabel = 'Dati ${catalog.extractionDate} · ${Fmt.count(catalog.stations.length)} impianti';
      if (settings.themeMode == AppThemeMode.system) {
        // nothing: theme resolves through MaterialApp
      }
      final home = settings.homePlace;
      if (home != null) {
        _center = home.position;
        _centerLabel = home.label;
      } else {
        final p = catalog.placeByName(settings.homeCity);
        if (p != null) {
          _center = p.position;
          _centerLabel = p.label;
        }
      }
      loading = false;
      notifyListeners();
      // Let the first frame (and the native splash hand-over) finish before the
      // heavier background work starts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (settings.followGps) unawaited(_bootstrapLocation());
        unawaited(refreshPrices());
        _startAutoSync();
      });
      if (settings.layers.ev || settings.layers.ztl || settings.layers.pois) {
        unawaited(warmLayers());
      }
    } catch (e, st) {
      error = '$e';
      loading = false;
      notifyListeners();
      debugPrint('CentsGo init failed: $e\n$st');
    }
  }

  Future<void> _bootstrapLocation() async {
    // Never ask for the location permission while the user is still reading the
    // onboarding: the system dialog would cover the welcome screen.
    if (!autoLocate || !settings.onboarded || !settings.followGps) return;
    await detectLocation(force: false);
  }

  /// Explicit area chosen by the user (search bar, settings, map picker).
  /// It is persisted so the app reopens where the user left it.
  void setPlace(Place place) {
    _center = place.position;
    _centerLabel = place.label;
    _usingGps = false;
    settings = settings.copyWith(homePlace: place, homeCity: place.name, followGps: false);
    _revision++;
    notifyListeners();
    _save();
  }

  Future<void> useGps() async {
    settings = settings.copyWith(followGps: true);
    notifyListeners();
    await detectLocation(force: true);
  }

  Future<void> warmLayers() async {
    try {
      if (settings.layers.ev) await layers.ensureEv();
      if (settings.layers.ztl) await layers.ensureZtl();
      if (settings.layers.pois) {
        await layers.ensureEvTariffs();
        await layers.ensurePois();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('layer load failed: $e');
    }
  }

  Future<bool> detectLocation({bool force = false}) async {
    if (_locating) return false;
    _locating = true;
    notifyListeners();
    try {
      final fix = await LocationService.currentPosition();
      if (fix != null) {
        _gps = fix;
        _center = fix;
        _usingGps = true;
        _permissionDenied = false;
        _permissionPermanentlyDenied = false;
        settings = settings.copyWith(followGps: true);
        final city = _catalog?.nearestPlace(fix, maxKm: 30);
        _centerLabel = city != null && Geo.distanceKm(city.position, fix) < 12
            ? 'Vicino a ${city.label}'
            : 'Posizione attuale';
        _revision++;
        _locating = false;
        notifyListeners();
        await _save();
        return true;
      }
      _permissionDenied = true;
      _permissionPermanentlyDenied = await LocationService.isPermanentlyDenied();
      _usingGps = false;
      _locating = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('location failed: $e');
      _permissionDenied = true;
      _usingGps = false;
      _locating = false;
      notifyListeners();
      return false;
    }
  }

  void setCenter(LatLng point, {String? label}) {
    _center = point;
    _usingGps = false;
    _centerLabel = label ?? (_catalog?.nearestPlace(point)?.label ?? 'Posizione scelta');
    _revision++;
    notifyListeners();
  }

  void setHomePlace(Place place) => setPlace(place);

  void updateSettings(AppSettings next, {bool persist = true}) {
    settings = next;
    notifyListeners();
    if (persist) _save();
  }

  void setFuel(String fuel) => updateSettings(settings.copyWith(fuel: fuel));
  void setSelfService(bool value) => updateSettings(settings.copyWith(selfService: value));
  void setSort(SortMode sort) => updateSettings(settings.copyWith(sort: sort));
  void setBrand(String? brand) => updateSettings(
        brand == null ? settings.copyWith(clearBrand: true) : settings.copyWith(brand: brand),
      );
  void setRadius(double km) => updateSettings(settings.copyWith(radiusKm: km));
  void setThemeMode(AppThemeMode mode) => updateSettings(settings.copyWith(themeMode: mode));
  void completeOnboarding() {
    updateSettings(settings.copyWith(onboarded: true));
    unawaited(detectLocation());
  }

  void setAutoSync(bool value) {
    autoSync = value;
    notifyListeners();
    _save();
    if (value) unawaited(syncPrices());
  }

  void setLayers(MapLayerSettings next) {
    updateSettings(settings.copyWith(layers: next));
    unawaited(warmLayers());
  }

  Future<void> toggleFavorite(Station station) async {
    if (!_favorites.remove(station.id)) {
      _favorites.add(station.id);
      _recordStationPrice(station);
    }
    notifyListeners();
    await _save();
  }

  bool isFavorite(String stationId) => _favorites.contains(stationId);

  Station? stationById(String id) {
    for (final s in _catalog?.stations ?? const <Station>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// National min / median / max for [fuel], memoised per data revision.
  NationalStat? nationalStats(String fuel, {bool self = true}) {
    if (_nationalRevision != _revision) {
      _national.clear();
      _nationalRevision = _revision;
    }
    final cached = _national[fuel];
    if (cached != null) return cached;
    final prices = <double>[];
    for (final s in _catalog?.stations ?? const <Station>[]) {
      final p = s.priceFor(fuel, self: self);
      if (p != null && FuelSanity.plausible(fuel, p)) prices.add(p);
    }
    if (prices.isEmpty) return null;
    prices.sort();
    final stat = NationalStat(
      fuel: fuel,
      min: prices.first,
      median: prices[prices.length ~/ 2],
      max: prices.last,
      count: prices.length,
    );
    _national[fuel] = stat;
    return stat;
  }

  /// Picks the station with the best net saving on a full tank, paying for the
  /// extra kilometres compared with the closest station.
  SmartFill? smartFill(List<StationHit> hits) {
    if (hits.length < 2) return null;
    final vehicle = activeVehicle;
    final liters = vehicle?.tankLiters ?? 50.0;
    final consumption = vehicle?.consumption ?? 6.0; // L/100 km
    final nearest = hits.reduce((a, b) => a.distanceKm <= b.distanceKm ? a : b);
    SmartFill? best;
    for (final hit in hits) {
      final extraKm = (hit.distanceKm - nearest.distanceKm).clamp(0.0, double.infinity) * 2;
      final detourCost = extraKm * (consumption / 100) * hit.price;
      final gross = (nearest.price - hit.price) * liters;
      final candidate = SmartFill(
        hit: hit,
        liters: liters,
        nearest: nearest,
        grossSaving: gross,
        detourCost: detourCost,
        extraKm: extraKm,
      );
      if (best == null || candidate.netSaving > best.netSaving) best = candidate;
    }
    return best;
  }

  List<StationHit> nearby({double? radiusKm, String? brand, int limit = 250}) {
    final cat = _catalog;
    if (cat == null) return const [];
    return cat.nearby(
      center: _center,
      fuel: settings.fuel,
      self: settings.selfService,
      sort: settings.sort,
      radiusKm: radiusKm ?? settings.radiusKm,
      brand: brand,
      limit: limit,
    );
  }

  /// Cheapest price around the current centre for an arbitrary fuel, used by the
  /// Garage to estimate the cost of a fill.
  double? benchmark(String fuel, {bool self = true}) =>
      _catalog?.benchmarkPrice(_center, fuel, self: self);

  TripResult planTrip(TripPlan trip) {
    final cat = _catalog;
    final path = Geo.interpolate(trip.origin.position, trip.destination.position, steps: 64);
    final hits = cat == null
        ? const <StationHit>[]
        : cat.alongPath(
            path: path,
            fuel: settings.fuel,
            self: settings.selfService,
            sort: settings.sort,
            corridorKm: trip.corridorKm,
          );
    return TripResult(
      trip: trip,
      path: path,
      hits: hits,
      fuel: settings.fuel,
      selfService: settings.selfService,
    );
  }

  Future<void> rememberTrip(TripPlan trip) async {
    _trips.removeWhere((t) => t.origin.name == trip.origin.name && t.destination.name == trip.destination.name);
    _trips.insert(0, trip);
    if (_trips.length > 8) _trips.removeRange(8, _trips.length);
    notifyListeners();
    await _save();
  }

  Future<void> removeTrip(String id) async {
    _trips.removeWhere((t) => t.id == id);
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------- Garage ---

  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);
    _activeVehicleId ??= vehicle.id;
    notifyListeners();
    await _save();
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final i = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (i == -1) return;
    _vehicles[i] = vehicle;
    notifyListeners();
    await _save();
  }

  Future<void> removeVehicle(String id) async {
    _vehicles.removeWhere((v) => v.id == id);
    _refuels.removeWhere((r) => r.vehicleId == id);
    if (_activeVehicleId == id) _activeVehicleId = _vehicles.isEmpty ? null : _vehicles.first.id;
    notifyListeners();
    await _save();
  }

  Future<void> setActiveVehicle(String id) async {
    _activeVehicleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> addRefuel(Refuel refuel) async {
    _refuels.add(refuel);
    notifyListeners();
    await _save();
  }

  Future<void> removeRefuel(String id) async {
    _refuels.removeWhere((r) => r.id == id);
    notifyListeners();
    await _save();
  }

  // --------------------------------------------------------------- History ---

  void _recordStationPrice(Station station) {
    final list = _stationHistory.putIfAbsent(station.id, () => <PricePoint>[]);
    final last = list.isEmpty ? null : list.last;
    final now = DateTime.now();
    final self = station.selfPrice(settings.fuel);
    final servito = station.servitoPrice(settings.fuel);
    if (last != null && last.self == self && last.servito == servito && now.difference(last.at).inHours < 12) {
      return;
    }
    list.add(PricePoint(at: now, self: self, servito: servito));
    if (list.length > 120) list.removeAt(0);
  }

  List<PricePoint> historyFor(String stationId) => _stationHistory[stationId] ?? const [];

  List<CountryDayPrice> nationalHistory(String fuel) {
    final list = _nationalHistory[fuel];
    if (list == null) return const [];
    return [...list]..sort((a, b) => a.day.compareTo(b.day));
  }

  /// Records today's national min/median/max for every fuel and compares the
  /// favourite stations with the last observed price, producing the alerts.
  Future<void> refreshPrices() async {
    final cat = _catalog;
    if (cat == null) return;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final generated = <PriceAlert>[];

    for (final fuel in Fuels.all) {
      final prices = <double>[];
      for (final s in cat.stations) {
        final p = s.priceFor(fuel, self: true);
        if (p != null) prices.add(p);
      }
      if (prices.isEmpty) continue;
      prices.sort();
      final list = _nationalHistory.putIfAbsent(fuel, () => <CountryDayPrice>[]);
      final entry = CountryDayPrice(
        day: day,
        fuel: fuel,
        min: prices.first,
        median: prices[prices.length ~/ 2],
        max: prices.last,
      );
      final idx = list.indexWhere((e) => e.day == day);
      if (idx >= 0) {
        list[idx] = entry;
      } else {
        list.add(entry);
      }
      if (list.length > 120) list.removeAt(0);
    }

    for (final id in _favorites) {
      final station = stationById(id);
      if (station == null) continue;
      final price = station.priceFor(settings.fuel, self: settings.selfService);
      if (price == null) continue;
      final key = '$id|${settings.fuel}|${settings.selfService}';
      final previous = _lastSeen[key];
      if (previous != null && (previous - price).abs() >= 0.0005) {
        generated.add(PriceAlert(
          stationId: id,
          stationName: station.displayName,
          fuel: settings.fuel,
          selfService: settings.selfService,
          from: previous,
          to: price,
          at: DateTime.now(),
        ));
      }
      _lastSeen[key] = price;
      _recordStationPrice(station);
    }

    if (generated.isNotEmpty) {
      _alerts.insertAll(0, generated);
      if (_alerts.length > 60) _alerts.removeRange(60, _alerts.length);
    }
    _revision++;
    notifyListeners();
    await _save();
  }

  Future<void> markAlertsRead() async {
    _alertsReadAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> clearAlerts() async {
    _alerts.clear();
    _alertsReadAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> resetAll() async {
    await _store?.clear();
    await _cache.clear();
    settings = const AppSettings();
    _favorites.clear();
    _alerts.clear();
    _vehicles = <Vehicle>[];
    _refuels = <Refuel>[];
    _trips = <TripPlan>[];
    _activeVehicleId = null;
    _stationHistory.clear();
    _nationalHistory.clear();
    _lastSeen.clear();
    notifyListeners();
    await _save();
  }

  // ------------------------------------------------------------- Live data ---

  void _startAutoSync() {
    if (!autoSyncEnabled) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (autoSync) unawaited(syncPrices());
    });
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        if (autoSync) unawaited(syncPrices());
      },
    );
    if (autoSync) {
      unawaited(syncPrices());
    }
  }

  /// Downloads the official open data (about 8 MB) and swaps the catalogue in
  /// place. Safe to call often: it no-ops when data is fresh or a download is
  /// already running.
  Future<void> syncPrices({bool force = false}) async {
    if (!autoSync && !force) return;
    if (_syncing) return;
    final now = DateTime.now();
    if (!force) {
      if (_lastSync != null && now.difference(_lastSync!) < syncInterval) return;
      if (_lastAttempt != null && now.difference(_lastAttempt!) < _minRetryGap) return;
    }
    _syncing = true;
    _syncError = null;
    _syncProgress = 0;
    notifyListeners();
    _lastAttempt = now;
    final source = MimitSource();
    try {
      // The files change once a day: ask the server whether ours is stale
      // before downloading ~8 MB.
      if (!force && _lastSync != null) {
        final remote = await source.remoteLastModified();
        if (remote != null && !remote.isAfter(_lastSync!)) {
          _lastSync = DateTime.now();
          _syncing = false;
          notifyListeners();
          return;
        }
      }
      final raw = await source.download(onProgress: (p) {
        _syncProgress = p;
        notifyListeners();
      });
      // CSV parsing touches ~8 MB: keep it off the UI isolate.
      final result = await compute(MimitSource.parsePair, raw);
      await _cache.write(result.json);
      final fresh = await StationCatalog.load(cache: _cache);
      _catalog = fresh;
      _national.clear();
      _nationalRevision = -1;
      _lastSync = DateTime.now();
      _revision++;
      _syncProgress = 1;
      notifyListeners();
      await _save();
    } catch (e) {
      _syncError = _describeSyncError(e);
      notifyListeners();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  static String _describeSyncError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Nessuna connessione: i prezzi restano quelli dell\'ultimo aggiornamento.';
    }
    if (text.contains('TimeoutException') || text.contains('timed out')) {
      return 'Il server MIMIT non risponde: riproverò tra poco.';
    }
    return 'Aggiornamento non riuscito: $text';
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- Persistence --

  void _restore(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    try {
      if (data['settings'] is Map) {
        settings = AppSettings.fromJson((data['settings'] as Map).cast<String, dynamic>());
      }
      _favorites.addAll(((data['favorites'] as List?) ?? const []).map((e) => e.toString()));
      _vehicles = ((data['vehicles'] as List?) ?? const [])
          .map((e) => Vehicle.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _refuels = ((data['refuels'] as List?) ?? const [])
          .map((e) => Refuel.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _trips = ((data['trips'] as List?) ?? const [])
          .map((e) => TripPlan.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _activeVehicleId = data['activeVehicleId'] as String?;
      final hist = (data['stationHistory'] as Map?) ?? const {};
      hist.forEach((k, v) {
        _stationHistory[k.toString()] =
            (v as List).map((e) => PricePoint.fromJson((e as Map).cast<String, dynamic>())).toList();
      });
      final nat = (data['nationalHistory'] as Map?) ?? const {};
      nat.forEach((k, v) {
        _nationalHistory[k.toString()] =
            (v as List).map((e) => CountryDayPrice.fromJson((e as Map).cast<String, dynamic>())).toList();
      });
      final seen = (data['lastSeen'] as Map?) ?? const {};
      seen.forEach((k, v) => _lastSeen[k.toString()] = (v as num).toDouble());
      _alerts.addAll(((data['alerts'] as List?) ?? const [])
          .map((e) => PriceAlert.fromJson((e as Map).cast<String, dynamic>())));
      final readAt = data['alertsReadAt'] as String?;
      if (readAt != null) _alertsReadAt = DateTime.tryParse(readAt) ?? _alertsReadAt;
      final syncedAt = data['lastSync'] as String?;
      if (syncedAt != null) _lastSync = DateTime.tryParse(syncedAt);
      autoSync = data['autoSync'] as bool? ?? true;
    } catch (e) {
      debugPrint('restore failed: $e');
    }
  }

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    await store.write({
      'settings': settings.toJson(),
      'favorites': _favorites.toList(),
      'vehicles': _vehicles.map((v) => v.toJson()).toList(),
      'refuels': _refuels.map((r) => r.toJson()).toList(),
      'trips': _trips.map((t) => t.toJson()).toList(),
      'activeVehicleId': _activeVehicleId,
      'stationHistory': _stationHistory.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      'nationalHistory': _nationalHistory.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      'lastSeen': _lastSeen,
      'alerts': _alerts.map((a) => a.toJson()).toList(),
      'alertsReadAt': _alertsReadAt.toIso8601String(),
      'lastSync': _lastSync?.toIso8601String(),
      'autoSync': autoSync,
    });
  }
}
