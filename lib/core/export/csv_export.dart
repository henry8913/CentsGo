import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/trip_record.dart';
import '../../models/vehicle.dart';

/// CSV export of the garage and trip data. No plugin: the file is written in
/// the app documents folder and its content is returned for sharing.
class CsvExport {
  static const _separator = ';';

  static String refuelsCsv(List<Refuel> refuels, {Map<String, String> vehicleNames = const {}}) {
    final buffer = StringBuffer()
      ..writeln('data${_separator}veicolo${_separator}distributore${_separator}litri${_separator}prezzo_L${_separator}totale${_separator}km${_separator}pieno');
    final sorted = [...refuels]..sort((a, b) => a.date.compareTo(b.date));
    for (final r in sorted) {
      buffer.writeln([
        _date(r.date),
        _cell(vehicleNames[r.vehicleId] ?? r.vehicleId),
        _cell(r.stationName),
        r.liters.toStringAsFixed(2),
        r.pricePerLiter.toStringAsFixed(3),
        r.total.toStringAsFixed(2),
        r.odometerKm?.toStringAsFixed(0) ?? '',
        r.fullTank ? 'si' : 'no',
      ].join(_separator));
    }
    return buffer.toString();
  }

  static String tripsCsv(List<TripRecord> trips) {
    final buffer = StringBuffer()
      ..writeln('data${_separator}partenza${_separator}arrivo${_separator}km${_separator}minuti${_separator}carburante${_separator}pedaggio${_separator}parcheggio${_separator}totale${_separator}persone${_separator}pedaggio_verificato');
    for (final t in trips) {
      buffer.writeln([
        _date(t.createdAt),
        _cell(t.origin.oneLine),
        _cell(t.destination.oneLine),
        t.km.toStringAsFixed(1),
        t.minutes.toStringAsFixed(0),
        t.fuel.toStringAsFixed(2),
        t.toll.toStringAsFixed(2),
        t.parking.toStringAsFixed(2),
        t.total.toStringAsFixed(2),
        '${t.occupants}',
        t.tollVerified ? 'si' : 'stima',
      ].join(_separator));
    }
    return buffer.toString();
  }

  /// Writes [content] to `<documents>/centsgo_<name>.csv` and returns the path.
  static Future<String> writeFile(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/centsgo_$name.csv');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _cell(String value) => value.replaceAll(_separator, ',').replaceAll('\n', ' ');
}
