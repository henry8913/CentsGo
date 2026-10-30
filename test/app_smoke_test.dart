import 'package:centsgo/features/garage/garage_tab.dart';
import 'package:centsgo/features/list/list_tab.dart';
import 'package:centsgo/features/search/search_tab.dart';
import 'package:centsgo/features/shell.dart';
import 'package:centsgo/features/trip/trip_tab.dart';
import 'package:centsgo/models/settings.dart';
import 'package:centsgo/state/app_state.dart';
import 'package:centsgo/theme/app_theme.dart';
import 'package:centsgo/widgets/station_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    state = AppState(autoLocate: false, autoSyncEnabled: false);
    await state.init();
    state.updateSettings(state.settings.copyWith(themeMode: AppThemeMode.light, onboarded: true));
  });

  Future<void> pumpAt(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppThemeMode.light, Brightness.light),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('catalogue loads the bundled snapshot', () {
    expect(state.ready, isTrue);
    expect(state.catalog.stations.length, greaterThan(15000));
    expect(state.catalog.places.length, greaterThan(3000));
    expect(state.catalog.highways, isNotEmpty);
  });

  test('nearby query returns stations sorted by price', () {
    final hits = state.nearby(limit: 50);
    expect(hits, isNotEmpty);
    for (var i = 1; i < hits.length; i++) {
      expect(hits[i].price, greaterThanOrEqualTo(hits[i - 1].price));
    }
    final spread = StationSpread.of(hits);
    expect(spread.min, lessThanOrEqualTo(spread.max));
  });

  test('sort mode changes the order of the results', () {
    final priceSorted = state.nearby(limit: 60);
    expect(priceSorted.length, greaterThan(10));
    state.setSort(SortMode.distance);
    final distanceSorted = state.nearby(limit: 60);
    expect(distanceSorted.first.distanceKm, lessThanOrEqualTo(distanceSorted.last.distanceKm));
    // The two orders must differ for at least one position in a dense city.
    final changed = List.generate(60, (i) => priceSorted[i].station.id != distanceSorted[i].station.id)
        .where((e) => e)
        .isNotEmpty;
    expect(changed, isTrue);
    state.setSort(SortMode.best);
    final best = state.nearby(limit: 60);
    expect(best, isNotEmpty);
    state.setSort(SortMode.price);
  });

  test('manual place is applied and persisted', () async {
    final torino = state.catalog.placeByName('Torino');
    expect(torino, isNotNull);
    state.setPlace(torino!);
    expect(state.centerLabel.contains('Torino'), isTrue);
    expect(state.settings.followGps, isFalse);
    expect(state.nearby(limit: 5).isNotEmpty, isTrue);

    // A second AppState reading the same storage must reopen in Torino.
    final restored = AppState(autoLocate: false, autoSyncEnabled: false);
    await restored.init();
    expect(restored.settings.homePlace?.name, 'Torino');
    expect(restored.center.latitude, closeTo(torino.position.latitude, 0.5));
  });

  test('smart fill never suggests a station that costs more after the detour', () {
    final hits = state.nearby(limit: 80);
    final smart = state.smartFill(hits);
    expect(smart, isNotNull);
    if (smart!.worthIt) {
      expect(smart.netSaving, greaterThan(0));
      expect(smart.hit.price, lessThanOrEqualTo(smart.nearest.price));
    }
  });

  test('national stats are computed for the selected fuel', () {
    final stat = state.nationalStats(Fuels.benzina);
    expect(stat, isNotNull);
    expect(stat!.count, greaterThan(10000));
    expect(stat.min, lessThanOrEqualTo(stat.median));
    expect(stat.median, lessThanOrEqualTo(stat.max));
  });

  test('trip corridor finds stations along the way', () {
    final milano = state.catalog.placeByName('Milano');
    final roma = state.catalog.placeByName('Roma');
    expect(milano, isNotNull);
    expect(roma, isNotNull);
    final result = state.planTrip(TripPlan(
      id: 't1',
      origin: milano!,
      destination: roma!,
      createdAt: DateTime.now(),
      corridorKm: 5,
    ));
    expect(result.hits, isNotEmpty);
    expect(result.hits.first.price, lessThanOrEqualTo(result.hits.last.price));
  });

  testWidgets('list tab renders without layout errors', (tester) async {
    await pumpAt(tester, ListTab(state: state));
    expect(find.byType(ListTab), findsOneWidget);
    expect(find.textContaining('PIENO INTELLIGENTE'), findsOneWidget);
    expect(find.byType(StationCard), findsWidgets);
  });

  testWidgets('search tab renders and finds a comune', (tester) async {
    await pumpAt(tester, SearchTab(state: state));
    expect(find.text('Cerca'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Torino');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Torino'), findsWidgets);
  });

  testWidgets('trip tab renders', (tester) async {
    await pumpAt(tester, TripTab(state: state));
    expect(find.text('Viaggio'), findsOneWidget);
    expect(find.text('Cerca lungo il percorso'), findsOneWidget);
  });

  testWidgets('garage tab shows the empty state', (tester) async {
    await pumpAt(tester, GarageTab(state: state));
    expect(find.text('Il tuo garage è vuoto'), findsOneWidget);
  });

  testWidgets('shell switches between the five tabs', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(AppThemeMode.light, Brightness.light),
      home: Shell(state: state),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    for (final label in ['Mappa', 'Cerca', 'Viaggio', 'Garage', 'Lista']) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.byType(Shell), findsOneWidget);
  });
}

/// Widget tests default to a wide monospace test font; load the real fonts so
/// layout and overflow assertions reflect the shipped UI.
Future<void> _loadFonts() async {
  final families = <String, List<String>>{
    'Jakarta': [
      'assets/fonts/PlusJakartaSans-400.ttf',
      'assets/fonts/PlusJakartaSans-500.ttf',
      'assets/fonts/PlusJakartaSans-600.ttf',
      'assets/fonts/PlusJakartaSans-700.ttf',
      'assets/fonts/PlusJakartaSans-800.ttf',
    ],
    'Display': ['assets/fonts/ArchivoBlack-Regular.ttf'],
    'Mono': [
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

/// Local mirror of the spread helper used by the list (kept test-side on
/// purpose so the test does not depend on private UI code).
class StationSpread {
  static ({double min, double median, double max}) of(List<dynamic> hits) {
    final prices = hits.map<double>((h) => h.price as double).toList()..sort();
    return (min: prices.first, median: prices[prices.length ~/ 2], max: prices.last);
  }
}
