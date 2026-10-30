import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Minimal line chart (no dependency) used for the local price history.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 70,
    this.showAxis = false,
  });

  final List<double> values;
  final Color? color;
  final double height;
  final bool showAxis;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Il grafico si popola con i prossimi aggiornamenti',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: color ?? p.brand, grid: showAxis ? p.border : null),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, this.grid});

  final List<double> values;
  final Color color;
  final Color? grid;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.0001 ? 0.01 : max - min;
    double x(int i) => values.length == 1 ? 0 : i / (values.length - 1) * size.width;
    double y(double v) => size.height - ((v - min) / range) * (size.height - 8) - 4;

    if (grid != null) {
      final gp = Paint()
        ..color = grid!
        ..strokeWidth = 1;
      for (var i = 1; i < 4; i++) {
        final gy = size.height / 4 * i;
        canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gp);
      }
    }

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.01)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(x(values.length - 1), y(values.last)), 3.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}

/// Monthly spend bars for the Garage.
class MonthBars extends StatelessWidget {
  const MonthBars({super.key, required this.entries, this.height = 120});

  /// label -> value (€)
  final List<({String label, double value})> entries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (entries.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Nessuna spesa registrata', style: TextStyle(color: p.muted, fontSize: 12.5))),
      );
    }
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      e.value <= 0 ? '' : '${e.value.round()}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.muted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: max <= 0 ? 2 : (e.value / max) * (height - 42),
                      decoration: BoxDecoration(
                        color: e.value <= 0 ? p.border : p.brand,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.label, style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
