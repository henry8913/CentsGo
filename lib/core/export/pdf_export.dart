import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/trip_record.dart';
import '../../models/vehicle.dart';

/// PDF report of the garage and trips. Pure Dart (`pdf` package), so it works
/// on all five platforms without native code.
class PdfExport {
  static Future<Uint8List> build({
    required List<Refuel> refuels,
    required List<TripRecord> trips,
    required Map<String, String> vehicleNames,
    required String generatedAt,
    required double fuelTotal,
    required double tollTotal,
    required String costPerKm,
  }) async {
    final doc = pw.Document();
    final orange = PdfColor.fromInt(0xFFEA580C);

    pw.Widget header(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: orange)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Text(
          'CentsGo · documento generato il $generatedAt · dati MIMIT (IODL 2.0) e OpenStreetMap (ODbL)',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
        build: (context) => [
          pw.Text('CentsGo', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: orange)),
          pw.Text('Riepilogo costi auto e viaggi', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Carburante: ${fuelTotal.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Pedaggi: ${tollTotal.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Costo/km: $costPerKm €', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          header('Rifornimenti (${refuels.length})'),
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Veicolo', 'Distributore', 'Litri', '€/L', 'Totale', 'Km', 'Pieno'],
            data: [
              for (final r in [...refuels]..sort((a, b) => b.date.compareTo(a.date)))
                [
                  _date(r.date),
                  vehicleNames[r.vehicleId] ?? r.vehicleId,
                  r.stationName,
                  r.liters.toStringAsFixed(1),
                  r.pricePerLiter.toStringAsFixed(3),
                  r.total.toStringAsFixed(2),
                  r.odometerKm?.toStringAsFixed(0) ?? '',
                  r.fullTank ? 'sì' : 'no',
                ],
            ],
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          header('Viaggi (${trips.length})'),
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Percorso', 'Km', 'Min', 'Carburante', 'Pedaggio', 'Totale', 'A testa'],
            data: [
              for (final t in trips)
                [
                  _date(t.createdAt),
                  '${t.origin.shortLabel} → ${t.destination.shortLabel}',
                  t.km.toStringAsFixed(0),
                  t.minutes.toStringAsFixed(0),
                  t.fuel.toStringAsFixed(2),
                  t.toll.toStringAsFixed(2),
                  t.total.toStringAsFixed(2),
                  t.perPerson.format(),
                ],
            ],
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'I pedaggi sono stime finché le tariffe delle concessionarie non sono validate. '
            'Le distanze dei viaggi provengono dal servizio di routing configurato.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> write(Uint8List bytes, {String name = 'riepilogo'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/centsgo_$name.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
