import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../units.dart';

/// One motorway section found on the route (from OSRM step refs).
@immutable
class MotorwayLeg {
  const MotorwayLeg({required this.ref, required this.km, required this.concession});

  final String ref;
  final double km;
  final String? concession;
}

@immutable
class TollLine {
  const TollLine({
    required this.ref,
    required this.km,
    required this.concession,
    required this.eurPerKm,
    required this.amount,
    required this.verified,
  });

  final String ref;
  final double km;
  final String? concession;
  final double eurPerKm;
  final Money amount;
  final bool verified;
}

@immutable
class TollEstimate {
  const TollEstimate({
    required this.lines,
    required this.total,
    required this.vehicleClass,
    required this.verified,
    required this.source,
    required this.validity,
    this.minimumApplied = false,
  });

  static const empty = TollEstimate(
    lines: [],
    total: Money.zero,
    vehicleClass: 'A',
    verified: false,
    source: '—',
    validity: '—',
  );

  final List<TollLine> lines;
  final Money total;
  final String vehicleClass;

  /// False when at least one line uses an unverified tariff: the UI must say
  /// "stima".
  final bool verified;
  final String source;
  final String validity;
  final bool minimumApplied;

  bool get isEmpty => lines.isEmpty;
  double get km => lines.fold(0, (a, b) => a + b.km);
}

/// Italian tolls are set per concession (not per region) and depend on the
/// vehicle class and on the distance actually driven on that motorway.
///
/// The bundled table is intentionally conservative: every entry that could not
/// be checked against the official concessionaire tariff is marked
/// `verified: false`, and the calculation is labelled as an estimate.
class TollEngine {
  TollEngine._(
    this._concessions,
    this._nationalPerKmClassA,
    this._minimum,
    this._roundingStep,
    this._classFactor,
    this._meta,
  );

  static const assetPath = 'assets/data/tolls_it.json';
  static TollEngine? _instance;

  final List<_Concession> _concessions;
  final double _nationalPerKmClassA;
  final double _minimum;
  final double _roundingStep;
  final Map<String, double> _classFactor;
  final Map<String, dynamic> _meta;

  static Future<TollEngine> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final national = (map['national'] as Map).cast<String, dynamic>();
    final concessions = <_Concession>[];
    for (final item in (map['concessions'] as List? ?? const [])) {
      final c = (item as Map).cast<String, dynamic>();
      concessions.add(_Concession(
        name: c['name'] as String? ?? '',
        refs: ((c['refs'] as List?) ?? const []).map((e) => e.toString().toUpperCase()).toSet(),
        perKmClassA: (c['eur_per_km_class_a'] as num?)?.toDouble(),
        verified: c['verified'] as bool? ?? false,
        source: c['source'] as String? ?? '',
        validity: c['validity'] as String? ?? '',
      ));
    }
    final classes = ((map['class_factor'] as Map?) ?? const {'A': 1.0}).cast<String, dynamic>();
    _instance = TollEngine._(
      concessions,
      (national['eur_per_km_class_a'] as num?)?.toDouble() ?? 0.095,
      (national['minimum'] as num?)?.toDouble() ?? 0.30,
      (national['rounding_step'] as num?)?.toDouble() ?? 0.10,
      {for (final e in classes.entries) e.key: (e.value as num).toDouble()},
      (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return _instance!;
  }

  String get datasetSource => _meta['source'] as String? ?? 'ART/MIT (da validare)';
  String get datasetValidity => _meta['validity'] as String? ?? '—';

  String concessionFor(String ref) {
    final code = ref.toUpperCase();
    for (final c in _concessions) {
      if (c.refs.contains(code)) return c.name;
    }
    return 'Concessione non riconosciuta';
  }

  /// [legs] are the motorway sections of the route. [vehicleClass] is one of
  /// A, B, 3, 4, 5 (Italian toll classes).
  TollEstimate estimate(List<MotorwayLeg> legs, {String vehicleClass = 'A'}) {
    if (legs.isEmpty) return TollEstimate.empty;
    final factor = _classFactor[vehicleClass] ?? 1.0;
    final lines = <TollLine>[];
    var total = 0.0;
    var allVerified = true;
    var source = '';
    var validity = '';
    final usedConcessions = <String>{};

    for (final leg in legs) {
      if (leg.km <= 0) continue;
      final concession = _find(leg.ref);
      final perKmA = concession?.perKmClassA ?? _nationalPerKmClassA;
      final verified = concession?.verified ?? false;
      if (!verified) allVerified = false;
      source = concession?.source ?? 'Tariffa media nazionale (stima)';
      validity = concession?.validity ?? datasetValidity;
      final amount = leg.km * perKmA * factor;
      total += amount;
      usedConcessions.add(concession?.name ?? leg.ref);
      lines.add(TollLine(
        ref: leg.ref,
        km: leg.km,
        concession: concession?.name,
        eurPerKm: perKmA * factor,
        amount: Money(amount),
        verified: verified,
      ));
    }

    var minimumApplied = false;
    if (total > 0 && total < _minimum * usedConcessions.length) {
      total = _minimum * usedConcessions.length;
      minimumApplied = true;
    }
    // Official receipts are rounded to the nearest 10 cents.
    if (_roundingStep > 0) {
      total = (total / _roundingStep).round() * _roundingStep;
    }

    return TollEstimate(
      lines: lines,
      total: Money(total),
      vehicleClass: vehicleClass,
      verified: allVerified,
      source: source,
      validity: validity,
      minimumApplied: minimumApplied,
    );
  }

  _Concession? _find(String ref) {
    for (final c in _concessions) {
      if (c.refs.contains(ref.toUpperCase())) return c;
    }
    return null;
  }
}

class _Concession {
  const _Concession({
    required this.name,
    required this.refs,
    required this.perKmClassA,
    required this.verified,
    required this.source,
    required this.validity,
  });

  final String name;
  final Set<String> refs;
  final double? perKmClassA;
  final bool verified;
  final String source;
  final String validity;
}
