import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';

/// Searchable place selector built on the comuni derived from the station
/// registry, so every selectable place has a real coordinate.
Future<Place?> pickPlace(
  BuildContext context,
  AppState state, {
  String title = 'Dove ti trovi?',
  bool autoDetect = true,
}) {
  return showAppSheet<Place>(
    context,
    heightFactor: 0.88,
    child: _PlaceSheet(state: state, title: title, autoDetect: autoDetect),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.state, required this.title, required this.autoDetect});

  final AppState state;
  final String title;
  final bool autoDetect;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _controller = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = _query.isEmpty ? widget.state.catalog.places.take(40).toList() : widget.state.catalog.searchPlaces(_query);
    return Column(
      children: [
        SheetTitle(widget.title, subtitle: 'Comune, provincia o posizione GPS'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: TextField(
            controller: _controller,
            autofocus: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Es. Milano, Napoli, Torino',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (widget.autoDetect)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await widget.state.useGps();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Usa la mia posizione'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.brand,
                      side: BorderSide(color: p.brand),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: results.length,
            separatorBuilder: (_, __) => Divider(color: p.border, height: 1),
            itemBuilder: (context, i) {
              final place = results[i];
              final cheapest = widget.state.catalog.bestInComune(
                place.name,
                widget.state.settings.fuel,
                widget.state.settings.selfService,
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.brandSoft,
                  child: Icon(Icons.place_outlined, size: 19, color: p.brand),
                ),
                title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(place.prov),
                trailing: cheapest == null
                    ? null
                    : Text(
                        'da €${cheapest.price.toStringAsFixed(3).replaceAll('.', ',')}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.good),
                      ),
                onTap: () => Navigator.of(context).pop(place),
              );
            },
          ),
        ),
      ],
    );
  }
}
