import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/launcher.dart';
import '../../models/vehicle.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';
import '../../widgets/vehicle_art.dart';
import '../settings/settings_screen.dart';
import 'refuel_form.dart';
import 'vehicle_form.dart';

class GarageTab extends StatelessWidget {
  const GarageTab({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final vehicles = state.vehicles;
    final vehicle = state.activeVehicle;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth > 680 ? (constraints.maxWidth - 640) / 2 : 20.0;
          return ListView(
        padding: EdgeInsets.fromLTRB(side, 14, side, 24),
        children: [
          ScreenTitle(
            title: 'Garage',
            subtitle: 'Veicoli, scadenze e spese',
            trailing: Row(
              children: [
                RoundIconButton(
                  icon: Icons.add,
                  filled: true,
                  tooltip: 'Aggiungi veicolo',
                  onTap: () => openVehicleForm(context, state),
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Impostazioni',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SettingsScreen(state: state)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (vehicles.isEmpty)
            _NoVehicle(state: state)
          else ...[
            if (vehicles.length > 1)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final v in vehicles)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PillChip(
                          label: v.displayName,
                          selected: v.id == vehicle?.id,
                          dense: true,
                          icon: v.type == VehicleType.moto || v.type == VehicleType.scooter
                              ? Icons.two_wheeler
                              : Icons.directions_car_filled,
                          onTap: () => state.setActiveVehicle(v.id),
                        ),
                      ),
                  ],
                ),
              ),
            if (vehicles.length > 1) const SizedBox(height: 12),
            if (vehicle != null) ...[
              _VehicleHero(vehicle: vehicle, state: state),
              const SizedBox(height: 14),
              _StatsRow(vehicle: vehicle, state: state),
              if (vehicle.deadlines.isNotEmpty) ...[
                const SectionTitle('Scadenze principali'),
                for (final d in vehicle.deadlines)
                  _DeadlineCard(deadline: d, vehicle: vehicle, state: state),
              ],
              const SectionTitle('Spese ultimi mesi'),
              _MonthlyCard(vehicle: vehicle, state: state),
              const SectionTitle('Ultimi rifornimenti'),
              _RefuelList(vehicle: vehicle, state: state),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showRefuelForm(context, state: state),
                icon: const Icon(Icons.local_gas_station_outlined, size: 19),
                label: const Text('Registra rifornimento'),
              ),
              const SizedBox(height: 18),
              const SectionTitle('Servizi utili'),
              _ServicesRow(vehicle: vehicle),
            ],
          ],
        ],
          );
        },
      ),
    );
  }
}

class _NoVehicle extends StatelessWidget {
  const _NoVehicle({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          VehicleArt(type: VehicleType.berlina, color: VehicleColor.arancio, height: 96),
          const SizedBox(height: 10),
          Text(
            'Il tuo garage è vuoto',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Aggiungi l\'auto o la moto: CentsGo calcola il costo del pieno con i prezzi della tua zona, '
            'tiene il diario dei rifornimenti e ti avvisa prima delle scadenze.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: p.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => openVehicleForm(context, state),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Aggiungi veicolo'),
          ),
        ],
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle, required this.state});

  final Vehicle vehicle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final price = state.benchmark(vehicle.fuel);
    final full = price == null ? null : vehicle.tankCost(price);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.brandSoft, p.surface],
        ),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.ink),
                    ),
                    Text(
                      ['${vehicle.brand} ${vehicle.model}', '${vehicle.year}', vehicle.fuel]
                          .where((e) => e.trim().isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Modifica',
                onPressed: () => openVehicleForm(context, state, vehicle: vehicle),
                icon: Icon(Icons.edit_outlined, size: 20, color: p.brand),
              ),
            ],
          ),
          VehicleArt(type: vehicle.type, color: vehicle.color, height: 104),
          const SizedBox(height: 4),
          _Plate(text: vehicle.plate.isEmpty ? 'CENTSO' : vehicle.plate),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.local_gas_station_outlined,
                  label: 'Pieno stimato',
                  value: full == null ? '—' : Fmt.euro(full),
                  caption: price == null ? 'prezzo non disponibile' : 'a ${Fmt.price(price)}/L in zona',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.speed,
                  label: 'Autonomia',
                  value: '${vehicle.rangeKm.round()} km',
                  caption: '${vehicle.tankLiters.round()} L · ${vehicle.consumption.toStringAsFixed(1).replaceAll('.', ',')} L/100',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1C4FA1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(7), bottomLeft: Radius.circular(7)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('I', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
                Text('★', style: TextStyle(color: Colors.white, fontSize: 8)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F5),
              borderRadius: BorderRadius.only(topRight: Radius.circular(7), bottomRight: Radius.circular(7)),
            ),
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppFonts.mono,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 2,
                color: Color(0xFF1B1F22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value, required this.caption});

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: p.brand),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 11, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: Money.style(p, size: 16)),
          Text(caption, style: TextStyle(fontSize: 10.5, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.vehicle, required this.state});

  final Vehicle vehicle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = state.statsFor(vehicle.id);
    final consumption = stats.measuredConsumption ?? vehicle.consumption;
    final price = state.benchmark(vehicle.fuel);
    final costPerKm = price == null ? vehicle.costPerKm(1.95) : vehicle.costPerKm(price);
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Spese del mese',
            value: Fmt.euro(stats.monthSpend),
            icon: Icons.receipt_long_outlined,
            color: p.brand,
            caption: '${Fmt.liters(stats.monthLiters)} · ${stats.refuels} rif.',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Consumo medio',
            value: consumption.toStringAsFixed(1).replaceAll('.', ','),
            unit: 'L/100',
            icon: Icons.thermostat,
            color: p.good,
            caption: stats.measuredConsumption == null ? 'dichiarato' : 'misurato',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Costo per km',
            value: costPerKm.toStringAsFixed(3).replaceAll('.', ','),
            unit: '€',
            icon: Icons.savings_outlined,
            color: p.warn,
            caption: 'stimato',
          ),
        ),
      ],
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.deadline, required this.vehicle, required this.state});

  final VehicleDeadline deadline;
  final Vehicle vehicle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = deadline.daysLeft();
    final overdue = days < 0;
    final soon = days <= deadline.reminderDays;
    final color = overdue ? p.bad : (soon ? p.warn : p.good);
    final icon = switch (deadline.kind.toLowerCase()) {
      'assicurazione rca' || 'assicurazione' => Icons.shield_outlined,
      'bollo auto' || 'bollo' => Icons.receipt_long_outlined,
      'revisione' => Icons.build_circle_outlined,
      _ => Icons.event_outlined,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deadline.kind, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
                Text(
                  '${Fmt.date(deadline.due)}  ·  ${overdue ? 'scaduta da ${-days} gg' : (days == 0 ? 'oggi' : 'tra $days gg')}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifica veicolo',
            onPressed: () => openVehicleForm(context, state, vehicle: vehicle),
            icon: Icon(Icons.edit_outlined, size: 18, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.vehicle, required this.state});

  final Vehicle vehicle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final refuels = state.refuelsFor(vehicle.id);
    final now = DateTime.now();
    final entries = <({String label, double value})>[];
    const names = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final total = refuels
          .where((r) => r.date.year == month.year && r.date.month == month.month)
          .fold<double>(0, (a, r) => a + r.total);
      entries.add((label: names[month.month - 1], value: total));
    }
    final stats = state.statsFor(vehicle.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          MonthBars(entries: entries, height: 130),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Totale ${Fmt.euro(stats.totalSpend)}', style: TextStyle(fontSize: 12, color: p.muted)),
              const Spacer(),
              Text('Prezzo medio ${Fmt.price(stats.avgPrice)}', style: TextStyle(fontSize: 12, color: p.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefuelList extends StatelessWidget {
  const _RefuelList({required this.vehicle, required this.state});

  final Vehicle vehicle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final refuels = state.refuelsFor(vehicle.id).take(4).toList();
    if (refuels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Text(
          'Nessun rifornimento registrato. Aggiungine uno dalla scheda di un distributore o dal pulsante qui sotto.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: p.muted),
        ),
      );
    }
    return Column(
      children: [
        for (final r in refuels)
          Dismissible(
            key: ValueKey(r.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: p.bad.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.delete_outline, color: p.bad),
            ),
            onDismissed: (_) => state.removeRefuel(r.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_gas_station_outlined, size: 18, color: p.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.stationName.isEmpty ? 'Rifornimento' : r.stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink),
                        ),
                        Text(
                          '${Fmt.date(r.date)} · ${Fmt.liters(r.liters)} · ${Fmt.price(r.pricePerLiter)}/L',
                          style: TextStyle(fontSize: 11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(Fmt.euro(r.total), style: Money.style(p, size: 15)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ServicesRow extends StatelessWidget {
  const _ServicesRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final query = Uri.encodeComponent('${vehicle.brand} ${vehicle.model}');
    final links = [
      ('Olio motore', 'https://www.google.com/search?q=olio+motore+$query'),
      ('Accessori', 'https://www.google.com/search?q=accessori+$query'),
      ('Assistenza', 'https://www.google.com/search?q=assistenza+$query'),
      ('Pneumatici', 'https://www.google.com/search?q=pneumatici+$query'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links)
          PillChip(
            label: link.$1,
            selected: false,
            dense: true,
            icon: Icons.open_in_new,
            onTap: () => openExternal(context, link.$2),
          ),
      ],
    );
  }
}
