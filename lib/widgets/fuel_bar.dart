import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

IconData fuelIcon(String fuel) => switch (fuel) {
      Fuels.benzina => Icons.local_gas_station,
      Fuels.gasolio => Icons.local_shipping_outlined,
      Fuels.gpl => Icons.propane_tank_outlined,
      Fuels.metano => Icons.air,
      Fuels.hvo => Icons.eco_outlined,
      Fuels.elettrico => Icons.bolt,
      _ => Icons.local_gas_station,
    };

/// Fuel + payment-mode + brand filter bar shared by the list and the map.
class FuelBar extends StatelessWidget {
  const FuelBar({super.key, required this.state, this.compact = false});

  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = state.settings;
    return SizedBox(
      height: compact ? 44 : 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PillChip(
            label: s.fuel,
            icon: fuelIcon(s.fuel),
            selected: true,
            dense: compact,
            trailing: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
            onTap: () => _pickFuel(context),
          ),
          const SizedBox(width: 8),
          PillChip(
            label: s.selfService ? 'Self' : 'Servito',
            icon: Icons.person_outline,
            selected: false,
            dense: compact,
            onTap: () => state.setSelfService(!s.selfService),
          ),
          const SizedBox(width: 8),
          PillChip(
            label: s.brand ?? 'Tutti',
            icon: Icons.local_offer_outlined,
            selected: false,
            dense: compact,
            trailing: Icon(
              s.brand == null ? Icons.keyboard_arrow_down : Icons.close,
              size: 16,
              color: p.brand,
            ),
            onTap: () {
              if (s.brand != null) {
                state.setBrand(null);
              } else {
                _pickBrand(context);
              }
            },
          ),
          const SizedBox(width: 8),
          PillChip(
            label: '${s.radiusKm.round()} km',
            icon: Icons.radar,
            selected: false,
            dense: compact,
            onTap: () => _pickRadius(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFuel(BuildContext context) async {
    final selected = await showAppSheet<String>(
      context,
      heightFactor: 0.6,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const SheetTitle('Carburante'),
          for (final fuel in Fuels.all)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: context.palette.brandSoft,
                child: Icon(fuelIcon(fuel), size: 20, color: context.palette.brand),
              ),
              title: Text(fuel, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Prezzo in €/${Fuels.unit(fuel)}'),
              trailing: state.settings.fuel == fuel
                  ? Icon(Icons.check_circle, color: context.palette.brand)
                  : null,
              onTap: () => Navigator.of(context).pop(fuel),
            ),
        ],
      ),
    );
    if (selected != null) state.setFuel(selected);
  }

  Future<void> _pickBrand(BuildContext context) async {
    final controller = TextEditingController();
    final brands = state.catalog.brands;
    final selected = await showAppSheet<String>(
      context,
      heightFactor: 0.85,
      child: StatefulBuilder(
        builder: (context, setLocal) {
          final q = controller.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? brands
              : brands.where((b) => b.toLowerCase().contains(q)).toList();
          return Column(
            children: [
              const SheetTitle('Marchio'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: TextField(
                  controller: controller,
                  autofocus: false,
                  decoration: const InputDecoration(
                    hintText: 'Cerca marchio',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final b = filtered[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: BrandBadge(letter: b.isEmpty ? '?' : b.substring(0, 1).toUpperCase(), size: 36),
                      title: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).pop(b),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) state.setBrand(selected);
  }

  Future<void> _pickRadius(BuildContext context) async {
    var value = state.settings.radiusKm;
    final result = await showAppSheet<double>(
      context,
      heightFactor: 0.45,
      child: StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetTitle('Raggio di ricerca'),
              Text(
                '${value.round()} km',
                style: Money.style(context.palette, size: 34, color: context.palette.brand),
              ),
              const SizedBox(height: 8),
              Slider(
                value: value,
                min: 1,
                max: 60,
                divisions: 59,
                label: '${value.round()} km',
                onChanged: (v) => setLocal(() => value = v),
              ),
              const Text('Usa un raggio più ampio per confrontare più distributori.'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(value),
                child: const Text('Applica'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) state.setRadius(result);
  }
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12.5, color: p.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Convenience colour for a price inside the current result set.
Color convenienceColor(AppPalette p, double price, double min, double median, double max) {
  if (price <= min + 0.0005) return p.good;
  if (price < median - 0.0005) return p.good;
  if (price <= median + 0.02) return p.warn;
  return p.bad;
}

String convenienceLabel(double price, double min, double median, double max) {
  if (price <= min + 0.0005) return 'Il più conveniente';
  if (price < median) return 'Sotto la media';
  if (price <= median + 0.02) return 'Nella media';
  return 'Sopra la media';
}

/// Compact row describing a station's position inside a result set.
class StationValueBadge extends StatelessWidget {
  const StationValueBadge({
    super.key,
    required this.price,
    required this.min,
    required this.median,
    required this.max,
    required this.tankLiters,
  });

  final double price;
  final double min;
  final double median;
  final double max;
  final double tankLiters;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final delta = (price - min) * tankLiters;
    final color = convenienceColor(p, price, min, median, max);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        delta < 0.005 ? 'Top prezzo' : '+${delta.toStringAsFixed(2).replaceAll('.', ',')} € / pieno',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
