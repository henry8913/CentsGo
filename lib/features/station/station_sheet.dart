import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/launcher.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';
import '../garage/refuel_form.dart';

/// Full station detail, opened from the list, the map and the search tab.
Future<void> showStationSheet(
  BuildContext context, {
  required AppState state,
  required Station station,
}) {
  return showAppSheet<void>(
    context,
    heightFactor: 0.92,
    child: _StationSheet(state: state, station: station),
  );
}

class _StationSheet extends StatelessWidget {
  const _StationSheet({required this.state, required this.station});

  final AppState state;
  final Station station;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final p = context.palette;
    final s = state.settings;
    final fuel = s.fuel;
    final price = station.priceFor(fuel, self: s.selfService);
    final localHits = state.catalog.nearby(
      center: station.position,
      fuel: fuel,
      self: s.selfService,
      sort: SortMode.price,
      radiusKm: 8,
      limit: 60,
    );
    final spread = localHits.isEmpty
        ? (min: price ?? 0, median: price ?? 0, max: price ?? 0)
        : (
            min: localHits.map((h) => h.price).reduce((a, b) => a < b ? a : b),
            median: (localHits.map((h) => h.price).toList()..sort())[localHits.length ~/ 2],
            max: localHits.map((h) => h.price).reduce((a, b) => a > b ? a : b),
          );
    final favorite = state.isFavorite(station.id);
    final history = state.historyFor(station.id);
    final vehicle = state.activeVehicle;
    final distanceKm = Geo.distanceKm(state.center, station.position);
    final minutes = (distanceKm / 35 * 60).round().clamp(1, 240);
    final mapsQuery = Uri.encodeComponent(
      '${station.brand} ${station.displayName} ${station.address} ${station.comune}',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Row(
          children: [
            BrandBadge(letter: station.initial, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.brand.toUpperCase(),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(station.displayName, style: TextStyle(fontSize: 13, color: p.muted)),
                ],
              ),
            ),
            RoundIconButton(
              icon: favorite ? Icons.favorite : Icons.favorite_border,
              tooltip: favorite ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
              onTap: () => state.toggleFavorite(station),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(station.fullAddress, style: TextStyle(fontSize: 13.5, height: 1.4, color: p.ink)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Tag(label: 'a ${Fmt.km(distanceKm)} · ~$minutes min', color: p.brand),
            if (station.isHighway)
              _Tag(label: 'Autostrada ${station.highway}', color: p.slate)
            else
              _Tag(label: 'Stradale', color: p.muted),
            _Tag(label: 'Aggiornato ${Fmt.relative(station.updatedAt)}', color: p.muted),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Prezzi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink)),
                  const SizedBox(width: 8),
                  Text('self · servito', style: TextStyle(fontSize: 11.5, color: p.muted)),
                  const Spacer(),
                  Text('€/${Fuels.unit(fuel)}', style: TextStyle(fontSize: 11.5, color: p.muted)),
                ],
              ),
              const SizedBox(height: 10),
              for (final f in station.fuels)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(fuelIcon(f), size: 16, color: f == fuel ? p.brand : p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: f == fuel ? FontWeight.w700 : FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                      ),
                      _PriceCell(
                        value: station.selfPrice(f),
                        highlight: f == fuel && s.selfService,
                        color: p,
                      ),
                      const SizedBox(width: 14),
                      _PriceCell(
                        value: station.servitoPrice(f),
                        highlight: f == fuel && !s.selfService,
                        color: p,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: p.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: p.border),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.schedule, color: p.brand, size: 21),
                title: const Text('Orari e servizi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Scheda aggiornata su Google Maps', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.open_in_new, size: 17),
                onTap: () => openExternal(context, 'https://www.google.com/maps/search/?api=1&query=$mapsQuery'),
              ),
              Divider(height: 1, color: p.border),
              ListTile(
                leading: Icon(Icons.navigation_outlined, color: p.brand, size: 21),
                title: const Text('Indicazioni stradali', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${Fmt.km(distanceKm)} da ${state.centerLabel}', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _openMaps(context, station),
              ),
            ],
          ),
        ),
        if (fuel == Fuels.gpl || fuel == Fuels.metano) ...[
          const SizedBox(height: 10),
          InfoBanner(
            icon: Icons.info_outline,
            color: p.warn,
            text: fuel == Fuels.gpl
                ? 'Il GPL richiede spesso l\'intervento dell\'operatore: controlla gli orari prima di partire.'
                : 'Il metano richiede spesso l\'intervento dell\'operatore: controlla gli orari prima di partire.',
          ),
        ],
        if (price != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Convenienza',
                  value: '${((price - spread.median) / spread.median * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
                  icon: Icons.trending_down,
                  color: price <= spread.median ? p.good : p.bad,
                  caption: price <= spread.median ? 'sotto la media di zona' : 'sopra la media di zona',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Differenza / 50 L',
                  value: (price - spread.min) * 50 < 0.005 ? 'Top prezzo' : Fmt.euro((price - spread.min) * 50),
                  icon: Icons.savings_outlined,
                  color: price <= spread.min + 0.0005 ? p.good : p.warn,
                  caption: price <= spread.min + 0.0005
                      ? 'il più economico in zona'
                      : 'vs ${Fmt.price(spread.min)}',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openMaps(context, station),
                icon: const Icon(Icons.navigation_outlined, size: 19),
                label: const Text('Portami qui'),
              ),
            ),
            const SizedBox(width: 10),
            RoundIconButton(
              icon: Icons.star_border,
              tooltip: 'Salva come preferito',
              size: 50,
              onTap: () => state.toggleFavorite(station),
            ),
          ],
        ),
        if (vehicle != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showRefuelForm(context, state: state, station: station),
            icon: const Icon(Icons.local_gas_station_outlined, size: 19),
            label: Text('Registra rifornimento su ${vehicle.displayName}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.brand,
              side: BorderSide(color: p.brand),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
        const SizedBox(height: 22),
        SectionTitle(
          'Storico locale',
          padding: const EdgeInsets.only(bottom: 8),
          action: Text(
            history.length < 2 ? 'in raccolta' : '${history.length} rilevazioni',
            style: TextStyle(fontSize: 11.5, color: p.muted),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Sparkline(
                values: history
                    .map((e) => (s.selfService ? e.self : e.servito) ?? 0)
                    .where((e) => e > 0)
                    .toList(),
                height: 80,
                showAxis: true,
              ),
              const SizedBox(height: 6),
              Text(
                'CentsGo registra il prezzo ogni volta che apri questa scheda: il grafico mostra l\'andamento reale nel tempo.',
                style: TextStyle(fontSize: 11, height: 1.35, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMaps(BuildContext context, Station station) async {
    final destination = '${station.lat},${station.lon}';
    final choice = await showAppSheet<String>(
      context,
      heightFactor: 0.42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetTitle('Apri il navigatore'),
          for (final entry in [
            ('Google Maps', 'https://www.google.com/maps/dir/?api=1&destination=$destination'),
            ('Apple Maps', 'https://maps.apple.com/?daddr=$destination&dirflg=d'),
            ('Waze', 'https://waze.com/ul?ll=$destination&navigate=yes'),
          ])
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(entry.$1),
              onTap: () => Navigator.of(context).pop(entry.$2),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (choice == null) return;
    final uri = Uri.parse(choice);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il navigatore')),
        );
      }
    }
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({required this.value, required this.highlight, required this.color});

  final double? value;
  final bool highlight;
  final AppPalette color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: highlight
          ? BoxDecoration(color: color.brandSoft, borderRadius: BorderRadius.circular(8))
          : null,
      child: Text(
        Fmt.priceCompact(value),
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: value == null ? color.muted : (highlight ? color.brand : color.ink),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
