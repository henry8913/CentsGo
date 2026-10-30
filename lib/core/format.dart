import 'package:intl/intl.dart';

/// Formatting helpers tuned for the Italian market: comma decimal separator,
/// three decimals for fuel prices (as required by the price transparency rules),
/// metric distances.
class Fmt {
  static final _int = NumberFormat.decimalPattern('it_IT');
  static final _two = NumberFormat('#,##0.00', 'it_IT');
  static final _one = NumberFormat('#,##0.0', 'it_IT');

  /// €1,989 — always three decimals, like the price boards.
  static String price(double? value) {
    if (value == null) return '—';
    return '€${value.toStringAsFixed(3).replaceAll('.', ',')}';
  }

  static String priceCompact(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(3).replaceAll('.', ',');
  }

  static String euro(num value) => '€ ${_two.format(value)}';

  static String euroOne(num value) => '€ ${_one.format(value)}';

  static String liters(num value) => '${_one.format(value)} L';

  static String km(double km) {
    if (km < 0.95) return '${(km * 1000).round()} m';
    if (km < 10) return '${_one.format(km)} km';
    return '${_int.format(km.round())} km';
  }

  static String count(num value) => _int.format(value);

  static String percent(double value) => '${_one.format(value)}%';

  /// DateFormat falls back to the default locale when the Italian date symbols
  /// have not been loaded yet (e.g. very first frame or a widget test).
  static DateFormat _df(String pattern) {
    try {
      return DateFormat(pattern, 'it_IT');
    } catch (_) {
      return DateFormat(pattern);
    }
  }

  static String date(DateTime d) => _df('dd/MM/yyyy').format(d);

  static String dateShort(DateTime d) => _df('dd MMM').format(d);

  static String time(DateTime d) => _df('HH:mm').format(d);

  static String monthYear(DateTime d) => _df('MMMM yyyy').format(d);

  /// "3 h fa", "ieri", "2 g fa" — the freshness line of a price.
  static String relative(DateTime? when, {DateTime? now}) {
    if (when == null) return 'non disponibile';
    final ref = now ?? DateTime.now();
    final diff = ref.difference(when);
    if (diff.isNegative || diff.inMinutes < 2) return 'adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    final hours = diff.inHours;
    final today = DateTime(ref.year, ref.month, ref.day);
    final day = DateTime(when.year, when.month, when.day);
    final days = today.difference(day).inDays;
    if (days == 0) return '$hours h fa';
    if (days == 1) return 'ieri';
    if (days < 7) return '$days g fa';
    if (days < 30) return '${(days / 7).floor()} sett fa';
    return date(when);
  }

  static String fuelUnit(String fuel) => fuel == 'Metano' ? 'kg' : 'L';

  static String sign(double value, {int decimals = 3}) {
    final s = value.abs().toStringAsFixed(decimals).replaceAll('.', ',');
    if (value > 0.0001) return '+$s';
    if (value < -0.0001) return '-$s';
    return s;
  }
}
