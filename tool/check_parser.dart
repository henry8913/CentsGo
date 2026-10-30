// Quick end-to-end check of the CSV parser against real MIMIT files:
//   dart run tool/check_parser.dart <anagrafica.csv> <prezzi.csv>
import 'dart:io';

import 'package:centsgo/data/mimit_source.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/check_parser.dart anagrafica.csv prezzi.csv');
    exit(2);
  }
  final anagrafica = File(args[0]).readAsStringSync();
  final prezzi = File(args[1]).readAsStringSync();
  final watch = Stopwatch()..start();
  final result = MimitSource.parse(anagrafica, prezzi);
  watch.stop();
  stdout.writeln('stations: ${result.stationCount}');
  stdout.writeln('priceDate: ${result.priceDate}');
  stdout.writeln('json size: ${(result.json.length / 1e6).toStringAsFixed(2)} MB');
  stdout.writeln('parse time: ${watch.elapsedMilliseconds} ms');
  final sample = result.json.substring(0, 600);
  stdout.writeln(sample);
}
