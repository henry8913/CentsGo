import 'package:centsgo/data/address_index.dart';
import 'package:centsgo/models/address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AddressIndex index;

  setUpAll(() async {
    index = await AddressIndex.load();
  });

  test('loads comuni and province from the bundled assets', () {
    expect(index.comuni.length, greaterThan(7000));
    expect(index.provinces.length, greaterThan(100));
    final milano = index.provinceByCode('MI');
    expect(milano?.name, 'Milano');
    expect(milano?.region, 'Lombardia');
  });

  test('comune autocomplete prefers prefixes over contains', () {
    final results = index.searchComuni('mil');
    expect(results.first.name.toLowerCase(), startsWith('mil'));
    expect(results.any((c) => c.name == 'Milano'), isTrue);
    expect(index.searchComuni('mil', province: 'RM').every((c) => c.province == 'RM'), isTrue);
  });

  test('province filter and lookup', () {
    final roma = index.comuniOf('RM');
    expect(roma.any((c) => c.name == 'Roma'), isTrue);
    expect(index.searchComuni('rom', province: 'RM').first.name, 'Roma');
    expect(index.comuneByName('Milano', province: 'MI')?.province, 'MI');
  });

  test('postcode validation is format-only, because CAP data is not bundled', () {
    expect(index.isValidPostcode('20121'), isTrue);
    expect(index.isValidPostcode('2012'), isFalse);
    expect(index.isValidPostcode('ABCDE'), isFalse);
  });

  test('addresses normalise and serialise', () {
    const raw = Address(
      street: '  via   roma ',
      houseNumber: ' 12 ',
      postcode: '2012 1',
      city: ' milano ',
      province: 'mi',
    );
    final a = raw.normalized();
    expect(a.street, 'via roma');
    expect(a.houseNumber, '12');
    expect(a.postcode, '20121');
    expect(a.city, 'milano');
    expect(a.province, 'MI');
    expect(a.oneLine, 'via roma 12, 20121 milano (MI)');

    final restored = Address.fromJson(a.toJson());
    expect(restored, a);
    expect(a.copyWith(clearCoordinates: true).hasCoordinates, isFalse);
  });
}
