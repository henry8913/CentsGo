
import '../core/units.dart';

/// Body styles for the Garage. The silhouettes are drawn with a CustomPainter
/// (no bundled car artwork), so any colour combination is available.
enum VehicleType {
  citycar('Citycar', 40),
  berlina('Berlina', 50),
  suv('SUV', 60),
  coupe('Coupé', 55),
  cabrio('Cabrio', 50),
  furgone('Furgone', 70),
  moto('Moto', 15),
  scooter('Scooter', 9);

  const VehicleType(this.label, this.defaultTank);
  final String label;
  final double defaultTank;
}

enum VehicleColor {
  bianco('Bianco', 0xFFF4F6F7),
  argento('Argento', 0xFFB9C3C8),
  grigio('Grigio', 0xFF7C8A90),
  nero('Nero', 0xFF22282B),
  blu('Blu', 0xFF2A5FA8),
  rosso('Rosso', 0xFFC63C35),
  verde('Verde', 0xFF2F8A5B),
  arancio('Arancio CentsGo', 0xFFEA580C);

  const VehicleColor(this.label, this.value);
  final String label;
  final int value;
}

/// Bollo / insurance / inspection deadlines.
class VehicleDeadline {
  const VehicleDeadline({
    required this.kind,
    required this.due,
    this.reminderDays = 30,
  });

  final String kind;
  final DateTime due;
  final int reminderDays;

  int daysLeft([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final a = DateTime(ref.year, ref.month, ref.day);
    final b = DateTime(due.year, due.month, due.day);
    return b.difference(a).inDays;
  }

  bool isOverdue([DateTime? now]) => daysLeft(now) < 0;
  bool isSoon([DateTime? now]) => daysLeft(now) <= reminderDays;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'due': due.toIso8601String(),
        'reminderDays': reminderDays,
      };

  static VehicleDeadline fromJson(Map<String, dynamic> json) => VehicleDeadline(
        kind: json['kind'] as String? ?? 'Scadenza',
        due: DateTime.tryParse(json['due'] as String? ?? '') ?? DateTime.now(),
        reminderDays: (json['reminderDays'] as num?)?.toInt() ?? 30,
      );
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.nickname,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.fuel,
    required this.tankLiters,
    required this.consumption,
    required this.color,
    required this.deadlines,
    this.odometerKm,
    this.createdAt,
    this.consumptionUnit,
  });

  final String id;
  final String nickname;
  final VehicleType type;
  final String brand;
  final String model;
  final int year;
  final String plate;

  /// One of: Benzina, Gasolio, GPL, Metano, HVO, Elettrico.
  final String fuel;
  final double tankLiters;

  /// Declared or measured consumption: litres per 100 km (kWh/100 km for EVs).
  final double consumption;

  /// Optional per-vehicle display unit; when null the app preference is used.
  final ConsumptionUnit? consumptionUnit;
  final VehicleColor color;
  final List<VehicleDeadline> deadlines;
  final double? odometerKm;
  final DateTime? createdAt;

  String get displayName => nickname.isNotEmpty ? nickname : '$brand $model'.trim();

  /// Cost of a full tank at [pricePerLiter].
  double tankCost(double pricePerLiter) => tankLiters * pricePerLiter;

  /// Estimated range on a full tank in km.
  double get rangeKm => consumption <= 0 ? 0 : tankLiters / consumption * 100;

  /// €/km at the given price per litre.
  double costPerKm(double pricePerLiter) =>
      consumption <= 0 ? 0 : consumption / 100 * pricePerLiter;

  Vehicle copyWith({
    String? nickname,
    VehicleType? type,
    String? brand,
    String? model,
    int? year,
    String? plate,
    String? fuel,
    double? tankLiters,
    double? consumption,
    VehicleColor? color,
    List<VehicleDeadline>? deadlines,
    double? odometerKm,
    ConsumptionUnit? consumptionUnit,
    bool clearConsumptionUnit = false,
  }) {
    return Vehicle(
      id: id,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      plate: plate ?? this.plate,
      fuel: fuel ?? this.fuel,
      tankLiters: tankLiters ?? this.tankLiters,
      consumption: consumption ?? this.consumption,
      color: color ?? this.color,
      deadlines: deadlines ?? this.deadlines,
      odometerKm: odometerKm ?? this.odometerKm,
      createdAt: createdAt,
      consumptionUnit: clearConsumptionUnit ? null : (consumptionUnit ?? this.consumptionUnit),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'type': type.name,
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'fuel': fuel,
        'tankLiters': tankLiters,
        'consumption': consumption,
        'color': color.name,
        'deadlines': deadlines.map((d) => d.toJson()).toList(),
        'odometerKm': odometerKm,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'consumptionUnit': consumptionUnit?.name,
      };

  static Vehicle fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '',
      type: VehicleType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VehicleType.berlina,
      ),
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      plate: json['plate'] as String? ?? '',
      fuel: json['fuel'] as String? ?? 'Benzina',
      tankLiters: (json['tankLiters'] as num?)?.toDouble() ?? 50,
      consumption: (json['consumption'] as num?)?.toDouble() ?? 6.5,
      color: VehicleColor.values.firstWhere(
        (c) => c.name == json['color'],
        orElse: () => VehicleColor.blu,
      ),
      deadlines: ((json['deadlines'] as List?) ?? const [])
          .map((e) => VehicleDeadline.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      odometerKm: (json['odometerKm'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      consumptionUnit: json['consumptionUnit'] == null
          ? null
          : ConsumptionUnit.values.firstWhere(
              (u) => u.name == json['consumptionUnit'],
              orElse: () => ConsumptionUnit.litersPer100km,
            ),
    );
  }
}

/// A refuel recorded in the Garage diary.
class Refuel {
  Refuel({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    required this.pricePerLiter,
    this.stationName = '',
    this.odometerKm,
    this.notes = '',
    this.fullTank = true,
    this.manualPrice = false,
    this.stationId,
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final double liters;
  final double pricePerLiter;
  final String stationName;
  final double? odometerKm;
  final String notes;

  /// A partial refuel must not be used as a consumption anchor: only full
  /// tanks delimit a measurable interval.
  final bool fullTank;

  /// True when the user typed the €/L instead of taking it from MIMIT.
  final bool manualPrice;
  final String? stationId;

  double get total => liters * pricePerLiter;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'date': date.toIso8601String(),
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'stationName': stationName,
        'odometerKm': odometerKm,
        'notes': notes,
        'fullTank': fullTank,
        'manualPrice': manualPrice,
        'stationId': stationId,
      };

  static Refuel fromJson(Map<String, dynamic> json) => Refuel(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        liters: (json['liters'] as num?)?.toDouble() ?? 0,
        pricePerLiter: (json['pricePerLiter'] as num?)?.toDouble() ?? 0,
        stationName: json['stationName'] as String? ?? '',
        odometerKm: (json['odometerKm'] as num?)?.toDouble(),
        notes: json['notes'] as String? ?? '',
        fullTank: json['fullTank'] as bool? ?? true,
        manualPrice: json['manualPrice'] as bool? ?? false,
        stationId: json['stationId'] as String?,
      );
}

/// Aggregated Garage numbers (month, lifetime, consumption).
class GarageStats {
  const GarageStats({
    required this.monthSpend,
    required this.monthLiters,
    required this.totalSpend,
    required this.totalLiters,
    required this.avgPrice,
    required this.refuels,
    required this.measuredConsumption,
    required this.odometerKm,
    this.measuredKm = 0,
    this.measuredCost,
    this.consumptionIsApproximate = false,
    this.fullTanks = 0,
    this.partialRefuels = 0,
  });

  final double monthSpend;
  final double monthLiters;
  final double totalSpend;
  final double totalLiters;
  final double avgPrice;
  final int refuels;

  /// Litres (or kWh) per 100 km measured from the diary, null when there are
  /// not enough data points.
  final double? measuredConsumption;
  final double? odometerKm;

  /// Kilometres covered by the measured intervals.
  final double measuredKm;

  /// Real €/km from the fuel actually paid in the measured intervals.
  final Money? measuredCost;

  /// True when the value comes from consecutive odometer readings instead of
  /// two full tanks (less precise).
  final bool consumptionIsApproximate;
  final int fullTanks;
  final int partialRefuels;

  /// Estimated €/km at [pricePerLiter] for the declared consumption.
  Money costPerKm(double pricePerLiter, double consumptionPer100) =>
      Money(consumptionPer100 / 100 * pricePerLiter);

  static GarageStats from(List<Refuel> refuels, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    var monthSpend = 0.0, monthLiters = 0.0, totalSpend = 0.0, totalLiters = 0.0;
    var fullTanks = 0, partial = 0;
    for (final r in refuels) {
      totalSpend += r.total;
      totalLiters += r.liters;
      r.fullTank ? fullTanks++ : partial++;
      if (r.date.year == ref.year && r.date.month == ref.month) {
        monthSpend += r.total;
        monthLiters += r.liters;
      }
    }

    final sorted = [...refuels]..sort((a, b) => a.date.compareTo(b.date));

    // Preferred method: two full tanks with an odometer delimit a measurable
    // interval; every refuel in between (partial ones included) counts.
    double? measured;
    var measuredKm = 0.0;
    double? measuredSpend;
    var approximate = false;

    final anchors = sorted.where((r) => r.fullTank && r.odometerKm != null).toList();
    var litersSum = 0.0;
    var kmSum = 0.0;
    var spendSum = 0.0;
    for (var i = 1; i < anchors.length; i++) {
      final from = sorted.indexOf(anchors[i - 1]);
      final to = sorted.indexOf(anchors[i]);
      if (to <= from) continue;
      final km = (anchors[i].odometerKm! - anchors[i - 1].odometerKm!).abs();
      if (km < 1) continue;
      var liters = 0.0;
      var spend = 0.0;
      for (var j = from + 1; j <= to; j++) {
        liters += sorted[j].liters;
        spend += sorted[j].total;
      }
      if (liters <= 0) continue;
      litersSum += liters;
      kmSum += km;
      spendSum += spend;
    }
    if (kmSum >= 1 && litersSum > 0) {
      measured = litersSum / kmSum * 100;
      measuredKm = kmSum;
      measuredSpend = spendSum;
    } else {
      // Fallback: consecutive odometer readings, marked as approximate.
      final withOdo = sorted.where((r) => r.odometerKm != null).toList();
      if (withOdo.length >= 2) {
        final first = withOdo.first;
        final last = withOdo.last;
        final km = (last.odometerKm! - first.odometerKm!).abs();
        final liters = withOdo.skip(1).fold<double>(0, (a, b) => a + b.liters);
        if (km > 1 && liters > 0) {
          measured = liters / km * 100;
          measuredKm = km;
          measuredSpend = withOdo.skip(1).fold<double>(0, (a, b) => a + b.total);
          approximate = true;
        }
      }
    }

    final odo = sorted.isEmpty ? null : sorted.last.odometerKm;
    return GarageStats(
      monthSpend: monthSpend,
      monthLiters: monthLiters,
      totalSpend: totalSpend,
      totalLiters: totalLiters,
      avgPrice: totalLiters > 0 ? totalSpend / totalLiters : 0,
      refuels: refuels.length,
      measuredConsumption: measured,
      odometerKm: odo,
      measuredKm: measuredKm,
      measuredCost: measuredSpend == null || measuredKm <= 0 ? null : Money(measuredSpend / measuredKm),
      consumptionIsApproximate: approximate,
      fullTanks: fullTanks,
      partialRefuels: partial,
    );
  }
}
