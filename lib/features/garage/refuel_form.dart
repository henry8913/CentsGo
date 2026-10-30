import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';

Future<void> showRefuelForm(
  BuildContext context, {
  required AppState state,
  Station? station,
}) {
  return showAppSheet<void>(
    context,
    heightFactor: 0.9,
    child: _RefuelForm(state: state, station: station),
  );
}

class _RefuelForm extends StatefulWidget {
  const _RefuelForm({required this.state, this.station});

  final AppState state;
  final Station? station;

  @override
  State<_RefuelForm> createState() => _RefuelFormState();
}

class _RefuelFormState extends State<_RefuelForm> {
  late final Vehicle? _vehicle = widget.state.activeVehicle;
  late final TextEditingController _liters;
  late final TextEditingController _price;
  late final TextEditingController _odometer;
  late final TextEditingController _notes;
  late DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final vehicle = _vehicle;
    final reference = widget.station?.priceFor(
          vehicle?.fuel ?? widget.state.settings.fuel,
          self: widget.state.settings.selfService,
        ) ??
        widget.state.benchmark(vehicle?.fuel ?? widget.state.settings.fuel);
    _liters = TextEditingController(text: vehicle == null ? '' : (vehicle.tankLiters * 0.8).toStringAsFixed(1));
    _price = TextEditingController(text: reference == null ? '' : reference.toStringAsFixed(3));
    _odometer = TextEditingController(text: vehicle?.odometerKm?.toStringAsFixed(0) ?? '');
    _notes = TextEditingController(text: widget.station?.brand ?? '');
  }

  @override
  void dispose() {
    _liters.dispose();
    _price.dispose();
    _odometer.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _total {
    final l = double.tryParse(_liters.text.replaceAll(',', '.')) ?? 0;
    final pr = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
    return l * pr;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final vehicle = _vehicle;
    if (vehicle == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Aggiungi prima un veicolo',
          message: 'Il diario dei rifornimenti è collegato al veicolo del Garage.',
          actionLabel: 'Chiudi',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }
    final unit = Fuels.unit(vehicle.fuel);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      children: [
        SheetTitle(
          'Nuovo rifornimento',
          subtitle: '${vehicle.displayName} · ${vehicle.fuel}',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _liters,
                label: 'Litri',
                suffix: unit,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                controller: _price,
                label: 'Prezzo',
                suffix: '€/$unit',
                decimals: 3,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _odometer,
                label: 'Km totali (facoltativo)',
                suffix: 'km',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Distributore / note'),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) setState(() => _date = picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: p.brand),
                const SizedBox(width: 10),
                Text('Data', style: TextStyle(fontSize: 13, color: p.muted)),
                const Spacer(),
                Text(Fmt.date(_date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, size: 18, color: p.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.brandSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text('Totale', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
              const Spacer(),
              Text(Fmt.euro(_total), style: Money.style(p, size: 24, color: p.brand)),
            ],
          ),
        ),
        if (widget.station != null) ...[
          const SizedBox(height: 10),
          InfoBanner(
            text: 'Stazione: ${widget.station!.brand} — ${widget.station!.comune}. Prezzo ${widget.state.settings.selfService ? 'self' : 'servito'} '
                '${Fmt.price(widget.station!.priceFor(vehicle.fuel, self: widget.state.settings.selfService))}.',
            icon: Icons.local_gas_station_outlined,
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _total <= 0
              ? null
              : () async {
                  await widget.state.addRefuel(Refuel(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    vehicleId: vehicle.id,
                    date: _date,
                    liters: double.tryParse(_liters.text.replaceAll(',', '.')) ?? 0,
                    pricePerLiter: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
                    stationName: _notes.text.trim(),
                    odometerKm: double.tryParse(_odometer.text.replaceAll(',', '.')),
                  ));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rifornimento salvato nel Garage')),
                    );
                  }
                },
          icon: const Icon(Icons.check, size: 19),
          label: const Text('Salva rifornimento'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.decimals,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final int? decimals;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }
}
