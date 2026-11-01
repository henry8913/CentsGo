import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../station/station_sheet.dart';

class _Digest extends StatelessWidget {
  const _Digest({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final deadlines = <(Vehicle, VehicleDeadline)>[];
    for (final vehicle in state.vehicles) {
      for (final deadline in vehicle.deadlines) {
        if (deadline.daysLeft(now) <= 30) deadlines.add((vehicle, deadline));
      }
    }
    deadlines.sort((a, b) => a.$2.daysLeft(now).compareTo(b.$2.daysLeft(now)));
    final drops = state.alerts.where((a) => a.isDrop).length;
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
              Icon(Icons.insights, size: 18, color: p.brand),
              const SizedBox(width: 6),
              Text('Riepilogo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${state.favorites.length} preferiti · $drops cali di prezzo · ${deadlines.length} scadenze entro 30 giorni',
            style: TextStyle(fontSize: 12.5, color: p.ink),
          ),
          if (deadlines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final entry in deadlines.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.$2.isOverdue(now) ? Icons.error_outline : Icons.schedule,
                      size: 14,
                      color: entry.$2.isOverdue(now) ? p.bad : p.warn,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.$1.displayName} · ${entry.$2.kind}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: p.ink),
                      ),
                    ),
                    Text(
                      entry.$2.isOverdue(now)
                          ? 'scaduta'
                          : 'tra ${entry.$2.daysLeft(now)} gg',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: entry.$2.isOverdue(now) ? p.bad : p.warn,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avvisi prezzo'),
        actions: [
          if (state.alerts.isNotEmpty)
            IconButton(
              tooltip: 'Cancella avvisi',
              onPressed: state.clearAlerts,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final favorites = <Station>[];
          for (final id in state.favorites) {
            final station = state.stationById(id);
            if (station != null) favorites.add(station);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              _Digest(state: state),
              const SizedBox(height: 10),
              const InfoBanner(
                text: 'CentsGo confronta il prezzo dei preferiti ad ogni aggiornamento e registra la variazione. '
                    'Gli avvisi restano sul dispositivo.',
                icon: Icons.notifications_active_outlined,
              ),
              const SectionTitle('Variazioni rilevate'),
              if (state.alerts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    state.favorites.isEmpty
                        ? 'Aggiungi un distributore ai preferiti (icona cuore nella scheda) per ricevere gli avvisi di variazione.'
                        : 'Nessuna variazione registrata: i prezzi dei tuoi preferiti sono stabili.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: p.muted),
                  ),
                )
              else
                for (final alert in state.alerts.reversed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (alert.isDrop ? p.good : p.bad).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            alert.isDrop ? Icons.trending_down : Icons.trending_up,
                            color: alert.isDrop ? p.good : p.bad,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.stationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                              ),
                              Text(
                                '${alert.fuel} ${alert.selfService ? 'self' : 'servito'} · '
                                '${Fmt.price(alert.from)} → ${Fmt.price(alert.to)} · ${Fmt.relative(alert.at)}',
                                style: TextStyle(fontSize: 11.5, color: p.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.sign(alert.delta),
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: alert.isDrop ? p.good : p.bad,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SectionTitle('Preferiti'),
              if (favorites.isEmpty)
                EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Nessun preferito',
                  message: 'Apri la scheda di un distributore e tocca il cuore per monitorarlo.',
                )
              else
                for (final st in favorites)
                  Builder(
                    builder: (context) {
                      final price = st.priceFor(state.settings.fuel, self: state.settings.selfService);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: BrandBadge(letter: st.initial),
                        title: Text(st.brand, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${st.comune} (${st.prov}) · ${Fmt.relative(st.updatedAt)}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (price != null)
                              Text(Fmt.price(price), style: PriceType.style(p, size: 15, color: p.good)),
                            IconButton(
                              icon: Icon(Icons.favorite, color: p.bad, size: 18),
                              onPressed: () => state.toggleFavorite(st),
                            ),
                          ],
                        ),
                        onTap: () => showStationSheet(context, state: state, station: st),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
