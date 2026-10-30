import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/station_card.dart';
import '../../widgets/ui.dart';
import '../alerts/alerts_screen.dart';
import '../common/place_picker.dart';
import '../station/station_sheet.dart';

class ListTab extends StatefulWidget {
  const ListTab({super.key, required this.state, this.onOpenMap, this.onOpenSearch});

  final AppState state;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenSearch;

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  List<StationHit> _hits = const [];
  ({double min, double median, double max}) _spread = (min: 0, median: 0, max: 0);
  StationHit? _cheapest;
  SmartFill? _smart;
  String _signature = '';
  bool _refreshing = false;

  AppState get state => widget.state;

  /// Every input of the query belongs to the signature: whenever one changes
  /// (including the sort mode) the list is recomputed.
  void _recompute() {
    final s = state.settings;
    final signature = [
      s.fuel,
      s.selfService,
      s.brand,
      s.radiusKm,
      s.sort.name,
      state.revision,
      state.center.latitude,
      state.center.longitude,
    ].join('|');
    if (signature == _signature) return;
    _signature = signature;

    final hits = state.nearby(limit: 300);
    final prices = hits.map((h) => h.price).toList()..sort();
    _hits = hits;
    _spread = prices.isEmpty
        ? (min: 0, median: 0, max: 0)
        : (min: prices.first, median: prices[prices.length ~/ 2], max: prices.last);
    // The cheapest station is a property of the data, not of the current order.
    _cheapest = hits.isEmpty ? null : hits.reduce((a, b) => a.price <= b.price ? a : b);
    _smart = state.smartFill(_cheapest == null ? const [] : _sortedByPrice(hits));
  }

  List<StationHit> _sortedByPrice(List<StationHit> hits) => [...hits]..sort((a, b) => a.price.compareTo(b.price));

  @override
  Widget build(BuildContext context) {
    _recompute();
    final p = context.palette;
    final s = state.settings;
    final hits = _hits;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
          child: ScreenTitle(
            title: 'Lista',
            subtitle: 'Distributori intorno a te',
            trailing: Row(
              children: [
                RoundIconButton(
                  icon: Icons.search,
                  tooltip: 'Cerca per zona o autostrada',
                  onTap: widget.onOpenSearch ?? () {},
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Avvisi prezzo',
                  badge: state.unreadAlerts.length,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AlertsScreen(state: state)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _LocationBar(state: state),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              SegmentedSort(
                options: SortMode.values.map((e) => e.label).toList(),
                selectedIndex: s.sort.index,
                onChanged: (i) => state.setSort(SortMode.values[i]),
                dense: true,
              ),
              const Spacer(),
              Icon(_sortIcon(s.sort), size: 13, color: p.muted),
              const SizedBox(width: 4),
              Text(
                hits.length >= 300 ? '300+' : '${hits.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        FuelBar(state: state),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: p.brand,
            onRefresh: () async {
              setState(() => _refreshing = true);
              await state.syncPrices(force: true);
              await state.refreshPrices();
              if (mounted) setState(() => _refreshing = false);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                return hits.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 30, bottom: 24),
                        children: [
                          EmptyState(
                            icon: Icons.local_gas_station_outlined,
                            title: 'Nessun distributore nel raggio di ${s.radiusKm.round()} km',
                            message: 'Aumenta il raggio di ricerca, cambia carburante o sposta la zona.',
                            actionLabel: 'Allarga il raggio',
                            onAction: () => state.setRadius(30),
                          ),
                        ],
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          if (state.permissionDenied && !state.hasGps)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InfoBanner(
                                text: 'Posizione non attiva: stai vedendo ${state.centerLabel}.',
                                icon: Icons.location_off_outlined,
                                color: p.warn,
                                action: TextButton(
                                  onPressed: () => pickPlace(context, state),
                                  child: const Text('Cambia zona'),
                                ),
                              ),
                            ),
                          _SmartFillCard(
                            smart: _smart,
                            nearest: _smart?.nearest,
                            fuel: s.fuel,
                            selfService: s.selfService,
                            liters: _smart?.liters ?? 50,
                            national: state.nationalStats(s.fuel, self: s.selfService),
                            refreshing: _refreshing || state.syncing,
                            syncProgress: state.syncProgress,
                            lastSync: state.lastSync,
                            onOpen: (hit) => showStationSheet(context, state: state, station: hit.station),
                          ),
                          const SizedBox(height: 12),
                          if (columns == 1)
                            for (final hit in hits)
                              StationCard(
                                hit: hit,
                                fuel: s.fuel,
                                min: _spread.min,
                                median: _spread.median,
                                max: _spread.max,
                                isFavorite: state.isFavorite(hit.station.id),
                                onTap: () => showStationSheet(context, state: state, station: hit.station),
                              )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 0,
                              children: [
                                for (final hit in hits)
                                  SizedBox(
                                    width: (constraints.maxWidth - 16 * 2 - 12) / 2,
                                    child: StationCard(
                                      hit: hit,
                                      fuel: s.fuel,
                                      min: _spread.min,
                                      median: _spread.median,
                                      max: _spread.max,
                                      isFavorite: state.isFavorite(hit.station.id),
                                      onTap: () => showStationSheet(context, state: state, station: hit.station),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      );
              },
            ),
          ),
        ),
      ],
    );
  }

  static IconData _sortIcon(SortMode mode) => switch (mode) {
        SortMode.price => Icons.savings_outlined,
        SortMode.distance => Icons.near_me_outlined,
        SortMode.best => Icons.balance,
      };
}

class _LocationBar extends StatelessWidget {
  const _LocationBar({required this.state});

  final AppState state;

  Future<void> _pick(BuildContext context) async {
    final place = await pickPlace(context, state);
    if (place != null) state.setPlace(place);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: p.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  state.usingGps ? Icons.my_location : Icons.place,
                  size: 19,
                  color: p.brand,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.usingGps ? 'La tua posizione' : 'Stai cercando in',
                      style: TextStyle(fontSize: 10.5, color: p.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      state.centerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.ink),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _pick(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Cambia', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The differentiator: "smart fill" tells you whether it is worth driving past
/// the closest station, net of the fuel burnt on the detour.
class _SmartFillCard extends StatelessWidget {
  const _SmartFillCard({
    required this.smart,
    required this.nearest,
    required this.fuel,
    required this.selfService,
    required this.liters,
    required this.national,
    required this.refreshing,
    required this.onOpen,
    this.syncProgress = 0,
    this.lastSync,
  });

  final SmartFill? smart;
  final StationHit? nearest;
  final String fuel;
  final bool selfService;
  final double liters;
  final NationalStat? national;
  final bool refreshing;
  final ValueChanged<StationHit> onOpen;
  final double syncProgress;
  final DateTime? lastSync;

  static String tankLabel(double liters) =>
      liters == liters.roundToDouble() ? '${liters.round()} L' : Fmt.liters(liters);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final best = smart;
    final target = best?.hit ?? nearest;
    if (target == null) return const SizedBox.shrink();
    final worth = best?.worthIt ?? false;
    final unit = Fuels.unit(fuel);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.brand, Color.lerp(p.brand, p.bad, 0.22)!],
        ),
        boxShadow: [BoxShadow(color: p.brand.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: p.brandOn.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Text(
                'PIENO INTELLIGENTE',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: p.brandOn.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              if (refreshing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.brandOn),
                )
              else if (lastSync != null)
                Text(
                  'agg. ${Fmt.time(lastSync!)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.brandOn.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.price(target.price),
                    style: Money.style(p, size: 34, color: p.brandOn),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '€/$unit · ${selfService ? 'self' : 'servito'}',
                  style: TextStyle(fontSize: 11.5, color: p.brandOn.withValues(alpha: 0.85)),
                ),
              ),
              const Spacer(),
              if (worth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.brandOn.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '−${Fmt.euro(best!.netSaving)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.brandOn),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            worth
                ? 'Conviene: ${target.station.brand} a ${Fmt.km(target.distanceKm)}. '
                    'Risparmi ${Fmt.euro(best!.netSaving)} netti su ${tankLabel(liters)}, '
                    'anche pagando ${Fmt.km(best.extraKm)} di deviazione.'
                : 'Il distributore più vicino è già la scelta migliore: '
                    '${target.station.brand} a ${Fmt.km(target.distanceKm)}.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.brandOn, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (refreshing && syncProgress > 0)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8, color: p.brandOn),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Aggiorno i prezzi… ${(syncProgress * 100).round()}%',
                        style: TextStyle(fontSize: 11, color: p.brandOn.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                )
              else if (national != null)
                Expanded(
                  child: Text(
                    'Italia oggi · min ${Fmt.price(national!.min)} · media ${Fmt.price(national!.median)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.brandOn.withValues(alpha: 0.8)),
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: () => onOpen(target),
                style: TextButton.styleFrom(
                  foregroundColor: p.brandOn,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text('Vedi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: p.brandOn)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 15, color: p.brandOn),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
