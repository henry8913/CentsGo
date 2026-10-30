import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/launcher.dart';
import '../../models/map_layers.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../state/app_state.dart';
import '../../state/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';
import '../common/place_picker.dart';
import '../station/station_sheet.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.state, this.onOpenList});

  final AppState state;
  final VoidCallback? onOpenList;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _map = MapController();

  List<StationHit> _hits = const [];
  ({double min, double median, double max}) _spread = (min: 0, median: 0, max: 0);
  LatLng? _cameraCenter;
  double _zoom = 12.5;
  double _rotation = 0;
  bool _cameraReady = false;
  bool _centeredOnGps = false;
  String _querySignature = '';
  Size _viewport = const Size(390, 780);
  bool _busy = false;
  bool _layersLoading = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _cameraCenter = state.center;
    _query();
    if (state.settings.layers.ev || state.settings.layers.ztl || state.settings.layers.pois) {
      _warmLayers();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _map.move(state.center, _zoom);
        _cameraReady = true;
      }
    });
  }

  Future<void> _warmLayers() async {
    setState(() => _layersLoading = true);
    await state.warmLayers();
    if (mounted) setState(() => _layersLoading = false);
  }

  /// Radius queried around the camera: about the visible diagonal, so panning
  /// the map always finds the stations the user is actually looking at.
  double _radiusKm(LatLng center, double zoom) {
    final metersPerPixel = 156543.03392 * math.cos(center.latitude * math.pi / 180) / math.pow(2, zoom);
    final diagonal = math.sqrt(_viewport.width * _viewport.width + _viewport.height * _viewport.height);
    return (diagonal * metersPerPixel / 1000 / 2 * 1.15).clamp(2.0, 45.0);
  }

  /// Re-runs the query whenever the camera *or* a filter/sort setting changes.
  void _ensureQuery() {
    final s = state.settings;
    final center = _cameraCenter;
    final signature = [
      s.fuel,
      s.selfService,
      s.brand,
      s.sort.name,
      state.revision,
      center?.latitude,
      center?.longitude,
      _zoom.toStringAsFixed(2),
    ].join('|');
    if (signature == _querySignature) return;
    _querySignature = signature;
    _query();
  }

  void _query() {
    final center = _cameraCenter;
    if (center == null) return;
    final radius = _radiusKm(center, _zoom);
    final hits = state.catalog.nearby(
      center: center,
      fuel: state.settings.fuel,
      self: state.settings.selfService,
      sort: state.settings.sort,
      radiusKm: radius,
      brand: state.settings.brand,
      limit: 400,
    );
    final prices = hits.map((h) => h.price).toList()..sort();
    _hits = hits;
    _spread = prices.isEmpty
        ? (min: 0, median: 0, max: 0)
        : (min: prices.first, median: prices[prices.length ~/ 2], max: prices.last);
  }

  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    final previous = _cameraCenter;
    final zoomChanged = camera.zoom != _zoom;
    final moved = previous == null || Geo.distanceKm(previous, camera.center) > 0.2;
    if (!zoomChanged && !moved) return;
    if (!mounted) return;
    final rotationChanged = (camera.rotation - _rotation).abs() > 0.5;
    if (!zoomChanged && !moved && !rotationChanged) return;
    setState(() {
      _zoom = camera.zoom;
      _rotation = camera.rotation;
      _cameraCenter = camera.center;
      _query();
    });
  }

  @override
  Widget build(BuildContext context) {
    _viewport = MediaQuery.sizeOf(context);
    _ensureQuery();
    // The first GPS fix moves the camera to the user, but only once: afterwards
    // the map belongs to the user's panning.
    if (!_centeredOnGps && state.gpsPosition != null) {
      _centeredOnGps = true;
      final fix = state.gpsPosition!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(fix, 14);
      });
    }
    final p = context.palette;
    final cheapest = _hits.isEmpty ? null : _hits.reduce((a, b) => a.price <= b.price ? a : b);
    final wide = _viewport.width > 700;
    final ztlZones = state.settings.layers.ztl && state.layers.ztlLoaded
        ? state.layers.ztlNear(_cameraCenter ?? state.center, radiusKm: 30)
        : const <ZtlZone>[];
    final chargers = state.settings.layers.ev && state.layers.evLoaded
        ? state.layers.evNear(_cameraCenter ?? state.center, radiusKm: 20, limit: 180)
        : const <EvCharger>[];
    final pois = state.settings.layers.pois && state.layers.poisLoaded
        ? state.layers.poisNear(
            _cameraCenter ?? state.center,
            state.settings.layers.poiKinds,
            radiusKm: 12,
            limit: 120,
          )
        : const <PlacePoi>[];

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: state.center,
        initialZoom: _zoom,
        minZoom: 5,
        maxZoom: 18,
        backgroundColor: p.surfaceAlt,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onPositionChanged: _onCameraChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.centsgo.centsgo',
          maxNativeZoom: 19,
          retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
        ),
        if (ztlZones.isNotEmpty)
          PolygonLayer(
            polygons: [
              for (final z in ztlZones)
                for (final ring in z.rings)
                  Polygon(
                    points: ring,
                    color: p.bad.withValues(alpha: 0.08),
                    borderColor: p.bad.withValues(alpha: 0.6),
                    borderStrokeWidth: 1.4,
                  ),
            ],
          ),
        if (pois.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final poi in pois.take(80))
                Marker(
                  point: poi.position,
                  width: 28,
                  height: 28,
                  child: _PoiMarker(poi: poi, onTap: () => _showPoi(poi)),
                ),
            ],
          ),
        if (chargers.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final c in chargers.take(120))
                Marker(
                  point: c.position,
                  width: 26,
                  height: 26,
                  child: _EvMarker(charger: c, onTap: () => _openCharger(c)),
                ),
            ],
          ),
        if (state.gpsPosition != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: state.gpsPosition!,
                radius: 60,
                useRadiusInMeter: true,
                color: p.brand.withValues(alpha: 0.18),
                borderColor: p.brand.withValues(alpha: 0.5),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final hit in _visibleMarkers(_hits))
              Marker(
                point: hit.station.position,
                width: _markerWidth(hit.price),
                height: 32,
                alignment: Alignment.center,
                child: _PriceMarker(
                  price: hit.price,
                  color: convenienceColor(p, hit.price, _spread.min, _spread.median, _spread.max),
                  onTap: () => _openStation(hit),
                ),
              ),
          ],
        ),
        if (state.gpsPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: state.gpsPosition!,
                width: 24,
                height: 24,
                child: _UserDot(color: p.brand),
              ),
            ],
          ),
      ],
    );

    final content = Stack(
      children: [
        Positioned.fill(
          child: wide
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: p.border)),
                      child: map,
                    ),
                  ),
                )
              : map,
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _SearchBar(
                  label: state.centerLabel,
                  onTap: () async {
                    final place = await pickPlace(context, state);
                    if (place != null && mounted) {
                      state.setPlace(place);
                      _map.move(place.position, _zoom < 11 ? 11 : _zoom);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              FuelBar(state: state, compact: true),
              PriorityBanner(state: state),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        '© OpenStreetMap',
                        style: TextStyle(fontSize: 9.5, color: p.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MapAction(
                      icon: Icons.my_location,
                      label: 'Posizione',
                      busy: state.locating || _busy,
                      onTap: _locate,
                    ),
                    const SizedBox(width: 8),
                    _MapAction(
                      icon: Icons.layers_outlined,
                      label: 'Livelli',
                      busy: _layersLoading,
                      onTap: _openLayers,
                    ),
                    const Spacer(),
                    if (cheapest != null)
                      _CheapestPill(hit: cheapest, count: _hits.length, onTap: () => _openStation(cheapest)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96,
          child: Column(
            children: [
              if (_rotation.abs() > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _CompassButton(rotation: _rotation, onTap: () => _map.rotate(0)),
                ),
              _ZoomButton(icon: Icons.add, onTap: () => _map.move(_map.camera.center, (_zoom + 1).clamp(5, 18))),
              const SizedBox(height: 6),
              _ZoomButton(icon: Icons.remove, onTap: () => _map.move(_map.camera.center, (_zoom - 1).clamp(5, 18))),
            ],
          ),
        ),
        if (_cameraReady && Geo.distanceKm(_map.camera.center, state.center) > 2)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 112,
            left: 0,
            right: 0,
            child: Center(
              child: _SearchAreaButton(
                onTap: () {
                  state.setCenter(_map.camera.center);
                  setState(_query);
                },
              ),
            ),
          ),
      ],
    );

    return content;
  }

  List<StationHit> _visibleMarkers(List<StationHit> hits) {
    final cellKm = (42 / math.pow(2, _zoom - 8)).clamp(0.3, 12.0).toDouble();
    final dLat = cellKm / 111.32;
    final dLon = dLat / math.max(0.15, math.cos((_cameraCenter?.latitude ?? 45) * math.pi / 180));
    final seen = <String>{};
    final out = <StationHit>[];
    for (final hit in hits) {
      final key = '${(hit.station.lat / dLat).floor()}:${(hit.station.lon / dLon).floor()}';
      if (seen.add(key)) out.add(hit);
      if (out.length >= 100) break;
    }
    return out;
  }

  double _markerWidth(double price) {
    final text = Fmt.priceCompact(price);
    return 30 + text.length * 8.0;
  }

  Future<void> _locate() async {
    if (state.locating) return;
    setState(() => _busy = true);
    final ok = await state.detectLocation(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _map.move(state.gpsPosition ?? state.center, 14);
      return;
    }
    final serviceEnabled = await LocationService.ensureServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      _showLocationHelp(context);
    }
  }

  void _showLocationHelp(BuildContext context) {
    final p = context.palette;
    showAppSheet<void>(
      context,
      heightFactor: 0.55,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const SheetTitle(
            'Posizione non disponibile',
            subtitle: 'Puoi comunque esplorare qualsiasi zona d\'Italia',
          ),
          const SizedBox(height: 8),
          Icon(Icons.location_off_outlined, size: 40, color: p.warn),
          const SizedBox(height: 10),
          Text(
            state.permissionPermanentlyDenied
                ? 'Hai negato l\'accesso alla posizione. Puoi riattivarlo dalle impostazioni di sistema, oppure scegliere una città.'
                : 'Il servizio di localizzazione è disattivato o non disponibile su questo dispositivo.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: p.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              LocationService.openSettings();
            },
            icon: const Icon(Icons.settings_outlined, size: 19),
            label: const Text('Apri impostazioni'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final place = await pickPlace(context, state);
              if (place != null && context.mounted) {
                state.setPlace(place);
                _map.move(place.position, 12);
              }
            },
            icon: const Icon(Icons.location_city, size: 19),
            label: const Text('Scegli una città'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.brand,
              side: BorderSide(color: p.brand),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  void _openStation(StationHit hit) {
    _map.move(hit.station.position, _zoom < 13 ? 13 : _zoom);
    showStationSheet(context, state: state, station: hit.station);
  }

  void _openCharger(EvCharger charger) {
    final tariff = state.layers.estimateEvTariff(charger.brand, charger.kw);
    showAppSheet<void>(
      context,
      heightFactor: 0.55,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.palette.greenSoft,
                child: Icon(Icons.bolt, color: context.palette.good),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(charger.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '${charger.kw.toStringAsFixed(0)} kW · ${charger.plugs.join(', ')}',
                      style: TextStyle(fontSize: 12.5, color: context.palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(charger.name, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(charger.address, style: TextStyle(fontSize: 12.5, color: context.palette.muted)),
          const SizedBox(height: 16),
          InfoBanner(
            icon: Icons.euro,
            text: tariff.hasValue
                ? 'Prezzo stimato ${tariff.value!.toStringAsFixed(2).replaceAll('.', ',')} €/kWh (${tariff.operatorName}). Fonte: ${tariff.source}.'
                : 'Prezzo non verificato per questo operatore: usiamo la media di mercato.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=${charger.position.latitude},${charger.position.longitude}',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Portami qui'),
          ),
        ],
      ),
    );
  }

  void _showPoi(PlacePoi poi) {
    final p = context.palette;
    final address = [poi.address, poi.city].where((e) => e.isNotEmpty).join(', ');
    final query = Uri.encodeComponent('${poi.name} $address');
    showAppSheet<void>(
      context,
      heightFactor: 0.66,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.warn.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  switch (poi.kind) {
                    PoiKind.wash => Icons.local_car_wash,
                    PoiKind.tyres => Icons.tire_repair,
                    _ => Icons.build,
                  },
                  color: p.warn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poi.name, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.ink)),
                    Text(
                      PoiKind.label(poi.kind),
                      style: TextStyle(fontSize: 12.5, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (address.isNotEmpty)
            _DetailRow(icon: Icons.place_outlined, label: address),
          _DetailRow(
            icon: Icons.schedule,
            label: poi.openingHours.isEmpty ? 'Orari non disponibili' : prettyOsmHours(poi.openingHours),
          ),
          if (poi.phone.isNotEmpty) _DetailRow(icon: Icons.phone_outlined, label: poi.phone),
          if (poi.website.isNotEmpty) _DetailRow(icon: Icons.link, label: poi.website),
          const SizedBox(height: 16),
          Row(
            children: [
              if (poi.phone.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openExternal(context, 'tel:${poi.phone.replaceAll(' ', '')}'),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Chiama'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.brand,
                      side: BorderSide(color: p.brand),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              if (poi.phone.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openExternal(context, 'https://www.google.com/maps/search/?api=1&query=$query'),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Scheda e orari'),
                ),
              ),
            ],
          ),
          if (poi.website.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openExternal(context, poi.website),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Apri sito web'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                side: BorderSide(color: p.border),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const InfoBanner(
            text: 'Dati OpenStreetMap (ODbL). Orari e contatti possono non essere aggiornati: '
                'la scheda su Google Maps è la fonte più recente.',
          ),
        ],
      ),
    );
  }

  void _openLayers() {
    showAppSheet<void>(
      context,
      heightFactor: 0.75,
      child: _LayersSheet(state: state),
    );
  }
}

/// Small banner shown when the GPS is unavailable, so the user understands why
/// the map is not centred on them.
class PriorityBanner extends StatelessWidget {
  const PriorityBanner({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.locating) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: InfoBanner(text: 'Cerco la tua posizione…', icon: Icons.my_location),
      );
    }
    if (!state.permissionDenied || state.hasGps) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InfoBanner(
        text: 'Posizione non attiva: stai esplorando ${state.centerLabel}.',
        icon: Icons.location_off_outlined,
        color: context.palette.warn,
      ),
    );
  }
}

class _LayersSheet extends StatefulWidget {
  const _LayersSheet({required this.state});

  final AppState state;

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late MapLayerSettings _layers = widget.state.settings.layers;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    void update(MapLayerSettings next) {
      setState(() => _layers = next);
      widget.state.setLayers(next);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const SheetTitle('Livelli mappa', subtitle: 'Servizi utili intorno a te'),
        const SizedBox(height: 8),
        _LayerRow(
          icon: Icons.bolt,
          color: p.good,
          title: 'Colonnine elettriche',
          subtitle: 'Potenza, prese e prezzo stimato',
          value: _layers.ev,
          onChanged: (v) => update(_layers.copyWith(ev: v)),
        ),
        _LayerRow(
          icon: Icons.wrong_location_outlined,
          color: p.bad,
          title: 'Zone ZTL',
          subtitle: 'Aree a traffico limitato',
          value: _layers.ztl,
          onChanged: (v) => update(_layers.copyWith(ztl: v)),
        ),
        _LayerRow(
          icon: Icons.build_outlined,
          color: p.warn,
          title: 'Officine / Meccanici',
          subtitle: 'Riparazioni e manutenzione',
          value: _layers.pois && _layers.poiKinds.contains(PoiKind.repair),
          onChanged: (v) => update(
            _layers.copyWith(
              pois: v || _layers.pois,
              poiKinds: {..._layers.poiKinds}..toggle(PoiKind.repair, v),
            ),
          ),
        ),
        _LayerRow(
          icon: Icons.local_car_wash_outlined,
          color: p.slate,
          title: 'Autolavaggi',
          subtitle: 'Lavaggi nelle vicinanze',
          value: _layers.pois && _layers.poiKinds.contains(PoiKind.wash),
          onChanged: (v) => update(
            _layers.copyWith(
              pois: v || _layers.pois,
              poiKinds: {..._layers.poiKinds}..toggle(PoiKind.wash, v),
            ),
          ),
        ),
        _LayerRow(
          icon: Icons.tire_repair,
          color: p.brand,
          title: 'Gommisti',
          subtitle: 'Pneumatici e convergenze',
          value: _layers.pois && _layers.poiKinds.contains(PoiKind.tyres),
          onChanged: (v) => update(
            _layers.copyWith(
              pois: v || _layers.pois,
              poiKinds: {..._layers.poiKinds}..toggle(PoiKind.tyres, v),
            ),
          ),
        ),
        const SizedBox(height: 10),
        InfoBanner(
          text: 'I livelli sono inclusi nell\'app: nessun dato personale lascia il dispositivo. '
              'I centri revisione MIT non sono presenti nello snapshot.',
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

extension on Set<String> {
  void toggle(String value, bool on) {
    if (on) {
      add(value);
    } else {
      remove(value);
    }
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  /// "Vicino a Romentino (NO)" -> "Romentino": the badge must stay small.
  static String _shortLabel(String value) {
    var v = value.replaceFirst('Vicino a ', '');
    if (v.contains(' (')) v = v.split(' (').first;
    return v;
  }

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
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: p.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cerca città, zona o indirizzo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: p.muted),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    _shortLabel(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({required this.price, required this.color, required this.onTap});

  final double price;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Fmt.priceCompact(price),
            style: const TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvMarker extends StatelessWidget {
  const _EvMarker({required this.charger, required this.onTap});

  final EvCharger charger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: charger.isHpc ? const Color(0xFF7B4BE0) : const Color(0xFF2E9E5B),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
        child: const Icon(Icons.bolt, size: 14, color: Colors.white),
      ),
    );
  }
}

class _PoiMarker extends StatelessWidget {
  const _PoiMarker({required this.poi, required this.onTap});

  final PlacePoi poi;
  final VoidCallback onTap;

  IconData get _icon => switch (poi.kind) {
        PoiKind.wash => Icons.local_car_wash,
        PoiKind.tyres => Icons.tire_repair,
        _ => Icons.build,
      };

  Color get _color => switch (poi.kind) {
        PoiKind.wash => const Color(0xFF306587),
        PoiKind.tyres => Brand.orange,
        _ => const Color(0xFFE29A24),
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(_icon, size: 13, color: Colors.white),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.4),
          ),
        ),
      ),
    );
  }
}

class _CheapestPill extends StatelessWidget {
  const _CheapestPill({required this.hit, required this.count, required this.onTap});

  final StationHit hit;
  final int count;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined, size: 16, color: p.good),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.price(hit.price),
                    style: Money.style(p, size: 15, color: p.good),
                  ),
                  Text(
                    '$count in vista',
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAreaButton extends StatelessWidget {
  const _SearchAreaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.ink,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 16, color: p.bg),
              const SizedBox(width: 6),
              Text(
                'Cerca in quest\'area',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.bg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapAction extends StatelessWidget {
  const _MapAction({required this.icon, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.brand),
                )
              else
                Icon(icon, size: 18, color: p.brand),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.rotation, required this.onTap});

  final double rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.border)),
          child: Transform.rotate(
            angle: -rotation * 3.1415926535 / 180,
            child: Icon(Icons.navigation, size: 18, color: p.brand),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.border)),
          child: Icon(icon, size: 18, color: p.ink),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: p.ink))),
        ],
      ),
    );
  }
}
