import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/settings.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/station_card.dart';
import '../../widgets/ui.dart';
import '../alerts/alerts_screen.dart';
import '../station/station_sheet.dart';

enum _SearchMode { station, zone, highway }

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.state, this.onOpenList});

  final AppState state;
  final VoidCallback? onOpenList;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  _SearchMode _mode = _SearchMode.station;
  final _controller = TextEditingController();
  String _query = '';

  AppState get state => widget.state;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: ScreenTitle(
              title: 'Cerca',
              subtitle: 'Distributori, zone e autostrade',
              trailing: RoundIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Avvisi prezzo',
                badge: state.unreadAlerts.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AlertsScreen(state: state)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  _ModeButton(
                    icon: Icons.local_gas_station_outlined,
                    label: 'Distributore',
                    selected: _mode == _SearchMode.station,
                    onTap: () => setState(() => _mode = _SearchMode.station),
                  ),
                  _ModeButton(
                    icon: Icons.apartment,
                    label: 'Zona',
                    selected: _mode == _SearchMode.zone,
                    onTap: () => setState(() => _mode = _SearchMode.zone),
                  ),
                  _ModeButton(
                    icon: Icons.fork_right,
                    label: 'Autostrada',
                    selected: _mode == _SearchMode.highway,
                    onTap: () => setState(() => _mode = _SearchMode.highway),
                  ),
                ],
              ),
            ),
          ),
          if (_mode != _SearchMode.highway)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: switch (_mode) {
                    _SearchMode.station => 'Nome, marchio o indirizzo',
                    _SearchMode.zone => 'Es. Milano, Napoli, Bari',
                    _ => 'Es. A1, A14',
                  },
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FuelBar(state: state, compact: true),
          const SizedBox(height: 6),
          Expanded(child: _results(context)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    switch (_mode) {
      case _SearchMode.station:
        return _stationResults(context);
      case _SearchMode.zone:
        return _zoneResults(context);
      case _SearchMode.highway:
        return _highwayResults(context);
    }
  }

  Widget _stationResults(BuildContext context) {
    final p = context.palette;
    final results = state.catalog.searchStations(_query, limit: 40);
    if (_query.trim().isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SectionTitle('Marchi più presenti', padding: const EdgeInsets.only(bottom: 10)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final brand in state.catalog.topBrands)
                PillChip(
                  label: brand,
                  selected: state.settings.brand == brand,
                  dense: true,
                  onTap: () {
                    if (state.settings.brand == brand) {
                      state.setBrand(null);
                    } else {
                      state.setBrand(brand);
                      widget.onOpenList?.call();
                    }
                  },
                ),
            ],
          ),
          SectionTitle('Come funziona', padding: const EdgeInsets.only(top: 26, bottom: 8)),
          const InfoBanner(
            text: 'Cerca per nome dell\'impianto, marchio o indirizzo. I prezzi sono quelli comunicati al MIMIT e '
                'mostrati per il carburante selezionato.',
          ),
        ],
      );
    }
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Nessun risultato',
        message: 'Prova con il nome del marchio (es. Q8, Eni) o con una via.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => Divider(color: p.border, height: 1),
      itemBuilder: (context, i) {
        final station = results[i];
        final price = station.priceFor(state.settings.fuel, self: state.settings.selfService);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: BrandBadge(letter: station.initial, size: 38),
          title: Text('${station.brand} · ${station.displayName}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(station.fullAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: price == null
              ? null
              : Text(
                  Fmt.price(price),
                  style: Money.style(p, size: 15, color: p.good),
                ),
          onTap: () => showStationSheet(context, state: state, station: station),
        );
      },
    );
  }

  Widget _zoneResults(BuildContext context) {
    final p = context.palette;
    final places = state.catalog.searchPlaces(_query, limit: 40);
    if (places.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'Nessun comune trovato',
        message: 'CentsGo include i comuni con almeno un distributore.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: places.length,
      separatorBuilder: (_, __) => Divider(color: p.border, height: 1),
      itemBuilder: (context, i) {
        final place = places[i];
        final best = state.catalog.bestInComune(place.name, state.settings.fuel, state.settings.selfService);
        final count = state.catalog.inComune(place.name).length;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: CircleAvatar(
            backgroundColor: p.brandSoft,
            child: Icon(Icons.location_city, size: 19, color: p.brand),
          ),
          title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${place.prov} · $count impianti'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (best != null)
                Text(
                  'da ${Fmt.price(best.price)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.good),
                ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 20, color: p.muted),
            ],
          ),
          onTap: () {
            state.setCenter(place.position, label: place.label);
            widget.onOpenList?.call();
          },
        );
      },
    );
  }

  Widget _highwayResults(BuildContext context) {
    final p = context.palette;
    final q = _query.trim().toLowerCase();
    final entries = state.catalog.highways.entries
        .where((e) => q.isEmpty || e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => Divider(color: p.border, height: 1),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: InfoBanner(
              text: 'Le aree di servizio sono ${state.catalog.byHighway.values.fold<int>(0, (a, b) => a + b.length)} '
                  'impianti autostradali inclusi nella snapshot MIMIT.',
              icon: Icons.info_outline,
            ),
          );
        }
        final entry = entries[i];
        final hits = state.catalog.highwayHits(
          entry.key,
          state.settings.fuel,
          state.settings.selfService,
          SortMode.price,
        );
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            width: 44,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.good, borderRadius: BorderRadius.circular(8)),
            child: Text(
              entry.key,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            hits.isEmpty
                ? 'Nessun prezzo per ${state.settings.fuel}'
                : '${hits.length} impianti · da ${Fmt.price(hits.first.price)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, size: 20, color: p.muted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HighwayScreen(state: state, code: entry.key, name: entry.value),
            ),
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: selected ? Colors.white : p.muted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : p.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Station list of a single motorway.
class HighwayScreen extends StatelessWidget {
  const HighwayScreen({super.key, required this.state, required this.code, required this.name});

  final AppState state;
  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hits = state.catalog.highwayHits(code, state.settings.fuel, state.settings.selfService, state.settings.sort);
    final prices = hits.map((h) => h.price).toList()..sort();
    final spread = prices.isEmpty
        ? (min: 0.0, median: 0.0, max: 0.0)
        : (min: prices.first, median: prices[prices.length ~/ 2], max: prices.last);
    return Scaffold(
      appBar: AppBar(title: Text('$code · $name')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          InfoBanner(
            text: '${hits.length} aree di servizio · prezzi ${state.settings.fuel} '
                '${state.settings.selfService ? 'self' : 'servito'}',
            icon: Icons.fork_right,
          ),
          const SizedBox(height: 12),
          for (final hit in hits)
            StationCard(
              hit: hit,
              fuel: state.settings.fuel,
              min: spread.min,
              median: spread.median,
              max: spread.max,
              onTap: () => showStationSheet(context, state: state, station: hit.station),
            ),
          if (hits.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'Nessun prezzo disponibile',
              message: 'Questo carburante non è venduto nelle aree di servizio di questa autostrada.',
            ),
          const SizedBox(height: 6),
          Text(
            'Dati MIMIT · ${state.catalog.extractionDate}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: p.muted),
          ),
        ],
      ),
    );
  }
}
