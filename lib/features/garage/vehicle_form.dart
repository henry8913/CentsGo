import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../data/vehicle_catalog.dart';
import '../../models/settings.dart';
import '../../models/vehicle.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/vehicle_art.dart';

Future<void> openVehicleForm(BuildContext context, AppState state, {Vehicle? vehicle}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VehicleFormScreen(state: state, vehicle: vehicle),
    ),
  );
}

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, required this.state, this.vehicle});

  final AppState state;
  final Vehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _nickname = TextEditingController();
  final _plate = TextEditingController();
  final _year = TextEditingController();
  final _tank = TextEditingController();
  final _consumption = TextEditingController();

  VehicleType _type = VehicleType.berlina;
  VehicleColor _color = VehicleColor.arancio;
  String _fuel = Fuels.benzina;
  String? _brand;
  String? _model;

  DateTime? _insurance;
  DateTime? _bollo;
  DateTime? _revision;

  VehicleCatalog? _catalog;

  bool get isTwoWheeler => _type == VehicleType.moto || _type == VehicleType.scooter;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _nickname.text = v.nickname;
      _plate.text = v.plate;
      _year.text = '${v.year}';
      _tank.text = v.tankLiters.toStringAsFixed(1);
      _consumption.text = v.consumption.toStringAsFixed(1);
      _type = v.type;
      _color = v.color;
      _fuel = v.fuel;
      _brand = v.brand.isEmpty ? null : v.brand;
      _model = v.model.isEmpty ? null : v.model;
      for (final d in v.deadlines) {
        switch (d.kind.toLowerCase()) {
          case 'assicurazione rca':
            _insurance = d.due;
          case 'bollo auto':
            _bollo = d.due;
          case 'revisione':
            _revision = d.due;
        }
      }
    } else {
      final year = DateTime.now().year;
      _year.text = '$year';
      _tank.text = _type.defaultTank.toStringAsFixed(0);
      _consumption.text = '6.5';
    }
    VehicleCatalog.load().then((c) {
      if (mounted) {
        setState(() {
          _catalog = c;
          final brand = _brand;
          if (brand != null && _catalog?.forType(isTwoWheeler).containsKey(brand) != true) {
            _brand = null;
            _model = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _plate.dispose();
    _year.dispose();
    _tank.dispose();
    _consumption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brands = _catalog?.brands(isTwoWheeler) ?? const <String>[];
    final models = _brand == null ? const <String>[] : (_catalog?.forType(isTwoWheeler)[_brand] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Nuovo veicolo' : 'Modifica veicolo'),
        actions: [
          if (widget.vehicle != null)
            IconButton(
              tooltip: 'Elimina',
              icon: Icon(Icons.delete_outline, color: p.bad),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminare il veicolo?'),
                    content: const Text('Verranno eliminati anche i rifornimenti registrati per questo veicolo.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.state.removeVehicle(widget.vehicle!.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Center(child: VehicleArt(type: _type, color: _color, height: 120)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _nickname.text.isEmpty ? 'La tua ${_type.label.toLowerCase()}' : _nickname.text,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink),
            ),
          ),
          const SectionTitle('Tipo di veicolo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in VehicleType.values)
                PillChip(
                  label: type.label,
                  selected: _type == type,
                  dense: true,
                  onTap: () => setState(() {
                    _type = type;
                    _tank.text = type.defaultTank.toStringAsFixed(0);
                    if (!_catalog!.forType(isTwoWheeler).containsKey(_brand)) {
                      _brand = null;
                      _model = null;
                    }
                  }),
                ),
            ],
          ),
          const SectionTitle('Colore'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in VehicleColor.values)
                GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(color.value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == color ? p.brand : p.border,
                        width: _color == color ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SectionTitle('Dati del veicolo'),
          _Field(
            controller: _nickname,
            label: 'Soprannome (facoltativo)',
            hint: 'Es. Panda di casa',
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  label: 'Marca',
                  value: _brand,
                  items: brands,
                  onChanged: (v) => setState(() {
                    _brand = v;
                    _model = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown(
                  label: 'Modello',
                  value: _model,
                  items: models,
                  onChanged: (v) => setState(() => _model = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _year,
                  label: 'Anno',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _plate,
                  label: 'Targa',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                ),
              ),
            ],
          ),
          const SectionTitle('Alimentazione'),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fuel in [...Fuels.all, Fuels.elettrico])
                PillChip(
                  label: fuel,
                  selected: _fuel == fuel,
                  dense: true,
                  onTap: () => setState(() => _fuel = fuel),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _tank,
                  label: _fuel == Fuels.elettrico ? 'Batteria (kWh)' : 'Serbatoio (L)',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _consumption,
                  label: _fuel == Fuels.elettrico ? 'Consumo (kWh/100)' : 'Consumo (L/100)',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SectionTitle('Scadenze'),
          _DateRow(
            label: 'Assicurazione RCA',
            value: _insurance,
            onPick: () => _pickDate(_insurance, (d) => setState(() => _insurance = d)),
            onClear: () => setState(() => _insurance = null),
          ),
          _DateRow(
            label: 'Bollo auto',
            value: _bollo,
            onPick: () => _pickDate(_bollo, (d) => setState(() => _bollo = d)),
            onClear: () => setState(() => _bollo = null),
          ),
          _DateRow(
            label: 'Revisione',
            value: _revision,
            onPick: () => _pickDate(_revision, (d) => setState(() => _revision = d)),
            onClear: () => setState(() => _revision = null),
          ),
          const SizedBox(height: 16),
          InfoBanner(
            text: 'Le scadenze restano solo sul dispositivo. CentsGo mostra l\'avviso in app quando mancano '
                '${30} giorni: nessuna notifica viene inviata a servizi esterni.',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: Text(widget.vehicle == null ? 'Aggiungi al garage' : 'Salva modifiche'),
          ),
          if (widget.vehicle != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await widget.state.removeVehicle(widget.vehicle!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text('Elimina veicolo', style: TextStyle(color: p.bad)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Scegli la scadenza',
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    final state = widget.state;
    final tank = double.tryParse(_tank.text.replaceAll(',', '.')) ?? _type.defaultTank;
    final consumption = double.tryParse(_consumption.text.replaceAll(',', '.')) ?? 6.5;
    final year = int.tryParse(_year.text) ?? DateTime.now().year;
    final deadlines = <VehicleDeadline>[
      if (_insurance != null) VehicleDeadline(kind: 'Assicurazione RCA', due: _insurance!),
      if (_bollo != null) VehicleDeadline(kind: 'Bollo auto', due: _bollo!),
      if (_revision != null) VehicleDeadline(kind: 'Revisione', due: _revision!),
    ];
    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nickname: _nickname.text.trim(),
      type: _type,
      brand: _brand ?? '',
      model: _model ?? '',
      year: year,
      plate: _plate.text.trim().toUpperCase(),
      fuel: _fuel,
      tankLiters: tank,
      consumption: consumption,
      color: _color,
      deadlines: deadlines,
      odometerKm: widget.vehicle?.odometerKm,
    );
    if (widget.vehicle == null) {
      await state.addVehicle(vehicle);
      await state.setActiveVehicle(vehicle.id);
    } else {
      await state.updateVehicle(vehicle);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboard,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in items)
            DropdownMenuItem<String>(
              value: item,
              child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 18, color: p.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12.5, color: p.muted)),
                Text(
                  value == null ? 'Da impostare' : Fmt.date(value!),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                ),
              ],
            ),
          ),
          if (value != null)
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
          TextButton(onPressed: onPick, child: Text(value == null ? 'Aggiungi' : 'Cambia')),
        ],
      ),
    );
  }
}
