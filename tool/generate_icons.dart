// Generates the CentsGo launcher artwork from the Material "local_gas_station"
// glyph, so the app icon matches the in-app logo.
//
// Usage:  flutter test tool/generate_icons.dart
//
// Output:
//   assets/branding/icon.png            1024px, full-bleed (iOS / Windows / Android legacy)
//   assets/branding/icon_foreground.png 1024px, transparent, safe zone (Android adaptive)
//   assets/branding/icon_macos.png      1024px, rounded with margin (macOS)
//
// The PNGs are then expanded to every size by `dart run flutter_launcher_icons`.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sdkFont = '/Users/henry/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
const _outDir = 'assets/branding';

const _orange = Color(0xFFF97316);
const _orangeDeep = Color(0xFFC2410C);
const _orangeDark = Color(0xFF7C2D12);

Future<void> _loadMaterialIcons() async {
  final file = File(_sdkFont);
  if (!file.existsSync()) {
    fail('MaterialIcons font not found at $_sdkFont');
  }
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  await loader.load();
}

void _drawGlyph(Canvas canvas, {required double size, required Offset center, Color color = Colors.white}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(Icons.local_gas_station_rounded.codePoint),
      style: TextStyle(
        fontFamily: Icons.local_gas_station_rounded.fontFamily,
        fontSize: size,
        color: color,
        height: 1,
      ),
    ),
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

void _drawBackground(Canvas canvas, Size size, {double radius = 0}) {
  final rect = Offset.zero & size;
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_orange, _orangeDeep, _orangeDark],
      stops: [0.0, 0.62, 1.0],
    ).createShader(rect);
  if (radius <= 0) {
    canvas.drawRect(rect, paint);
  } else {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  }
  // Soft highlight in the top-left corner for depth.
  canvas.drawCircle(
    Offset(size.width * 0.24, size.height * 0.2),
    size.width * 0.42,
    Paint()..color = Colors.white.withValues(alpha: 0.10),
  );
}

Future<void> _write(String name, int size, Future<void> Function(Canvas canvas, Size size) painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  await painter(canvas, Size(size.toDouble(), size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_outDir/$name');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${file.path} (${size}px)');
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadMaterialIcons();

  // iOS / Windows / Android legacy: opaque, full bleed.
  await _write('icon.png', 1024, (canvas, size) async {
    _drawBackground(canvas, size);
    _drawGlyph(canvas, size: size.width * 0.52, center: Offset(size.width / 2, size.height / 2));
  });

  // Android adaptive foreground: transparent, glyph inside the 66% safe zone.
  await _write('icon_foreground.png', 1024, (canvas, size) async {
    _drawGlyph(canvas, size: size.width * 0.46, center: Offset(size.width / 2, size.height / 2));
  });

  // macOS: rounded square with breathing room, transparent outside.
  await _write('icon_macos.png', 1024, (canvas, size) async {
    final inset = size.width * 0.09;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    canvas.save();
    canvas.translate(inset, inset);
    _drawBackground(canvas, rect.size, radius: size.width * 0.19);
    canvas.restore();
    _drawGlyph(canvas, size: rect.width * 0.58, center: rect.center);
  });
}
