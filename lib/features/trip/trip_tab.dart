import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/fuel_units.dart';
import '../../core/geo.dart';
import '../../core/trip/trip_cost.dart';
import '../../core/units.dart';
import '../../models/address.dart';
import '../../models/settings.dart';
import '../../models/trip_record.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';
import '../common/address_sheet.dart';

class TripTab extends StatefulWidget {
  const TripTab({super.key, required this.state});

  final AppState state;

  @override
  State<TripTab> createState() => _TripTabState();
}

class _TripTabState extends State<TripTab> {
  Address? _origin;
  Address? _destination;
  int _occupants = 1;
  TripCostResult? _result;
  RefuelSuggestion? _refuel;
  bool _loading = false;
  bool _offline = false;
  String? _error;
  final _parking = TextEditingController(text: '0');
  final _price = TextEditingController();
  final _consumption = TextEditingController();
  bool _priceTouched = false;
  bool _consumptionTouched = false;
  RoutePlan? _highway;
  RoutePlan? _free;
  String? _priceStationName;
  bool _priceIsEstimate = false;
  String _lastFuel = '';
  late ConsumptionUnit _consumptionUnit = state.activeVehicle?.consumptionUnit ?? state.settings.consumptionUnit;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _occupants = state.settings.householdSize;
    _origin = state.settings.homeAddress;
    _destination = state.settings.workAddress;
    _lastFuel = state.settings.fuel;
    final vehicle = state.activeVehicle;
    _writeConsumption(vehicle == null ? 6.0 : (_consumptionFor(vehicle) ?? 6.0));
    final price = state.benchmark(state.settings.fuel, self: state.settings.selfService);
    if (price != null) _price.text = price.toStringAsFixed(3).replaceAll('.', ',');
  }

  double? _consumptionFor(vehicle) {
    if (vehicle == null) return null;
    final stats = state.statsFor(vehicle.id);
    return stats.measuredConsumption ?? vehicle.consumption;
  }

  double get _priceValue => double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;

  /// Value as typed, in the unit currently shown.
  double get _consumptionTyped => double.tryParse(_consumption.text.replaceAll(',', '.')) ?? 0;

  /// Canonical litres (or kg/kWh) per 100 km, used by the engine.
  double get _consumptionPer100 => Consumption.fromValue(_consumptionTyped, _consumptionUnit).per100;

  void _writeConsumption(double per100) {
    _consumption.text = per100 <= 0 ? '' : Consumption.per100km(per100).valueIn(_consumptionUnit).toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  void dispose() {
    _parking.dispose();
    _price.dispose();
    _consumption.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool origin}) async {
    final picked = await editAddress(
      context,
      state: state,
      title: origin ? 'Partenza' : 'Arrivo',
      initial: origin ? _origin : _destination,
    );
    if (picked == null) return;
    setState(() {
      if (origin) {
        _origin = picked;
      } else {
        _destination = picked;
      }
      _result = null;
    });
  }

  /// Uses the stored coordinates, then the geocoder, then the city centroid.
  Future<Address?> _resolve(Address? address) async {
    if (address == null) return null;
    if (address.hasCoordinates) return address;
    final results = await state.geocoder.search(address, limit: 1);
    if (results.isNotEmpty) return results.first.address;
    final place = state.catalog.placeByName(address.city);
    if (place == null) return null;
    return address.copyWith(lat: place.position.latitude, lon: place.position.longitude);
  }

  Future<void> _calculate() async {
    final from = await _resolve(_origin);
    final to = await _resolve(_destination);
    if (from == null || to == null || !from.hasCoordinates || !to.hasCoordinates) {
      setState(() => _error = 'Scegli partenza e arrivo con una città valida.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });

    final vehicle = state.activeVehicle;
    RoutePlan? highway;
    RoutePlan? free;
    try {
      final routes = await Future.wait([
        state.router.route(LatLng(from.lat!, from.lon!), LatLng(to.lat!, to.lon!)),
        state.router.route(
          LatLng(from.lat!, from.lon!),
          LatLng(to.lat!, to.lon!),
          avoidMotorways: true,
        ),
      ]);
      highway = routes[0];
      free = routes[1];
    } catch (_) {
      highway = null;
    }

    if (highway == null) {
      _offline = true;
      final path = Geo.interpolate(LatLng(from.lat!, from.lon!), LatLng(to.lat!, to.lon!), steps: 64);
      final km = Geo.distanceKm(path.first, path.last) * 1.25;
      highway = RoutePlan(
        points: path,
        km: km,
        minutes: km / 70 * 60,
        steps: const [],
        provider: 'Corridoio in linea d\'aria (offline)',
      );
    }

    final hits = state.catalog.alongPath(
      path: highway.points,
      fuel: state.settings.fuel,
      self: state.settings.selfService,
      sort: SortMode.price,
      corridorKm: 8,
      limit: 60,
    );
    final priceHit = hits.isEmpty ? null : hits.first;

    // Prefill only what the user has not typed: the values stay editable.
    if (!_priceTouched) {
      final price = priceHit?.price ?? state.benchmark(state.settings.fuel, self: state.settings.selfService);
      if (price != null) _price.text = price.toStringAsFixed(3).replaceAll('.', ',');
    }
    if (!_consumptionTouched) {
      _writeConsumption(_consumptionFor(vehicle) ?? 6.0);
    }

    _highway = highway;
    _free = free;
    _priceStationName = _priceTouched ? null : priceHit?.station.brand;
    _priceIsEstimate = priceHit == null;

    setState(() {
      _refuel = state.suggestRefuel(highway!.points);
      _radioRecompute();
    });
  }

  /// Recomputes the cost from the current route and the fields, without
  /// repeating routing. Called on every price/consumption edit.
  void _radioRecompute() {
    final route = _highway;
    if (route == null) return;
    final price = _priceValue;
    final consumption = _consumptionPer100;
    if (price <= 0 || consumption <= 0) {
      _result = null;
      return;
    }
    final parking = double.tryParse(_parking.text.replaceAll(',', '.')) ?? 0;
    _result = computeTripCost(
      route: route,
      freeRoute: _free,
      tollEngine: state.tolls,
      consumptionPer100: consumption,
      pricePerLiter: price,
      occupants: _occupants,
      parking: Money(parking),
      priceStationName: _priceStationName,
      priceIsEstimate: _priceIsEstimate,
    );
  }

  /// Fills the price with the cheapest station found along the route.
  void _useCheapestAlongRoute() {
    final route = _highway;
    if (route == null) return;
    final hits = state.catalog.alongPath(
      path: route.points,
      fuel: state.settings.fuel,
      self: state.settings.selfService,
      sort: SortMode.price,
      corridorKm: 8,
      limit: 1,
    );
    if (hits.isEmpty) return;
    setState(() {
      _price.text = hits.first.price.toStringAsFixed(3).replaceAll('.', ',');
      _priceTouched = false;
      _priceStationName = hits.first.station.brand;
      _priceIsEstimate = false;
      _radioRecompute();
    });
  }

  String _summary(TripCostResult cost) {
    final buffer = StringBuffer()
      ..writeln('CentsGo · ${_origin?.shortLabel} → ${_destination?.shortLabel}')
      ..writeln('${cost.route.distance.format()} · ${_duration(cost.route.minutes)}')
      ..writeln('Carburante ${cost.fuelCost.format()} (${cost.fuelLiters.toStringAsFixed(1)} L a ${Fmt.price(cost.pricePerLiter)})');
    if (cost.hasToll) {
      buffer.writeln('Pedaggio ${cost.toll.total.format()} ${cost.toll.verified ? '' : '(stima)'}');
    }
    if (!cost.parking.isZero) buffer.writeln('Parcheggio ${cost.parking.format()}');
    buffer
      ..writeln('Totale ${cost.total.format()} · ${cost.occupants} persone → ${cost.perPerson.format()} a testa');
    return buffer.toString();
  }

  Future<void> _save(TripCostResult cost) async {
    final origin = _origin!;
    final destination = _destination!;
    await state.saveTripRecord(TripRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      origin: Address.fromJson(origin.toJson()),
      destination: Address.fromJson(destination.toJson()),
      km: cost.route.km,
      minutes: cost.route.minutes,
      fuel: cost.fuelCost.euro,
      toll: cost.toll.total.euro,
      parking: cost.parking.euro,
      total: cost.total.euro,
      occupants: cost.occupants,
      tollVerified: cost.toll.verified,
      fuelLiters: cost.fuelLiters,
      pricePerLiter: cost.pricePerLiter,
      provider: cost.route.provider,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaggio salvato nello storico')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_lastFuel != state.settings.fuel) {
      _lastFuel = state.settings.fuel;
      _priceTouched = false;
      _consumptionTouched = false;
      _highway = null;
      _free = null;
      _result = null;
      final price = state.benchmark(state.settings.fuel, self: state.settings.selfService);
      _price.text = price == null ? '' : price.toStringAsFixed(3).replaceAll('.', ',');
      final vehicle = state.activeVehicle;
      _writeConsumption(_consumptionFor(vehicle) ?? 6.0);
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          const ScreenTitle(title: 'Percorso', subtitle: 'Costi reali di viaggio, calcolati sul telefono'),
          const SizedBox(height: 14),
          _AddressCard(
            icon: Icons.radio_button_checked,
            color: p.good,
            label: 'Partenza',
            address: _origin,
            onTap: () => _pick(origin: true),
            shortcuts: [
              if (state.settings.homeAddress != null)
                _Shortcut(label: 'Casa', onTap: () => setState(() => _origin = state.settings.homeAddress)),
              if (state.settings.workAddress != null)
                _Shortcut(label: 'Lavoro', onTap: () => setState(() => _origin = state.settings.workAddress)),
            ],
          ),
          const SizedBox(height: 8),
          _AddressCard(
            icon: Icons.place,
            color: p.bad,
            label: 'Arrivo',
            address: _destination,
            onTap: () => _pick(origin: false),
            shortcuts: [
              if (state.settings.homeAddress != null)
                _Shortcut(label: 'Casa', onTap: () => setState(() => _destination = state.settings.homeAddress)),
              if (state.settings.workAddress != null)
                _Shortcut(label: 'Lavoro', onTap: () => setState(() => _destination = state.settings.workAddress)),
            ],
          ),
          const SizedBox(height: 10),
          _OptionsRow(
            occupants: _occupants,
            onOccupants: (v) => setState(() => _occupants = v),
            parking: _parking,
          ),
          const SizedBox(height: 10),
          FuelBar(state: state, compact: true),
          const SizedBox(height: 10),
          _FuelInputs(
            fuel: state.settings.fuel,
            unit: FuelUnits.volume(state.settings.fuel),
            per100: _consumptionUnit == ConsumptionUnit.litersPer100km,
            consumptionUnit: FuelUnits.consumption(
              state.settings.fuel,
              per100: _consumptionUnit == ConsumptionUnit.litersPer100km,
            ),
            onToggleUnit: () => setState(() {
              final per100 = _consumptionPer100;
              _consumptionUnit = _consumptionUnit == ConsumptionUnit.litersPer100km
                  ? ConsumptionUnit.kmPerLiter
                  : ConsumptionUnit.litersPer100km;
              _writeConsumption(per100);
              _radioRecompute();
            }),
            price: _price,
            consumption: _consumption,
            stationName: _priceStationName,
            priceTouched: _priceTouched,
            vehicleName: state.activeVehicle?.displayName,
            onPriceChanged: () {
              _priceTouched = true;
              _priceStationName = null;
              setState(_radioRecompute);
            },
            onConsumptionChanged: () {
              _consumptionTouched = true;
              setState(_radioRecompute);
            },
            onUseVehicleConsumption: () {
              final vehicle = state.activeVehicle;
              final value = _consumptionFor(vehicle);
              if (value == null) return;
              setState(() {
                _writeConsumption(value);
                _consumptionTouched = false;
                _radioRecompute();
              });
            },
            onUseCheapest: _highway == null ? null : _useCheapestAlongRoute,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _calculate,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.route, size: 19),
            label: Text(_loading ? 'Calcolo…' : 'Calcola percorso e costi'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoBanner(text: _error!, color: p.bad, icon: Icons.error_outline),
          ],
          if (_offline) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              text: 'Routing non disponibile: distanza stimata in linea d\'aria (+25%). Riprova online per pedaggi e tempi reali.',
              icon: Icons.wifi_off,
              color: Colors.orange,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultView(
              cost: _result!,
              refuel: _refuel,
              hourlyValue: state.settings.hourlyValue,
              onSave: () => _save(_result!),
              onShare: () => _share(_result!),
              onCopy: () => _copy(_result!),
            ),
          ],
          if (state.tripRecords.isNotEmpty) ...[
            const SectionTitle('Viaggi salvati'),
            for (final record in state.tripRecords.take(6))
              _RecordTile(
                record: record,
                onDelete: () => state.removeTripRecord(record.id),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(TripCostResult cost) async {
    await Clipboard.setData(ClipboardData(text: _summary(cost)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riepilogo copiato')));
  }

  Future<void> _share(TripCostResult cost) async {
    final text = Uri.encodeComponent(_summary(cost));
    final whatsapp = Uri.parse('https://wa.me/?text=$text');
    if (!await launchUrl(whatsapp, mode: LaunchMode.externalApplication)) {
      await _copy(cost);
    }
  }

  static String _duration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }
}

class _FuelInputs extends StatelessWidget {
  const _FuelInputs({
    required this.fuel,
    required this.unit,
    required this.per100,
    required this.consumptionUnit,
    required this.onToggleUnit,
    required this.price,
    required this.consumption,
    required this.stationName,
    required this.priceTouched,
    required this.vehicleName,
    required this.onPriceChanged,
    required this.onConsumptionChanged,
    required this.onUseVehicleConsumption,
    this.onUseCheapest,
  });

  final String fuel;
  final String unit;
  final bool per100;
  final String consumptionUnit;
  final VoidCallback onToggleUnit;
  final TextEditingController price;
  final TextEditingController consumption;
  final String? stationName;
  final bool priceTouched;
  final String? vehicleName;
  final VoidCallback onPriceChanged;
  final VoidCallback onConsumptionChanged;
  final VoidCallback onUseVehicleConsumption;
  final VoidCallback? onUseCheapest;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: p.brand),
              const SizedBox(width: 6),
              Text('Come calcolo il carburante', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink)),
              const Spacer(),
              if (vehicleName != null)
                Flexible(
                  child: Text(
                    vehicleName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onPriceChanged(),
                  style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Prezzo',
                    suffixText: '€/$unit',
                    isDense: true,
                    helperText: priceTouched
                        ? 'inserito da te'
                        : stationName != null
                            ? 'MIMIT · $stationName'
                            : 'prezzo di zona',
                    helperStyle: TextStyle(fontSize: 9.5, color: priceTouched ? p.warn : p.muted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: consumption,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onConsumptionChanged(),
                  style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Consumo',
                    suffixText: consumptionUnit,
                    isDense: true,
                    helperText: vehicleName == null ? 'nessun veicolo: 6,0 indicativo' : 'dal Garage, modificabile',
                    helperStyle: TextStyle(fontSize: 9.5, color: p.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Unità', style: TextStyle(fontSize: 10.5, color: p.muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              for (final value in ConsumptionUnit.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PillChip(
                    label: FuelUnits.consumption(fuel, per100: value == ConsumptionUnit.litersPer100km),
                    selected: per100 == (value == ConsumptionUnit.litersPer100km),
                    dense: true,
                    onTap: () {
                      if (per100 == (value == ConsumptionUnit.litersPer100km)) return;
                      onToggleUnit();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Costo = km × consumo ÷ 100 × prezzo. Il prezzo parte dal distributore più conveniente '
              'lungo la rotta: sovrascrivilo con quello che hai pagato e il totale si aggiorna.',
              style: TextStyle(fontSize: 10, height: 1.45, color: p.muted),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (onUseCheapest != null)
                TextButton(
                  onPressed: onUseCheapest,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Prezzo più basso sul percorso', style: TextStyle(fontSize: 11)),
                ),
              const Spacer(),
              TextButton(
                onPressed: onUseVehicleConsumption,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Consumo del veicolo', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
    required this.onTap,
    this.shortcuts = const [],
  });

  final IconData icon;
  final Color color;
  final String label;
  final Address? address;
  final VoidCallback onTap;
  final List<_Shortcut> shortcuts;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 10.5, color: p.muted, fontWeight: FontWeight.w600)),
                    Text(
                      address?.oneLine.isNotEmpty == true ? address!.oneLine : 'Tocca per scegliere',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: address == null ? p.muted : p.ink,
                      ),
                    ),
                  ],
                ),
              ),
              for (final shortcut in shortcuts) ...[
                const SizedBox(width: 6),
                ShortcutChip(label: shortcut.label, onTap: shortcut.onTap),
              ],
              Icon(Icons.chevron_right, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class ShortcutChip extends StatelessWidget {
  const ShortcutChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.brand)),
      ),
    );
  }
}

class _OptionsRow extends StatelessWidget {
  const _OptionsRow({required this.occupants, required this.onOccupants, required this.parking});

  final int occupants;
  final ValueChanged<int> onOccupants;
  final TextEditingController parking;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(Icons.group_outlined, size: 17, color: p.brand),
                const SizedBox(width: 6),
                Text('Persone', style: TextStyle(fontSize: 12, color: p.muted)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 17),
                  onPressed: occupants <= 1 ? null : () => onOccupants(occupants - 1),
                ),
                Text('$occupants', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 17),
                  onPressed: occupants >= 7 ? null : () => onOccupants(occupants + 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: parking,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Sosta', suffixText: '€', isDense: true),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.cost,
    required this.refuel,
    required this.hourlyValue,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
  });

  final TripCostResult cost;
  final RefuelSuggestion? refuel;
  final double hourlyValue;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final free = cost.freeRoute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(height: 210, child: _RouteMap(points: cost.route.points, from: cost.route.points.first, to: cost.route.points.last)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.brand, Color.lerp(p.brand, p.bad, 0.2)!]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    cost.route.distance.format(),
                    style: PriceType.style(p, size: 26, color: p.brandOn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _duration(cost.route.minutes),
                    style: TextStyle(fontSize: 13, color: p.brandOn.withValues(alpha: 0.9)),
                  ),
                  const Spacer(),
                  Text(
                    '${cost.total.format()}',
                    style: PriceType.style(p, size: 24, color: p.brandOn),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${cost.perPerson.format()} a testa · ${cost.occupants} persone',
                style: TextStyle(fontSize: 12, color: p.brandOn.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Breakdown(cost: cost),
        if (free != null) ...[
          const SizedBox(height: 12),
          _Comparison(cost: cost, free: free, hourlyValue: hourlyValue),
        ],
        if (refuel != null) ...[
          const SizedBox(height: 12),
          _RefuelCard(refuel: refuel!),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.bookmark_add_outlined, size: 18), label: const Text('Salva'))),
            const SizedBox(width: 8),
            RoundIconButton(icon: Icons.share_outlined, tooltip: 'Condividi', size: 50, onTap: onShare),
            const SizedBox(width: 8),
            RoundIconButton(icon: Icons.copy_all_outlined, tooltip: 'Copia', size: 50, onTap: onCopy),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Routing ${cost.route.provider}. Pedaggi ${cost.toll.verified ? 'verificati' : 'stimati'} '
          '(${cost.toll.source}). Fonti: MIMIT, OpenStreetMap, ART/MIT.',
          style: TextStyle(fontSize: 10.5, height: 1.4, color: p.muted),
        ),
      ],
    );
  }

  static String _duration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.cost});

  final TripCostResult cost;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          _row(p, Icons.local_gas_station_outlined, 'Carburante',
              '${cost.route.km.toStringAsFixed(0)} km × ${cost.consumptionPer100.toStringAsFixed(1).replaceAll('.', ',')} '
              '/100 = ${cost.fuelLiters.toStringAsFixed(1)} · ${Fmt.price(cost.pricePerLiter)}',
              cost.fuelCost.format()),
          if (cost.priceStationName != null)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('prezzo ${cost.priceStationName}${cost.priceIsEstimate ? ' (stima)' : ''}',
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
              ),
            ),
          if (cost.hasToll) ...[
            _row(p, Icons.toll_outlined, 'Pedaggio ${cost.toll.verified ? '' : '(stima)'}',
                '${cost.toll.km.toStringAsFixed(0)} km autostrada', cost.toll.total.format()),
            for (final line in cost.toll.lines)
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 2),
                child: Row(
                  children: [
                    Text(line.ref, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.muted)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${line.km.toStringAsFixed(1)} km · ${line.concession ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: p.muted),
                      ),
                    ),
                    Text(line.amount.format(), style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
              ),
          ],
          if (!cost.parking.isZero) _row(p, Icons.local_parking_outlined, 'Parcheggio', '', cost.parking.format()),
          Divider(color: p.border, height: 18),
          _row(p, Icons.summarize_outlined, 'Totale', '', cost.total.format(), bold: true),
        ],
      ),
    );
  }

  Widget _row(AppPalette p, IconData icon, String label, String detail, String amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: p.ink)),
                if (detail.isNotEmpty)
                  Text(detail, style: TextStyle(fontSize: 10.5, color: p.muted)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: bold ? 15 : 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink)),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.cost, required this.free, required this.hourlyValue});

  final TripCostResult cost;
  final RoutePlan free;
  final double hourlyValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final freeFuel = cost.fuelLiters * cost.pricePerLiter * (free.km / cost.route.km.clamp(0.1, 1e9));
    final freeTotal = freeFuel + cost.parking.euro;
    final delta = cost.total.euro - freeTotal;
    final minutes = free.minutes - cost.route.minutes;
    final timeValue = hourlyValue > 0 ? minutes / 60 * hourlyValue : null;
    final verdict = timeValue == null
        ? 'Imposta il valore del tempo nelle impostazioni per il verdetto.'
        : (timeValue - delta) >= 0
            ? 'L\'autostrada conviene: risparmi ${_euro(timeValue - delta)} di tempo.'
            : 'Non conviene: paghi ${_euro(delta - timeValue)} in più rispetto al tempo risparmiato.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Autostrada vs strade gratuite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 8),
          _line(p, 'Autostrada', '${cost.route.distance.format()} · ${_duration(cost.route.minutes)}', cost.total.format()),
          _line(p, 'Gratuita', '${free.distance.format()} · ${_duration(free.minutes)}', _euro(freeTotal)),
          const SizedBox(height: 6),
          Text(
            'Differenza ${_euro(delta)} · ${minutes >= 0 ? '+' : ''}${minutes.toStringAsFixed(0)} min. $verdict',
            style: TextStyle(fontSize: 11, height: 1.4, color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _line(AppPalette p, String label, String detail, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 78, child: Text(label, style: TextStyle(fontSize: 12, color: p.ink))),
            Expanded(child: Text(detail, style: TextStyle(fontSize: 11, color: p.muted))),
            Text(amount, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
          ],
        ),
      );

  static String _euro(double v) => Money(v).format();
  static String _duration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }
}

class _RefuelCard extends StatelessWidget {
  const _RefuelCard({required this.refuel});

  final RefuelSuggestion refuel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final station = refuel.station.station;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.brandSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, size: 18, color: p.brand),
              const SizedBox(width: 6),
              Text('Rifornimento smart', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
              const Spacer(),
              Text('−${Money(refuel.netSaving).format()}', style: PriceType.style(p, size: 15, color: p.good)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${station.brand} · ${station.comune} a ${Fmt.km(refuel.station.distanceKm)} dal percorso: '
            '${Fmt.price(refuel.station.price)} contro ${Fmt.price(refuel.referencePrice)} in autostrada. '
            'Su ${refuel.liters.toStringAsFixed(0)} L risparmi ${Money(refuel.netSaving).format()} netti '
            'anche con ${Fmt.km(refuel.detourKm)} di deviazione.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: p.ink.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final TripRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: p.bad.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.delete_outline, color: p.bad),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(Icons.route, size: 18, color: p.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '${record.distance.format()} · ${record.totalMoney.format()} · ${Fmt.date(record.createdAt)}',
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                ],
              ),
            ),
            if (!record.tollVerified) Text('stima', style: TextStyle(fontSize: 10, color: p.warn)),
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.points, required this.from, required this.to});

  final List<LatLng> points;
  final LatLng from;
  final LatLng to;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.points.length < 2) return;
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(widget.points),
        padding: const EdgeInsets.all(28),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.from,
        initialZoom: 8,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.centsgo.centsgo',
        ),
        PolylineLayer(polylines: [Polyline(points: widget.points, strokeWidth: 4, color: p.brand)]),
        MarkerLayer(markers: [
          Marker(point: widget.from, width: 24, height: 24, child: _Dot(color: p.good)),
          Marker(point: widget.to, width: 24, height: 24, child: _Dot(color: p.bad)),
        ]),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
      );
}
