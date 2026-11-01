import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/fuel_units.dart';
import '../../core/units.dart';
import '../../models/settings.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';

enum _EntryMode { liters, amount }

Future<void> showRefuelForm(
  BuildContext context, {
  required AppState state,
  Station? station,
}) {
  return showAppSheet<void>(
    context,
    heightFactor: 0.94,
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
  late String _fuel = _vehicle?.fuel ?? widget.state.settings.fuel;
  late bool _self = widget.state.settings.selfService;
  late Station? _station = widget.station;

  final _liters = TextEditingController();
  final _price = TextEditingController();
  final _amount = TextEditingController();
  final _odometer = TextEditingController();

  _EntryMode _mode = _EntryMode.liters;
  bool _fullTank = true;
  bool _manualPrice = false;
  DateTime _date = DateTime.now();
  bool _updating = false;

  String get _unit => FuelUnits.volume(_fuel);

  @override
  void initState() {
    super.initState();
    final v = _vehicle;
    if (v != null) {
      _odometer.text = v.odometerKm?.toStringAsFixed(0) ?? '';
      _liters.text = (v.tankLiters * 0.8).toStringAsFixed(1).replaceAll('.', ',');
    }
    final reference = _station?.priceFor(_fuel, self: _self) ?? widget.state.benchmark(_fuel, self: _self);
    if (reference != null) {
      _price.text = reference.toStringAsFixed(3).replaceAll('.', ',');
    }
    _syncFromLiters();
  }

  @override
  void dispose() {
    _liters.dispose();
    _price.dispose();
    _amount.dispose();
    _odometer.dispose();
    super.dispose();
  }

  double get _priceValue => double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
  double get _litersValue => double.tryParse(_liters.text.replaceAll(',', '.')) ?? 0;
  double get _amountValue => double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
  double get _total => _mode == _EntryMode.liters ? _litersValue * _priceValue : _amountValue;

  void _syncFromLiters() {
    _updating = true;
    final total = _litersValue * _priceValue;
    _amount.text = total > 0 ? total.toStringAsFixed(2).replaceAll('.', ',') : '';
    _updating = false;
  }

  void _syncFromAmount() {
    if (_priceValue <= 0) return;
    _updating = true;
    _liters.text = (_amountValue / _priceValue).toStringAsFixed(2).replaceAll('.', ',');
    _updating = false;
  }

  void _syncFromPrice() {
    if (_priceValue <= 0) return;
    _updating = true;
    if (_mode == _EntryMode.liters) {
      _amount.text = (_litersValue * _priceValue).toStringAsFixed(2).replaceAll('.', ',');
    } else {
      _liters.text = (_amountValue / _priceValue).toStringAsFixed(2).replaceAll('.', ',');
    }
    _updating = false;
  }

  void _applyStation(Station station) {
    setState(() {
      _station = station;
      final price = station.priceFor(_fuel, self: _self);
      if (price != null) {
        _price.text = price.toStringAsFixed(3).replaceAll('.', ',');
        _manualPrice = false;
        _syncFromPrice();
      }
    });
  }

  Future<void> _pickStation() async {
    final selected = await showAppSheet<Station>(
      context,
      heightFactor: 0.88,
      child: _StationPicker(state: widget.state, fuel: _fuel, self: _self, initial: _station),
    );
    if (selected != null) _applyStation(selected);
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

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      children: [
        SheetTitle('Nuovo rifornimento', subtitle: '${vehicle.displayName} · ${vehicle.fuel}'),
        const SizedBox(height: 12),
        _Segmented(
          options: ['Quantità ($_unit)', 'Importo €'],
          selected: _mode == _EntryMode.liters ? 0 : 1,
          onChanged: (i) => setState(() {
            _mode = i == 0 ? _EntryMode.liters : _EntryMode.amount;
          }),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _liters,
                label: 'Quantità',
                suffix: _unit,
                emphasised: _mode == _EntryMode.liters,
                onChanged: (_) {
                  if (_updating) return;
                  _syncFromLiters();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                controller: _amount,
                label: 'Totale',
                suffix: '€',
                emphasised: _mode == _EntryMode.amount,
                onChanged: (_) {
                  if (_updating) return;
                  _syncFromAmount();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        _NumberField(
          controller: _price,
          label: 'Prezzo al $_unit',
          suffix: '€/$_unit',
          onChanged: (_) {
            if (_updating) return;
            _manualPrice = true;
            _syncFromPrice();
            setState(() {});
          },
        ),
        _Segmented(
          options: const ['Self service', 'Servito'],
          selected: _self ? 0 : 1,
          onChanged: (i) => setState(() {
            _self = i == 0;
            final stationPrice = _station?.priceFor(_fuel, self: _self);
            if (stationPrice != null && !_manualPrice) {
              _price.text = stationPrice.toStringAsFixed(3).replaceAll('.', ',');
              _syncFromPrice();
            }
          }),
        ),
        const SizedBox(height: 10),
        _StationRow(
          station: _station,
          fuel: _fuel,
          self: _self,
          manual: _manualPrice,
          onPick: _pickStation,
          onClear: () => setState(() => _station = null),
        ),
        const SizedBox(height: 12),
        _NumberField(
          controller: _odometer,
          label: 'Km totali (facoltativo)',
          suffix: 'km',
        ),
        Material(
          color: p.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fullTank,
            onChanged: (v) => setState(() => _fullTank = v),
            title: const Text('Pieno completo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _fullTank
                  ? 'Il consumo si misura tra due pieni completi'
                  : 'Rifornimento parziale: non usato come riferimento per i consumi',
              style: const TextStyle(fontSize: 11.5),
            ),
            ),
          ),
        ),
        _DateRow(
          date: _date,
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Totale speso', style: TextStyle(fontSize: 12, color: p.muted)),
                  Text(
                    Fmt.price(_priceValue),
                    style: PriceType.style(p, size: 13, color: p.muted),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                Fmt.euro(_total),
                style: PriceType.style(p, size: 24, color: p.brand),
              ),
            ],
          ),
        ),
        if (_mode == _EntryMode.amount && _priceValue > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${Fmt.liters(_litersValue)} a ${Fmt.price(_priceValue)}/$_unit',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
        if (_manualPrice) ...[
          const SizedBox(height: 8),
          const InfoBanner(
            icon: Icons.edit_outlined,
            text: 'Prezzo inserito a mano: non coincide con il dato MIMIT.',
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _litersValue <= 0 || _priceValue <= 0
              ? null
              : () async {
                  await widget.state.addRefuel(Refuel(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    vehicleId: vehicle.id,
                    date: _date,
                    liters: _mode == _EntryMode.liters ? _litersValue : _amountValue / _priceValue,
                    pricePerLiter: _priceValue,
                    stationId: _station?.id,
                    stationName: _station?.brand ?? '',
                    odometerKm: double.tryParse(_odometer.text.replaceAll(',', '.')),
                    fullTank: _fullTank,
                    manualPrice: _manualPrice,
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

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.fuel,
    required this.self,
    required this.manual,
    required this.onPick,
    required this.onClear,
  });

  final Station? station;
  final String fuel;
  final bool self;
  final bool manual;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(Icons.local_gas_station_outlined, size: 19, color: p.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station?.brand ?? 'Distributore (facoltativo)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink),
                    ),
                    Text(
                      station == null
                          ? 'Associa la spesa a un impianto MIMIT'
                          : '${station!.comune} · ${manual ? 'prezzo manuale' : 'prezzo MIMIT ${self ? 'self' : 'servito'}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                  ],
                ),
              ),
              if (station != null)
                IconButton(
                  tooltip: 'Rimuovi',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              else
                Icon(Icons.chevron_right, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationPicker extends StatefulWidget {
  const _StationPicker({
    required this.state,
    required this.fuel,
    required this.self,
    this.initial,
  });

  final AppState state;
  final String fuel;
  final bool self;
  final Station? initial;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = _query.trim().length < 2
        ? widget.state.nearby(limit: 12)
        : widget.state.catalog
            .searchStations(_query, limit: 25)
            .map((s) => StationHit(
                  station: s,
                  distanceKm: 0,
                  price: s.priceFor(widget.fuel, self: widget.self) ?? 0,
                  selfService: widget.self,
                ))
            .where((h) => h.price > 0)
            .toList();

    return Column(
      children: [
        SheetTitle(
          'Scegli il distributore',
          subtitle: _query.trim().length < 2 ? 'I più vicini a te' : 'Risultati per "$_query"',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Nome, marchio, comune o indirizzo',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nessun distributore',
                  message: 'Prova con il nome del marchio o della città.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => Divider(color: p.border, height: 1),
                  itemBuilder: (context, i) {
                    final hit = results[i];
                    final price = hit.station.priceFor(widget.fuel, self: widget.self);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: BrandBadge(letter: hit.station.initial, size: 36),
                      title: Text(hit.station.brand, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${hit.station.comune} · ${hit.station.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: price == null
                          ? Text('n/d', style: TextStyle(fontSize: 11.5, color: p.muted))
                          : Text(
                              Fmt.price(price),
                              style: PriceType.style(p, size: 14, color: p.good),
                            ),
                      onTap: () => Navigator.of(context).pop(hit.station),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, required this.onChanged});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selected ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == selected
                        ? [BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                      color: i == selected ? p.ink : p.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.onChanged,
    this.emphasised = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String>? onChanged;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: emphasised ? p.brandSoft : p.surface,
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onPick,
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
            Text(Fmt.date(date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 18, color: p.muted),
          ],
        ),
      ),
    );
  }
}
