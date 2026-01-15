import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'roulette_constants.dart';

// ============================================================================
// ROULETTE WHEEL COMPONENT - FIXED
// ============================================================================

class RouletteWheel extends PositionComponent {
  double rotation = 0;
  bool isSpinning = false;
  int? winningNumber;

  final VoidCallback? onSpinComplete;

  RouletteWheel({required Vector2 position, this.onSpinComplete})
    : super(
        position: position,
        size: Vector2.all(RouletteConstants.wheelRadius * 2),
        anchor: Anchor.center,
      );

  void spin(int targetNumber) {
    isSpinning = true;
    winningNumber = targetNumber;

    // Calculate exact target rotation
    final targetIndex = RouletteNumbers.wheelOrder.indexOf(targetNumber);
    final singlePocketAngle = (2 * pi) / RouletteConstants.totalNumbers;

    // Point the pocket to the top (where the arrow is)
    // We need to rotate so the target pocket is at angle 0 (top of wheel)
    final targetAngle = -targetIndex * singlePocketAngle;

    // Add multiple full rotations for spinning effect
    final totalRotation =
        targetAngle + (RouletteConstants.ballRevolutions * 2 * pi);

    _animateSpin(totalRotation);
  }

  void _animateSpin(double targetRotation) {
    final duration = 5000.0; // Fixed 5 seconds for smooth animation

    final startRotation = rotation;
    final startTime = DateTime.now();

    void animate() {
      if (!isSpinning) return; // Safety check

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = (elapsed / duration).clamp(0.0, 1.0);

      // Smooth easing with gradual slowdown
      final eased = progress < 0.8
          ? progress
          : 0.8 + (1 - pow(1 - (progress - 0.8) / 0.2, 3)) * 0.2;

      rotation = startRotation + (targetRotation * eased);

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), animate);
      } else {
        rotation = targetRotation % (2 * pi); // Normalize rotation
        isSpinning = false;
        onSpinComplete?.call();
      }
    }

    animate();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Center point
    final center = Offset(size.x / 2, size.y / 2);

    // Draw shadow
    canvas.drawCircle(
      Offset(center.dx + 4, center.dy + 4),
      RouletteConstants.wheelRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Draw outer rim
    canvas.drawCircle(
      center,
      RouletteConstants.wheelRadius + 5,
      Paint()..color = Colors.grey[900]!,
    );

    // Rotate canvas for wheel
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    _drawWheelPockets(canvas, center);

    canvas.restore();

    // Draw static pointer (after restore, so it doesn't rotate)
    _drawPointer(canvas, center);
  }

  void _drawWheelPockets(Canvas canvas, Offset center) {
    final pocketAngle = (2 * pi) / RouletteConstants.totalNumbers;

    for (int i = 0; i < RouletteConstants.totalNumbers; i++) {
      final number = RouletteNumbers.wheelOrder[i];

      // Start angle - offset by -90 degrees to put 0 at top
      final startAngle = (i * pocketAngle) - (pi / 2);

      // Draw pocket segment
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(
            center: center,
            radius: RouletteConstants.wheelRadius,
          ),
          startAngle,
          pocketAngle,
          false,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()..color = RouletteNumbers.getNumberColor(number),
      );

      // Draw pocket border
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.grey[700]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Draw number text
      final midAngle = startAngle + pocketAngle / 2;
      final textRadius = RouletteConstants.wheelRadius * 0.7;
      final textX = center.dx + cos(midAngle) * textRadius;
      final textY = center.dy + sin(midAngle) * textRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            color: RouletteNumbers.getNumberTextColor(number),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(midAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  void _drawPointer(Canvas canvas, Offset center) {
    // Triangle pointer at top - points DOWN into wheel
    final pointerSize = 25.0;
    final pointerY = center.dy - RouletteConstants.wheelRadius - 15;

    final path = Path()
      ..moveTo(center.dx, pointerY + pointerSize) // Point (pointing down)
      ..lineTo(center.dx - pointerSize / 2, pointerY) // Top left
      ..lineTo(center.dx + pointerSize / 2, pointerY) // Top right
      ..close();

    // Glow effect
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Solid pointer
    canvas.drawPath(path, Paint()..color = Colors.white);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // Helper to get current winning number based on rotation
  int getCurrentNumber() {
    // Normalize rotation to 0-2π
    final normalizedRotation = rotation % (2 * pi);

    // Calculate which pocket is at the top (0 degrees)
    final pocketAngle = (2 * pi) / RouletteConstants.totalNumbers;
    final pocketIndex =
        ((normalizedRotation + (pi / 2)) / pocketAngle).round() %
        RouletteConstants.totalNumbers;

    return RouletteNumbers.wheelOrder[pocketIndex];
  }
}
