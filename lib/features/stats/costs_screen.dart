import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/export/csv_export.dart';
import '../../core/export/pdf_export.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

/// Dashboard of the real running costs: fuel, tolls, cost per km, monthly bars
/// and CSV export. Everything is computed on device.
class CostsScreen extends StatefulWidget {
  const CostsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  String? _lastExport;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final refuels = state.refuels;
    final trips = state.tripRecords;
    final vehicle = state.activeVehicle;
    final stats = vehicle == null ? null : state.statsFor(vehicle.id);
    final fuel = refuels.fold<double>(0, (a, r) => a + r.total);
    final tolls = trips.fold<double>(0, (a, t) => a + t.toll);
    final tripKm = trips.fold<double>(0, (a, t) => a + t.km);
    final km = (stats?.measuredKm ?? 0) + tripKm;
    final total = fuel + tolls;
    final perKm = km > 0 ? total / km : 0;

    final now = DateTime.now();
    const months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    final bars = <({String label, double value})>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final value = refuels
              .where((r) => r.date.year == month.year && r.date.month == month.month)
              .fold<double>(0, (a, r) => a + r.total) +
          trips
              .where((t) => t.createdAt.year == month.year && t.createdAt.month == month.month)
              .fold<double>(0, (a, t) => a + t.toll);
      bars.add((label: months[month.month - 1], value: value));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Costi dell\'auto')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Carburante',
                  value: Money(fuel).format(),
                  icon: Icons.local_gas_station_outlined,
                  color: p.brand,
                  caption: '${refuels.length} rifornimenti',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Pedaggi',
                  value: Money(tolls).format(),
                  icon: Icons.toll_outlined,
                  color: p.warn,
                  caption: '${trips.length} viaggi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Costo per km',
                  value: perKm.toStringAsFixed(3).replaceAll('.', ','),
                  unit: '€',
                  icon: Icons.speed,
                  color: p.good,
                  caption: km > 0 ? 'su ${Fmt.km(km)}' : 'dati insufficienti',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Totale',
                  value: Money(total).format(),
                  icon: Icons.summarize_outlined,
                  color: p.ink,
                  caption: 'carburante + pedaggi',
                ),
              ),
            ],
          ),
          const SectionTitle('Ultimi 6 mesi'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                MonthBars(entries: bars, height: 140),
                const SizedBox(height: 6),
                Text(
                  'Carburante e pedaggi registrati sul dispositivo',
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
              ],
            ),
          ),
          const SectionTitle('Esporta'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV compatibile con Excel (separatore “;”). Il file viene salvato nella cartella documenti dell\'app; il contenuto viene anche copiato negli appunti.',
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: p.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: refuels.isEmpty ? null : () => _export('rifornimenti', CsvExport.refuelsCsv(
                          refuels,
                          vehicleNames: {for (final v in state.vehicles) v.id: v.displayName},
                        )),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Rifornimenti'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.brand,
                          side: BorderSide(color: p.brand),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: trips.isEmpty ? null : () => _export('viaggi', CsvExport.tripsCsv(trips)),
                        icon: const Icon(Icons.route_outlined, size: 18),
                        label: const Text('Viaggi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.brand,
                          side: BorderSide(color: p.brand),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (refuels.isEmpty && trips.isEmpty) ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Report PDF completo'),
                  ),
                ),
                if (_lastExport != null) ...[
                  const SizedBox(height: 10),
                  InfoBanner(text: 'File salvato in $_lastExport', icon: Icons.check_circle_outline, color: p.good),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InfoBanner(
            text: 'I pedaggi dei viaggi sono stime finché le tariffe delle concessionarie non sono validate. '
                'Nessun dato lascia il dispositivo: il CSV resta locale.',
          ),
        ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      final refuels = state.refuels;
      final trips = state.tripRecords;
      final fuel = refuels.fold<double>(0, (a, r) => a + r.total);
      final tolls = trips.fold<double>(0, (a, t) => a + t.toll);
      final vehicle = state.activeVehicle;
      final stats = vehicle == null ? null : state.statsFor(vehicle.id);
      final km = (stats?.measuredKm ?? 0) + trips.fold<double>(0, (a, t) => a + t.km);
      final perKm = km > 0 ? (fuel + tolls) / km : 0;
      final bytes = await PdfExport.build(
        refuels: refuels,
        trips: trips,
        vehicleNames: {for (final v in state.vehicles) v.id: v.displayName},
        generatedAt: Fmt.date(DateTime.now()),
        fuelTotal: fuel,
        tollTotal: tolls,
        costPerKm: perKm.toStringAsFixed(3),
      );
      final path = await PdfExport.write(bytes);
      if (!mounted) return;
      setState(() => _lastExport = path);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF salvato nella cartella documenti')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF non riuscito: $e')));
    }
  }

  Future<void> _export(String name, String csv) async {
    try {
      final path = await CsvExport.writeFile(name, csv);
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      setState(() => _lastExport = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV salvato e copiato negli appunti')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export non riuscito: $e')));
    }
  }
}
