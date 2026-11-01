import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/net/geocoding_service.dart';
import '../../models/address.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';

/// Editor for via / civico / CAP / città with **offline** autocomplete on the
/// bundled comuni, and an explicit "Cerca" that calls Nominatim once.
Future<Address?> editAddress(
  BuildContext context, {
  required AppState state,
  String title = 'Indirizzo',
  Address? initial,
}) {
  return showAppSheet<Address>(
    context,
    heightFactor: 0.95,
    child: _AddressSheet(state: state, title: title, initial: initial),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.state, required this.title, this.initial});

  final AppState state;
  final String title;
  final Address? initial;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _street = TextEditingController(text: widget.initial?.street ?? '');
  late final _number = TextEditingController(text: widget.initial?.houseNumber ?? '');
  late final _postcode = TextEditingController(text: widget.initial?.postcode ?? '');
  late final _city = TextEditingController(text: widget.initial?.city ?? '');
  String _province = '';
  String? _cityError;
  List<GeocodeResult> _results = const [];
  bool _searching = false;
  bool _searched = false;
  String? _info;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.city.isNotEmpty) {
      final comune = widget.state.addresses.comuneByName(initial.city, province: initial.province.isEmpty ? null : initial.province);
      _province = comune?.province ?? initial.province;
    }
  }

  @override
  void dispose() {
    _street.dispose();
    _number.dispose();
    _postcode.dispose();
    _city.dispose();
    super.dispose();
  }

  Address get _draft => Address(
        street: _street.text,
        houseNumber: _number.text,
        postcode: _postcode.text,
        city: _city.text,
        province: _province,
      ).normalized();

  Future<void> _search() async {
    final draft = _draft;
    if (draft.city.isEmpty) {
      setState(() => _cityError = 'Indica la città');
      return;
    }
    setState(() {
      _cityError = null;
      _searching = true;
      _info = null;
      _searched = false;
    });
    final results = await widget.state.geocoder.search(draft);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _results = results;
      if (results.isEmpty) {
        _info = 'Nessun risultato. Controlla i dati o riprova quando sei online.';
      }
    });
  }

  void _applyComune(String name) {
    final comune = widget.state.addresses.comuneByName(name);
    setState(() {
      _city.text = name;
      _province = comune?.province ?? _province;
      _cityError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final suggestions = _city.text.trim().length < 2
        ? const <dynamic>[]
        : widget.state.addresses.searchComuni(_city.text, province: _province.isEmpty ? null : _province, limit: 5);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      children: [
        SheetTitle(widget.title, subtitle: 'Via, civico, CAP e città'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _Field(controller: _street, label: 'Via / piazza', hint: 'Via Roma'),
            ),
            const SizedBox(width: 10),
            Expanded(child: _Field(controller: _number, label: 'Civico', hint: '12')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _Field(controller: _postcode, label: 'CAP', hint: '20121', keyboard: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _Field(
                controller: _city,
                label: 'Città',
                hint: 'Milano',
                error: _cityError,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                for (final comune in suggestions.take(5))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18),
                    title: Text(comune.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${comune.province} · ${comune.region}', style: const TextStyle(fontSize: 11)),
                    onTap: () => _applyComune(comune.name),
                  ),
              ],
            ),
          ),
        if (_province.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 16, color: p.muted),
                const SizedBox(width: 6),
                Text('Provincia ${_province.toUpperCase()}', style: TextStyle(fontSize: 12, color: p.muted)),
                const Spacer(),
                if (!widget.state.addresses.isValidPostcode(_postcode.text) && _postcode.text.isNotEmpty)
                  Text('CAP da controllare', style: TextStyle(fontSize: 11, color: p.warn)),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: _searching ? null : _search,
          icon: _searching
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.search, size: 19),
          label: Text(_searching ? 'Cerco…' : 'Cerca indirizzo'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            final draft = _draft;
            if (draft.city.isEmpty) {
              setState(() => _cityError = 'Indica la città');
              return;
            }
            final place = widget.state.catalog.placeByName(draft.city);
            Navigator.of(context).pop(
              draft.copyWith(lat: place?.position.latitude, lon: place?.position.longitude),
            );
          },
          icon: const Icon(Icons.location_city, size: 18),
          label: const Text('Usa solo la città (offline)'),
        ),
        if (_info != null) ...[
          const SizedBox(height: 8),
          InfoBanner(text: _info!, icon: Icons.info_outline, color: p.warn),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 6),
          const SectionTitle('Risultati'),
          for (final result in _results)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: ListTile(
                leading: Icon(Icons.pin_drop_outlined, color: p.brand, size: 20),
                title: Text(
                  result.address.oneLine.isEmpty ? result.label : result.address.oneLine,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(result.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.of(context).pop(result.address),
              ),
            ),
          Text(
            'Ricerca con Nominatim (© OpenStreetMap contributors). Risultati in cache sul dispositivo.',
            style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.4),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Suggerimenti città offline; la ricerca del civico richiede la rete e una richiesta al secondo.',
          style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboard,
    this.error,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final String? error;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint, errorText: error),
      ),
    );
  }
}
