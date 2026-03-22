import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'roulette_constants.dart';

class RouletteWheel extends PositionComponent {
  double rotation = 0;
  bool isSpinning = false;
  int? winningNumber;

  final VoidCallback? onSpinComplete;

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
      glowIntensity =
          0.15 + (sin(DateTime.now().millisecondsSinceEpoch / 1200) * 0.08);
    }
    for (int i = 0; i < segmentHighlights.length; i++) {
      if (segmentHighlights[i] > 0) {
        segmentHighlights[i] = max(0, segmentHighlights[i] - dt * 2);
      }
    }
  }

  void spin(int targetNumber) {
    isSpinning = true;
    winningNumber = targetNumber;

    final targetIndex = RouletteNumbers.wheelOrder.indexOf(targetNumber);
    final singlePocketAngle = (2 * pi) / RouletteConstants.totalNumbers;
    final targetAngle = -targetIndex * singlePocketAngle;
    final totalRotation =
        targetAngle + (RouletteConstants.ballRevolutions * 2 * pi);

    _animateSpin(totalRotation);
  }

  void _animateSpin(double targetRotation) {
    const duration = 5000.0;
    final startRotation = rotation;
    final startTime = DateTime.now();

    void animate() {
      if (!isSpinning) return;

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = (elapsed / duration).clamp(0.0, 1.0);

      final eased = progress < 0.8
          ? progress
          : 0.8 + (1 - pow(1 - (progress - 0.8) / 0.2, 3)) * 0.2;

      rotation = startRotation + (targetRotation * eased);
      glowIntensity = 1.0 - progress;

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), () => animate());
      } else {
        rotation = targetRotation % (2 * pi);
        isSpinning = false;
        final winningIndex =
            RouletteNumbers.wheelOrder.indexOf(winningNumber!);
        segmentHighlights[winningIndex] = 1.0;
        Future.delayed(
          const Duration(milliseconds: 300),
          () => onSpinComplete?.call(),
        );
      }
    }

    animate();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    final center = Offset(size.x / 2, size.y / 2);

    _drawShadows(canvas, center);
    _drawOuterRim(canvas, center);
    _drawInnerRim(canvas, center);

    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    _drawWheelPockets(canvas, center);
    _drawCenterHub(canvas, center);

    canvas.restore();

    _drawPointer(canvas, center);
    _drawGlowEffect(canvas, center);
  }

  void _drawShadows(Canvas canvas, Offset center) {
    canvas.drawCircle(
      Offset(center.dx + 4, center.dy + 6),
      RouletteConstants.wheelRadius + 5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    // Neon rose outer glow
    canvas.drawCircle(
      center,
      RouletteConstants.wheelRadius + 14,
      Paint()
        ..color = const Color(0xFFFF1A5C).withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  void _drawOuterRim(Canvas canvas, Offset center) {
    final rimRadius = RouletteConstants.wheelRadius + 6;

    canvas.drawCircle(
      center,
      rimRadius,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1C1E28), Color(0xFF0A0B12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: rimRadius)),
    );

    // Rose accent ring
    canvas.drawCircle(
      center,
      rimRadius,
      Paint()
        ..color = const Color(0xFFFF1A5C).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawInnerRim(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      RouletteConstants.wheelRadius + 2,
      Paint()..color = const Color(0xFF060810),
    );
  }

  void _drawWheelPockets(Canvas canvas, Offset center) {
    final pocketAngle = (2 * pi) / RouletteConstants.totalNumbers;

    for (int i = 0; i < RouletteConstants.totalNumbers; i++) {
      final number = RouletteNumbers.wheelOrder[i];
      final startAngle = (i * pocketAngle) - (pi / 2);
      _drawPocket(canvas, center, startAngle, pocketAngle, number, i);
      _drawSeparator(canvas, center, startAngle + pocketAngle);
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

    final outerPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: RouletteConstants.wheelRadius),
        startAngle,
        pocketAngle,
        false,
      )
      ..close();

    final pocketColor = highlight > 0
        ? Color.lerp(baseColor, const Color(0xFFFF1A5C), highlight * 0.40)!
        : baseColor;

    canvas.drawPath(outerPath, Paint()..color = pocketColor);
  }

  void _drawSeparator(Canvas canvas, Offset center, double angle) {
    final innerRadius = RouletteConstants.wheelRadius * 0.3;
    final outerRadius = RouletteConstants.wheelRadius;

    canvas.drawLine(
      Offset(
        center.dx + cos(angle) * innerRadius,
        center.dy + sin(angle) * innerRadius,
      ),
      Offset(
        center.dx + cos(angle) * outerRadius,
        center.dy + sin(angle) * outerRadius,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.2,
    );
  }

  void _drawNumber(Canvas canvas, Offset center, double angle, int number) {
    final textRadius = RouletteConstants.wheelRadius * 0.77;
    final textX = center.dx + cos(angle) * textRadius;
    final textY = center.dy + sin(angle) * textRadius;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: RouletteNumbers.getNumberTextColor(number),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0.5, 0.5),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(textX, textY);
    canvas.rotate(-rotation);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  void _drawCenterHub(Canvas canvas, Offset center) {
    final hubRadius = RouletteConstants.wheelRadius * 0.2;

    canvas.drawCircle(
      center,
      hubRadius + 3,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF16182A), Color(0xFF060810)],
        ).createShader(Rect.fromCircle(center: center, radius: hubRadius)),
    );

    // Rose center dot
    canvas.drawCircle(
      center,
      hubRadius * 0.35,
      Paint()..color = const Color(0xFFFF1A5C),
    );

    // Inner glow
    canvas.drawCircle(
      center,
      hubRadius * 0.35,
      Paint()
        ..color = const Color(0xFFFF1A5C).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawPointer(Canvas canvas, Offset center) {
    const pointerSize = 22.0;
    final pointerY = center.dy - RouletteConstants.wheelRadius - 14;

    // Shadow
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, pointerY + pointerSize + 2)
        ..lineTo(center.dx - pointerSize / 2, pointerY + 2)
        ..lineTo(center.dx + pointerSize / 2, pointerY + 2)
        ..close(),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // White pointer
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, pointerY + pointerSize)
        ..lineTo(center.dx - pointerSize / 2, pointerY)
        ..lineTo(center.dx + pointerSize / 2, pointerY)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  void _drawGlowEffect(Canvas canvas, Offset center) {
    if (glowIntensity > 0.04) {
      canvas.drawCircle(
        center,
        RouletteConstants.wheelRadius + 18,
        Paint()
          ..color = const Color(0xFFFF1A5C).withValues(alpha: glowIntensity * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
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
