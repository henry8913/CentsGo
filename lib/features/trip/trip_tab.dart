import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/format.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/station_card.dart';
import '../../widgets/ui.dart';
import '../common/place_picker.dart';
import '../station/station_sheet.dart';

class TripTab extends StatefulWidget {
  const TripTab({super.key, required this.state});

  final AppState state;

  @override
  State<TripTab> createState() => _TripTabState();
}

class _TripTabState extends State<TripTab> {
  Place? _origin;
  Place? _destination;
  double _corridor = 4;
  TripResult? _result;
  bool _busy = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _origin = Place(
      name: state.centerLabel.replaceAll('Vicino a ', '').split(' (').first,
      prov: '',
      position: state.center,
    );
  }

  Future<void> _pick({required bool origin}) async {
    final place = await pickPlace(context, state, title: origin ? 'Partenza' : 'Arrivo', autoDetect: false);
    if (place == null) return;
    setState(() {
      if (origin) {
        _origin = place;
      } else {
        _destination = place;
      }
      _result = null;
    });
  }

  Future<void> _calculate() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli partenza e arrivo per calcolare il percorso.')),
      );
      return;
    }
    setState(() => _busy = true);
    final trip = TripPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      origin: origin,
      destination: destination,
      createdAt: DateTime.now(),
      corridorKm: _corridor,
    );
    final result = state.planTrip(trip);
    await state.rememberTrip(trip);
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          const ScreenTitle(
            title: 'Viaggio',
            subtitle: 'I distributori più convenienti lungo la strada',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                _EndpointRow(
                  icon: Icons.radio_button_checked,
                  color: p.good,
                  label: 'Partenza',
                  value: _origin?.label ?? 'Scegli',
                  onTap: () => _pick(origin: true),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Divider(color: p.border, height: 12),
                ),
                _EndpointRow(
                  icon: Icons.place,
                  color: p.bad,
                  label: 'Arrivo',
                  value: _destination?.label ?? 'Scegli',
                  onTap: () => _pick(origin: false),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.alt_route, size: 16, color: p.muted),
                    const SizedBox(width: 6),
                    Text('Deviazione max', style: TextStyle(fontSize: 12.5, color: p.muted)),
                    Expanded(
                      child: Slider(
                        value: _corridor,
                        min: 1,
                        max: 12,
                        divisions: 11,
                        label: '${_corridor.round()} km',
                        onChanged: (v) => setState(() => _corridor = v),
                      ),
                    ),
                    Text('${_corridor.round()} km',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink)),
                  ],
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: _busy ? null : _calculate,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.route, size: 19),
                  label: Text(_busy ? 'Calcolo…' : 'Cerca lungo il percorso'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FuelBar(state: state, compact: true),
          if (state.trips.isNotEmpty) ...[
            const SectionTitle('Viaggi recenti'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final trip in state.trips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PillChip(
                        label: trip.label,
                        selected: false,
                        dense: true,
                        icon: Icons.history,
                        onTap: () {
                          setState(() {
                            _origin = trip.origin;
                            _destination = trip.destination;
                            _corridor = trip.corridorKm;
                            _result = null;
                          });
                          _calculate();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 8),
            _ResultHeader(result: _result!),
            const SizedBox(height: 12),
            _RouteMap(result: _result!, onTap: (station) => showStationSheet(context, state: state, station: station)),
            const SizedBox(height: 14),
            for (final hit in _result!.hits.take(40))
              StationCard(
                hit: hit,
                fuel: _result!.fuel,
                min: _result!.hits.map((h) => h.price).reduce((a, b) => a < b ? a : b),
                median: _median(_result!.hits.map((h) => h.price).toList()),
                max: _result!.hits.map((h) => h.price).reduce((a, b) => a > b ? a : b),
                trailingLabel: hit.detourKm == null ? null : '${Fmt.km(hit.detourKm!)} dal percorso',
                onTap: () => showStationSheet(context, state: state, station: hit.station),
              ),
          ] else ...[
            const SizedBox(height: 10),
            const InfoBanner(
              text: 'Il percorso è calcolato in linea d\'aria: CentsGo cerca gli impianti entro la deviazione scelta, '
                  'senza consumare API di routing. Apri il navigatore dalla scheda del distributore.',
              icon: Icons.info_outline,
            ),
          ],
        ],
      ),
    );
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 17, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});

  final TripResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cheapest = result.cheapest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.trip.origin.name} → ${result.trip.destination.name}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cheapest == null ? '—' : Fmt.price(cheapest.price),
                style: Money.style(p, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '€/${Fuels.unit(result.fuel)} · ${result.selfService ? 'self' : 'servito'}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.hits.length} distributori sul percorso · ~${Fmt.km(result.trip.distanceKm)} in linea d\'aria',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          if (result.savingsVsMedian() > 0.01) ...[
            const SizedBox(height: 6),
            Text(
              'Risparmi fino a ${Fmt.euro(result.savingsVsMedian())} su 50 L rispetto alla mediana del percorso',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.result, required this.onTap});

  final TripResult result;
  final ValueChanged<Station> onTap;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final MapController _map = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final path = widget.result.path;
      if (path.length < 2) return;
      final bounds = LatLngBounds.fromPoints(path);
      _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hits = widget.result.hits.take(50).toList();
    final cheapest = widget.result.cheapest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 250,
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.result.trip.origin.position,
            initialZoom: 8,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.centsgo.centsgo',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: widget.result.path, strokeWidth: 4, color: p.brand),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.result.trip.origin.position,
                  width: 26,
                  height: 26,
                  child: const _EndpointDot(color: Color(0xFF1F9E58)),
                ),
                Marker(
                  point: widget.result.trip.destination.position,
                  width: 26,
                  height: 26,
                  child: const _EndpointDot(color: Color(0xFFDE5349)),
                ),
                for (final hit in hits)
                  Marker(
                    point: hit.station.position,
                    width: 58,
                    height: 26,
                    child: GestureDetector(
                      onTap: () => widget.onTap(hit.station),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cheapest != null && hit.station.id == cheapest.station.id
                              ? p.good
                              : p.warn,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: FittedBox(
                          child: Text(
                            Fmt.priceCompact(hit.price),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
    );
  }
}
