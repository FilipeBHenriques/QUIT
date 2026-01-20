import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'roulette_constants.dart';

// ============================================================================
// ENHANCED ROULETTE WHEEL COMPONENT
// ============================================================================

class RouletteWheel extends PositionComponent {
  double rotation = 0;
  bool isSpinning = false;
  int? winningNumber;

  final VoidCallback? onSpinComplete;

  // Visual enhancements
  double glowIntensity = 0.0;
  final List<double> segmentHighlights = List.filled(37, 0.0);

  RouletteWheel({required Vector2 position, this.onSpinComplete})
    : super(
        position: position,
        size: Vector2.all(RouletteConstants.wheelRadius * 2),
        anchor: Anchor.center,
      );

  @override
  void update(double dt) {
    super.update(dt);

    if (!isSpinning) {
      // Idle glow effect
      glowIntensity =
          0.2 + (sin(DateTime.now().millisecondsSinceEpoch / 1000) * 0.1);
    }

    // Decay segment highlights
    for (int i = 0; i < segmentHighlights.length; i++) {
      if (segmentHighlights[i] > 0) {
        segmentHighlights[i] = max(0, segmentHighlights[i] - dt * 2);
      }
    }
  }

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

      // Update glow intensity based on speed
      glowIntensity = 1.0 - progress;

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), () => animate());
      } else {
        rotation = targetRotation % (2 * pi); // Normalize rotation
        isSpinning = false;

        // Highlight winning segment
        final winningIndex = RouletteNumbers.wheelOrder.indexOf(winningNumber!);
        segmentHighlights[winningIndex] = 1.0;

        Future.delayed(const Duration(milliseconds: 300), () {
          onSpinComplete?.call();
        });
      }
    }

    animate();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    final center = Offset(size.x / 2, size.y / 2);

    // Draw layered shadows for depth
    _drawShadows(canvas, center);

    // Draw outer rim with metallic effect
    _drawOuterRim(canvas, center);

    // Draw inner rim
    _drawInnerRim(canvas, center);

    // Rotate canvas for wheel
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    // Draw wheel pockets
    _drawWheelPockets(canvas, center);

    // Draw center hub
    _drawCenterHub(canvas, center);

    canvas.restore();

    // Draw static elements (non-rotating)
    _drawPointer(canvas, center);
    _drawGlowEffect(canvas, center);
  }

  void _drawShadows(Canvas canvas, Offset center) {
    // Single shadow layer
    canvas.drawCircle(
      Offset(center.dx + 4, center.dy + 4),
      RouletteConstants.wheelRadius + 5,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawOuterRim(Canvas canvas, Offset center) {
    final rimRadius = RouletteConstants.wheelRadius + 6;

    // Outer rim - dark gray
    canvas.drawCircle(
      center,
      rimRadius,
      Paint()..color = const Color(0xFF1a1a1a),
    );

    // Subtle highlight
    canvas.drawCircle(
      center,
      rimRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawInnerRim(Canvas canvas, Offset center) {
    final innerRimRadius = RouletteConstants.wheelRadius + 2;

    // Dark inner rim
    canvas.drawCircle(
      center,
      innerRimRadius,
      Paint()..color = const Color(0xFF0a0a0a),
    );
  }

  void _drawWheelPockets(Canvas canvas, Offset center) {
    final pocketAngle = (2 * pi) / RouletteConstants.totalNumbers;

    for (int i = 0; i < RouletteConstants.totalNumbers; i++) {
      final number = RouletteNumbers.wheelOrder[i];
      final startAngle = (i * pocketAngle) - (pi / 2);

      // Draw pocket with depth
      _drawPocket(canvas, center, startAngle, pocketAngle, number, i);

      // Draw separator lines
      _drawSeparator(canvas, center, startAngle + pocketAngle);

      // Draw number
      _drawNumber(canvas, center, startAngle + pocketAngle / 2, number);
    }
  }

  void _drawPocket(
    Canvas canvas,
    Offset center,
    double startAngle,
    double pocketAngle,
    int number,
    int index,
  ) {
    final baseColor = RouletteNumbers.getNumberColor(number);
    final highlight = segmentHighlights[index];

    // Main pocket
    final outerPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: RouletteConstants.wheelRadius),
        startAngle,
        pocketAngle,
        false,
      )
      ..close();

    // Apply highlight if winning number
    final pocketColor = highlight > 0
        ? Color.lerp(baseColor, Colors.white, highlight * 0.3)!
        : baseColor;

    canvas.drawPath(outerPath, Paint()..color = pocketColor);
  }

  void _drawSeparator(Canvas canvas, Offset center, double angle) {
    final innerRadius = RouletteConstants.wheelRadius * 0.3;
    final outerRadius = RouletteConstants.wheelRadius;

    final x1 = center.dx + cos(angle) * innerRadius;
    final y1 = center.dy + sin(angle) * innerRadius;
    final x2 = center.dx + cos(angle) * outerRadius;
    final y2 = center.dy + sin(angle) * outerRadius;

    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 1.5,
    );
  }

  void _drawNumber(Canvas canvas, Offset center, double angle, int number) {
    final textRadius = RouletteConstants.wheelRadius * 0.73;
    final textX = center.dx + cos(angle) * textRadius;
    final textY = center.dy + sin(angle) * textRadius;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: RouletteNumbers.getNumberTextColor(number),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(textX, textY);
    canvas.rotate(angle + pi / 2);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  void _drawCenterHub(Canvas canvas, Offset center) {
    final hubRadius = RouletteConstants.wheelRadius * 0.2;

    // Outer ring
    canvas.drawCircle(
      center,
      hubRadius + 3,
      Paint()..color = Colors.white.withOpacity(0.2),
    );

    // Inner hub
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()..color = const Color(0xFF0a0a0a),
    );
  }

  void _drawPointer(Canvas canvas, Offset center) {
    final pointerSize = 28.0;
    final pointerY = center.dy - RouletteConstants.wheelRadius - 18;

    // Pointer shadow
    final shadowPath = Path()
      ..moveTo(center.dx, pointerY + pointerSize + 2)
      ..lineTo(center.dx - pointerSize / 2, pointerY + 2)
      ..lineTo(center.dx + pointerSize / 2, pointerY + 2)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Main pointer path
    final path = Path()
      ..moveTo(center.dx, pointerY + pointerSize) // Point
      ..lineTo(center.dx - pointerSize / 2, pointerY) // Top left
      ..lineTo(center.dx + pointerSize / 2, pointerY) // Top right
      ..close();

    // White fill
    canvas.drawPath(path, Paint()..color = Colors.white);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawGlowEffect(Canvas canvas, Offset center) {
    if (glowIntensity > 0.05) {
      final glowRadius = RouletteConstants.wheelRadius + 20;

      // Subtle white underglow
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..color = Colors.white.withOpacity(glowIntensity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
      );
    }
  }

  int getCurrentNumber() {
    final normalizedRotation = rotation % (2 * pi);
    final pocketAngle = (2 * pi) / RouletteConstants.totalNumbers;
    final pocketIndex =
        ((normalizedRotation + (pi / 2)) / pocketAngle).round() %
        RouletteConstants.totalNumbers;

    return RouletteNumbers.wheelOrder[pocketIndex];
  }
}
