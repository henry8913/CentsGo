import 'dart:convert';

import 'package:centsgo/data/mimit_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const anagrafica = '''Estrazione del 2026-10-28
idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|Comune|Provincia|Latitudine|Longitudine
1|ENI SPA|Agip Eni|Stradale|IMPIANTO UNO|Via Roma 1|Milano|MI|45.46420|9.19000
2|Q8|Q8|Autostradale|AREA A4|Autostrada A4 Km 12|Verona|VR|45.43800|10.99200
3|X|Pompe Bianche|Stradale|SENZA PREZZI|Via Test|Roma|RM|41.90000|12.49000
4|Y|Esso|Stradale|COORDINATA ZERO|Via Zero|Napoli|NA|0|0
''';

  const prezzi = '''Estrazione del 2026-10-28
idImpianto|descCarburante|prezzo|isSelf|dtComu
1|Benzina|1.899|1|28/10/2026 08:00:00
1|Benzina|2.099|0|28/10/2026 08:00:00
1|Gasolio|1.799|1|28/10/2026 08:05:00
1|HVOlution|1.899|1|28/10/2026 08:05:00
2|Benzina|1.959|1|28/10/2026 08:10:00
2|GPL|0.799|0|28/10/2026 08:10:00
2|Metano|1.299|0|28/10/2026 08:10:00
3|Benzina|1.900|1|28/10/2026 08:00:00
''';

  test('joins anagrafica and prices into the compact snapshot', () {
    final result = MimitSource.parse(anagrafica, prezzi);
    expect(result.stationCount, 3, reason: 'station 4 has invalid coordinates');
    expect(result.priceDate, '2026-10-28');

    final json = jsonDecode(result.json) as Map<String, dynamic>;
    expect(json['fuels'], MimitSource.fuels);
    final brands = json['brands'] as List;
    final stations = json['stations'] as List;

    // Stations are sorted by province (MI, RM, VR).
    expect((stations[0] as List)[0], '1');
    final milano = stations[0] as List;
    expect(milano[10]['Benzina'], [1.899, 2.099]);
    expect(milano[10]['Gasolio'], [1.799, null]);
    expect(milano[10]['HVO'], [1.899, null], reason: 'HVOlution maps to HVO');
    expect(milano[9], greaterThan(0));

    final verona = stations[2] as List;
    expect(verona[0], '2');
    expect(brands[verona[1]], 'Q8');
    expect(verona[8], 'A4', reason: 'motorway code extracted from the address');
    expect(verona[10], {'Benzina': [1.959, null], 'GPL': [null, 0.799], 'Metano': [null, 1.299]});
  });

  test('skips stations without prices or with invalid coordinates', () {
    final result = MimitSource.parse(anagrafica, prezzi);
    final ids = (jsonDecode(result.json)['stations'] as List).map((s) => (s as List)[0]).toList();
    expect(ids, contains('3'));
    expect(ids, isNot(contains('4')), reason: '0/0 coordinates are dropped');
  });
}
