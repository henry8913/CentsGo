import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// Stylised side view of the vehicle, drawn with a CustomPainter so that every
/// body style/colour combination is available without shipping artwork.
///
/// The canvas is 260×116 with the ground line at y = 112; every shape is sized
/// from the wheel radius, which keeps the proportions believable for all body
/// styles (cars are about 2.6–2.9 wheel lengths tall in reality).
class VehicleArt extends StatelessWidget {
  const VehicleArt({
    super.key,
    required this.type,
    required this.color,
    this.width = 260,
    this.height = 116,
  });

  final VehicleType type;
  final VehicleColor color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _VehiclePainter(type: type, body: Color(color.value)),
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  _VehiclePainter({required this.type, required this.body});

  final VehicleType type;
  final Color body;

  static const _wheel = Color(0xFF20282B);
  static const _hub = Color(0xFFC9D3D6);
  static const _glass = Color(0xFFDDEFF3);
  static const _shadow = Color(0x22000000);
  static const _groundY = 112.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260, size.height / 116);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(130, 106), width: 196, height: 12),
      Paint()..color = _shadow,
    );

    switch (type) {
      case VehicleType.moto:
        _paintMoto(canvas, scooter: false);
      case VehicleType.scooter:
        _paintMoto(canvas, scooter: true);
      case VehicleType.furgone:
        _paintVan(canvas);
      case VehicleType.suv:
        _paintCar(canvas, wheelR: 23, bodyRise: 29, roofRise: 27, long: true, boxy: true);
      case VehicleType.coupe:
        _paintCar(canvas, wheelR: 21, bodyRise: 22, roofRise: 22, long: true);
      case VehicleType.cabrio:
        _paintCar(canvas, wheelR: 21, bodyRise: 22, roofRise: 24, open: true);
      case VehicleType.citycar:
        _paintCar(canvas, wheelR: 19, bodyRise: 21, roofRise: 27, short: true);
      case VehicleType.berlina:
        _paintCar(canvas, wheelR: 21, bodyRise: 22, roofRise: 25);
    }
    canvas.restore();
  }

  /// [bodyRise] is how tall the body band is above the wheel centre, [roofRise]
  /// how far the roof sits above the body.
  void _paintCar(
    Canvas canvas, {
    required double wheelR,
    required double bodyRise,
    required double roofRise,
    bool tall = false,
    bool short = false,
    bool long = false,
    bool open = false,
    bool boxy = false,
  }) {
    final wheelY = _groundY - wheelR;
    final left = short ? 44.0 : 32.0;
    final right = short ? 214.0 : 230.0;
    final bodyTop = wheelY - bodyRise;
    final bodyBottom = wheelY + 7;
    final roof = bodyTop - roofRise;

    final rearWheel = Offset(left + 36, wheelY);
    final frontWheel = Offset(right - 38, wheelY);

    final main = Paint()..color = body;
    final shade = Paint()..color = Color.lerp(body, Colors.black, 0.22)!;
    final darker = Paint()..color = Color.lerp(body, Colors.black, 0.32)!;

    // Wheel arches behind the body, so the silhouette reads as a car.
    final arch = Paint()..color = Color.lerp(body, Colors.black, 0.4)!;
    canvas.drawCircle(rearWheel, wheelR + 4, arch);
    canvas.drawCircle(frontWheel, wheelR + 4, arch);

    // Body: rounded nose and tail, flat sill.
    canvas.drawRRect(
      RRect.fromLTRBR(left, bodyTop, right, bodyBottom, const Radius.circular(12)),
      main,
    );

    // Shoulder line: a slightly darker band along the top of the body.
    canvas.drawRRect(
      RRect.fromLTRBR(left + 2, bodyTop, right - 2, bodyTop + 7, const Radius.circular(6)),
      Paint()..color = Color.lerp(body, Colors.white, 0.12)!,
    );

    if (open) {
      // Cockpit opening.
      canvas.drawRRect(
        RRect.fromLTRBR(left + 46, bodyTop - 6, right - 74, bodyTop + 2, const Radius.circular(6)),
        darker,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(left + 52, bodyTop - 5, right - 82, bodyTop - 1, const Radius.circular(4)),
        Paint()..color = const Color(0xFF2B2320),
      );
      // Raked windshield.
      final windshield = Path()
        ..moveTo(right - 86, bodyTop + 1)
        ..quadraticBezierTo(right - 82, roof + 2, right - 62, roof - 2)
        ..lineTo(right - 54, roof)
        ..quadraticBezierTo(right - 60, roof + 6, right - 58, bodyTop + 1)
        ..close();
      canvas.drawPath(windshield, Paint()..color = _glass);
      canvas.drawPath(
        windshield,
        Paint()
          ..color = Color.lerp(body, Colors.white, 0.35)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    } else {
      // Cabin: smooth roof between the rear pillar and the windshield.
      final cabin = Path()
        ..moveTo(left + (boxy ? 40 : 52), bodyTop + 1)
        ..quadraticBezierTo(left + (boxy ? 48 : 66), roof + (boxy ? 3 : 7), left + (boxy ? 72 : 96), roof)
        ..lineTo(right - (boxy ? 56 : 74), roof)
        ..quadraticBezierTo(right - (boxy ? 50 : 56), roof + (boxy ? 3 : 6), right - (boxy ? 40 : 44), bodyTop + 1)
        ..close();
      canvas.drawPath(cabin, Paint()..color = Color.lerp(body, Colors.black, 0.06)!);

      // Glass band with a B-pillar.
      final glass = Path()
        ..moveTo(left + 64, bodyTop - 2)
        ..quadraticBezierTo(left + 76, roof + 9, left + 100, roof + 4)
        ..lineTo(right - 82, roof + 4)
        ..quadraticBezierTo(right - 66, roof + 9, right - 56, bodyTop - 2)
        ..close();
      canvas.drawPath(glass, Paint()..color = _glass.withValues(alpha: 0.95));

      final pillarX = left + 98;
      canvas.drawLine(
        Offset(pillarX, roof + 4),
        Offset(pillarX + 6, bodyTop - 2),
        Paint()
          ..color = Color.lerp(body, Colors.black, 0.25)!
          ..strokeWidth = 4,
      );
    }

    // Sill shadow and door handle.
    canvas.drawRRect(
      RRect.fromLTRBR(left + 10, bodyBottom - 5, right - 8, bodyBottom - 2, const Radius.circular(2)),
      shade,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(left + 96, bodyTop + 6, left + 112, bodyTop + 10, const Radius.circular(2)),
      Paint()..color = Color.lerp(body, Colors.white, 0.45)!,
    );

    // Wheels on top of the body, fully visible like in flat illustrations.
    _wheelAt(canvas, rearWheel, wheelR);
    _wheelAt(canvas, frontWheel, wheelR);

    // Lights.
    canvas.drawRRect(
      RRect.fromLTRBR(right - 12, bodyTop + 6, right - 3, bodyTop + 12, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFFE29A),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(left + 1, bodyTop + 6, left + 7, bodyTop + 12, const Radius.circular(2)),
      Paint()..color = const Color(0xFFD1453B),
    );
  }

  void _paintVan(Canvas canvas) {
    const wheelR = 23.0;
    final wheelY = _groundY - wheelR;
    final main = Paint()..color = body;
    final glass = Paint()..color = _glass;

    final rearWheel = const Offset(72.0, 0).translate(0, wheelY);
    final frontWheel = Offset(196, wheelY);
    final arch = Paint()..color = Color.lerp(body, Colors.black, 0.4)!;
    canvas.drawCircle(rearWheel, wheelR + 4, arch);
    canvas.drawCircle(frontWheel, wheelR + 4, arch);

    // Box body with a short sloped nose.
    final box = Path()
      ..moveTo(28, wheelY - 56)
      ..lineTo(196, wheelY - 56)
      ..quadraticBezierTo(224, wheelY - 54, 232, wheelY - 32)
      ..lineTo(232, wheelY + 6)
      ..lineTo(28, wheelY + 6)
      ..close();
    canvas.drawPath(box, main);

    // Cargo area stripe and windows.
    canvas.drawRRect(
      RRect.fromLTRBR(34, wheelY - 50, 158, wheelY - 36, const Radius.circular(4)),
      Paint()..color = Color.lerp(body, Colors.white, 0.12)!,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(166, wheelY - 50, 196, wheelY - 34, const Radius.circular(5)),
      glass,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(202, wheelY - 46, 226, wheelY - 30, const Radius.circular(6)),
      glass,
    );

    _wheelAt(canvas, rearWheel, wheelR);
    _wheelAt(canvas, frontWheel, wheelR);

    canvas.drawRRect(
      RRect.fromLTRBR(226, wheelY - 26, 232, wheelY - 16, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFFE29A),
    );
  }

  void _paintMoto(Canvas canvas, {required bool scooter}) {
    final wheelR = scooter ? 18.0 : 21.0;
    final wheelY = _groundY - wheelR;
    final rear = Offset(scooter ? 74 : 64, wheelY);
    final front = Offset(scooter ? 190 : 196, wheelY);

    final main = Paint()..color = body;
    final dark = Paint()..color = Color.lerp(body, Colors.black, 0.42)!;
    final frame = Paint()
      ..color = Color.lerp(body, Colors.black, 0.3)!
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _wheelAt(canvas, rear, wheelR);
    _wheelAt(canvas, front, wheelR);
    // Front fender.
    canvas.drawArc(
      Rect.fromCircle(center: front, radius: wheelR + 4),
      3.6,
      1.9,
      false,
      Paint()
        ..color = Color.lerp(body, Colors.black, 0.15)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    if (scooter) {
      // Floorboard from the rear body to the front shield.
      canvas.drawRRect(
        RRect.fromLTRBR(rear.dx + 8, wheelY - 4, front.dx - 16, wheelY + 3, const Radius.circular(4)),
        Paint()..color = Color.lerp(body, Colors.black, 0.1)!.withValues(alpha: 0.9),
      );
      // Front shield (leg protector).
      final shield = Path()
        ..moveTo(front.dx - 26, wheelY - 2)
        ..lineTo(front.dx - 20, wheelY - 34)
        ..quadraticBezierTo(front.dx - 16, wheelY - 46, front.dx - 2, wheelY - 48)
        ..lineTo(front.dx + 6, wheelY - 42)
        ..lineTo(front.dx + 2, wheelY - 2)
        ..close();
      canvas.drawPath(shield, main);
      // Headlight.
      canvas.drawCircle(Offset(front.dx + 2, wheelY - 40), 4.5, Paint()..color = const Color(0xFFFFE29A));
      // Rear body + seat.
      canvas.drawRRect(
        RRect.fromLTRBR(rear.dx - 6, wheelY - 32, rear.dx + 52, wheelY + 2, const Radius.circular(12)),
        main,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(rear.dx - 4, wheelY - 38, rear.dx + 44, wheelY - 30, const Radius.circular(5)),
        dark,
      );
      // Handlebar + mirror.
      canvas.drawLine(Offset(front.dx - 16, wheelY - 46), Offset(front.dx + 8, wheelY - 52), frame);
      canvas.drawLine(Offset(front.dx - 6, wheelY - 50), Offset(front.dx + 2, wheelY - 68), frame);
      canvas.drawCircle(Offset(front.dx + 2, wheelY - 70), 3, dark);
      // Rear light.
      canvas.drawCircle(Offset(rear.dx - 6, wheelY - 22), 3, Paint()..color = const Color(0xFFD1453B));
    } else {
      // Sport bike, drawn from a few anchor points: swingarm, frame, tank,
      // engine block, fork and handlebar.
      final swingPivot = Offset(104, wheelY - 6);
      final steeringHead = Offset(166, wheelY - 30);
      final exhaust = Paint()..color = const Color(0xFF9AA5A8);

      // Swingarm and frame.
      canvas.drawLine(rear, swingPivot, frame);
      canvas.drawLine(swingPivot, steeringHead, frame);

      // Engine block.
      canvas.drawRRect(
        RRect.fromLTRBR(106, wheelY - 14, 146, wheelY + 2, const Radius.circular(4)),
        dark,
      );

      // Tank sloping towards the seat.
      final tank = Path()
        ..moveTo(102, wheelY - 22)
        ..quadraticBezierTo(118, wheelY - 36, 142, wheelY - 32)
        ..quadraticBezierTo(158, wheelY - 30, 162, wheelY - 22)
        ..lineTo(136, wheelY - 12)
        ..lineTo(104, wheelY - 14)
        ..close();
      canvas.drawPath(tank, main);

      // Seat.
      canvas.drawRRect(
        RRect.fromLTRBR(66, wheelY - 28, 100, wheelY - 20, const Radius.circular(5)),
        dark,
      );

      // Fork, handlebar, headlight, mirror.
      canvas.drawLine(steeringHead, front, frame);
      canvas.drawLine(Offset(154, wheelY - 38), Offset(174, wheelY - 42), frame);
      canvas.drawCircle(steeringHead + const Offset(-2, -6), 5.5, Paint()..color = const Color(0xFFFFE29A));
      canvas.drawLine(Offset(168, wheelY - 44), Offset(172, wheelY - 56), frame);
      canvas.drawCircle(Offset(172, wheelY - 58), 2.6, dark);

      // Exhaust pipe above the rear wheel.
      canvas.drawRRect(
        RRect.fromLTRBR(116, wheelY + 3, 154, wheelY + 9, const Radius.circular(3)),
        exhaust,
      );
    }
  }

  void _wheelAt(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = _wheel);
    canvas.drawCircle(center, radius * 0.52, Paint()..color = _hub);
    canvas.drawCircle(center, radius * 0.18, Paint()..color = _wheel);
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter old) => old.type != type || old.body != body;
}
