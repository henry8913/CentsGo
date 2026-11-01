import '../core/units.dart';
import 'address.dart';

/// A calculated trip saved in the history, with its cost breakdown.
class TripRecord {
  const TripRecord({
    required this.id,
    required this.createdAt,
    required this.origin,
    required this.destination,
    required this.km,
    required this.minutes,
    required this.fuel,
    required this.toll,
    required this.parking,
    required this.total,
    required this.occupants,
    required this.tollVerified,
    this.fuelLiters = 0,
    this.pricePerLiter = 0,
    this.provider = '',
  });

  final String id;
  final DateTime createdAt;
  final Address origin;
  final Address destination;
  final double km;
  final double minutes;
  final double fuel;
  final double toll;
  final double parking;
  final double total;
  final int occupants;
  final bool tollVerified;
  final double fuelLiters;
  final double pricePerLiter;
  final String provider;

  Money get totalMoney => Money(total);
  Money get perPerson => Money(total / (occupants <= 0 ? 1 : occupants));
  Distance get distance => Distance(km);

  String get label => '${origin.shortLabel} → ${destination.shortLabel}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'km': km,
        'minutes': minutes,
        'fuel': fuel,
        'toll': toll,
        'parking': parking,
        'total': total,
        'occupants': occupants,
        'tollVerified': tollVerified,
        'fuelLiters': fuelLiters,
        'pricePerLiter': pricePerLiter,
        'provider': provider,
      };

  static TripRecord fromJson(Map<String, dynamic> json) => TripRecord(
        id: json['id'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        origin: Address.fromJson((json['origin'] as Map).cast<String, dynamic>()),
        destination: Address.fromJson((json['destination'] as Map).cast<String, dynamic>()),
        km: (json['km'] as num?)?.toDouble() ?? 0,
        minutes: (json['minutes'] as num?)?.toDouble() ?? 0,
        fuel: (json['fuel'] as num?)?.toDouble() ?? 0,
        toll: (json['toll'] as num?)?.toDouble() ?? 0,
        parking: (json['parking'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        occupants: (json['occupants'] as num?)?.toInt() ?? 1,
        tollVerified: json['tollVerified'] as bool? ?? false,
        fuelLiters: (json['fuelLiters'] as num?)?.toDouble() ?? 0,
        pricePerLiter: (json['pricePerLiter'] as num?)?.toDouble() ?? 0,
        provider: json['provider'] as String? ?? '',
      );
}
