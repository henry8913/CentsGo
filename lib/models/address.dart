import 'package:flutter/foundation.dart';

/// Postal address used by origins, destinations, home/work shortcuts and the
/// garage. Flat, serialisable, and never assumes the city alone.
@immutable
class Address {
  const Address({
    this.street = '',
    this.houseNumber = '',
    this.postcode = '',
    this.city = '',
    this.province = '',
    this.lat,
    this.lon,
  });

  static const empty = Address();

  final String street;
  final String houseNumber;
  final String postcode;
  final String city;
  final String province;
  final double? lat;
  final double? lon;

  bool get hasCoordinates => lat != null && lon != null;
  bool get isStreetAddress => street.trim().isNotEmpty;
  bool get isComplete => isStreetAddress && city.trim().isNotEmpty;

  /// "Via Roma 12, 20121 Milano (MI)"
  String get oneLine {
    final parts = <String>[];
    final streetPart = [street.trim(), houseNumber.trim()].where((e) => e.isNotEmpty).join(' ');
    if (streetPart.isNotEmpty) parts.add(streetPart);
    final cityPart = [postcode.trim(), city.trim()].where((e) => e.isNotEmpty).join(' ');
    final cityWithProvince = [cityPart, if (province.trim().isNotEmpty) '(${province.trim().toUpperCase()})']
        .where((e) => e.isNotEmpty)
        .join(' ');
    if (cityWithProvince.isNotEmpty) parts.add(cityWithProvince);
    return parts.join(', ');
  }

  /// Short label for chips and lists.
  String get shortLabel {
    if (city.isNotEmpty) return province.isEmpty ? city : '$city (${province.toUpperCase()})';
    if (street.isNotEmpty) return street;
    return 'Posizione';
  }

  Address copyWith({
    String? street,
    String? houseNumber,
    String? postcode,
    String? city,
    String? province,
    double? lat,
    double? lon,
    bool clearCoordinates = false,
  }) {
    return Address(
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      postcode: postcode ?? this.postcode,
      city: city ?? this.city,
      province: province ?? this.province,
      lat: clearCoordinates ? null : (lat ?? this.lat),
      lon: clearCoordinates ? null : (lon ?? this.lon),
    );
  }

  /// Trims, collapses spaces and upper-cases the province, following the
  /// conventions of the Italian address registry.
  Address normalized() => Address(
        street: _clean(street),
        houseNumber: _clean(houseNumber),
        postcode: postcode.replaceAll(RegExp(r'\D'), '').trim(),
        city: _clean(city),
        province: province.trim().toUpperCase(),
        lat: lat,
        lon: lon,
      );

  static String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  Map<String, dynamic> toJson() => {
        'street': street,
        'houseNumber': houseNumber,
        'postcode': postcode,
        'city': city,
        'province': province,
        'lat': lat,
        'lon': lon,
      };

  static Address fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] as String? ?? '',
        houseNumber: json['houseNumber'] as String? ?? '',
        postcode: json['postcode'] as String? ?? '',
        city: json['city'] as String? ?? '',
        province: json['province'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.street == street &&
      other.houseNumber == houseNumber &&
      other.postcode == postcode &&
      other.city == city &&
      other.province == province &&
      other.lat == lat &&
      other.lon == lon;

  @override
  int get hashCode => Object.hash(street, houseNumber, postcode, city, province, lat, lon);

  @override
  String toString() => oneLine;
}

/// How an address was produced, so the UI can be honest about precision.
enum AddressPrecision {
  gps('Posizione GPS'),
  civic('Numero civico'),
  street('Via'),
  city('Città');

  const AddressPrecision(this.label);
  final String label;
}
