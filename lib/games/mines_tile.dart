import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'mines_constants.dart' show MinesConstants, TileState, TileType;

// ============================================================================
// MINES TILE COMPONENT
// ============================================================================

class MinesTile extends PositionComponent with TapCallbacks {
  final int row;
  final int col;
  final TileType type;
  final Function(int row, int col) onTap;
  final double tileSize;

  TileState state = TileState.hidden;

  // Animation properties
  double _revealProgress = 0.0;
  double _pulsePhase = 0.0;
  bool _isHovered = false;

  MinesTile({
    required this.row,
    required this.col,
    required this.type,
    required this.onTap,
    required this.tileSize,
    required Vector2 position,
  }) : super(
         position: position,
         size: Vector2.all(tileSize),
         anchor: Anchor.center,
       );

  @override
  void update(double dt) {
    super.update(dt);

    // Animate reveal
    if (state == TileState.revealed && _revealProgress < 1.0) {
      _revealProgress = math.min(1.0, _revealProgress + dt * 3.0);
    }

    // Pulse animation for revealed diamonds
    if (state == TileState.revealed && type == TileType.diamond) {
      _pulsePhase += dt * 2.0;
    }

    // Explosion animation for bombs
    if (state == TileState.exploding && _revealProgress < 1.0) {
      _revealProgress = math.min(1.0, _revealProgress + dt * 4.0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(MinesConstants.tileBorderRadius),
    );

    if (state == TileState.hidden) {
      _renderHiddenTile(canvas, rect);
    } else if (state == TileState.revealed) {
      _renderRevealedTile(canvas, rect);
    } else if (state == TileState.exploding) {
      _renderExplodingTile(canvas, rect);
    }
  }

  void _renderHiddenTile(Canvas canvas, RRect rect) {
    // Background
    final bgColor = _isHovered
        ? MinesConstants.tileHoverColor
        : MinesConstants.tileColor;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = MinesConstants.tileBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = MinesConstants.tileBorderWidth;

    canvas.drawRRect(rect, borderPaint);

    // Subtle hover glow
    if (_isHovered) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawRRect(rect, glowPaint);
    }
  }

  void _renderRevealedTile(Canvas canvas, RRect rect) {
    // Animate scale
    final scale = 0.8 + (_revealProgress * 0.2);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (type == TileType.diamond) {
      _renderDiamond(canvas, rect);
    } else {
      _renderBomb(canvas, rect);
    }

    canvas.restore();
  }

  void _renderDiamond(Canvas canvas, RRect rect) {
    // Background
    final bgPaint = Paint()
      ..color = MinesConstants.backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, bgPaint);

    // Pulsing glow
    final pulseIntensity = (math.sin(_pulsePhase) * 0.5 + 0.5) * 0.3;
    final glowPaint = Paint()
      ..color = MinesConstants.diamondColor.withOpacity(pulseIntensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        MinesConstants.glowBlurRadius * pulseIntensity,
      );

    canvas.drawRRect(rect, glowPaint);

    // Border
    final borderPaint = Paint()
      ..color = MinesConstants.diamondColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = MinesConstants.tileBorderWidth * 2;

    canvas.drawRRect(rect, borderPaint);

    // Diamond icon
    _drawDiamondIcon(canvas);
  }

  void _renderBomb(Canvas canvas, RRect rect) {
    // Background (darker)
    final bgPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, bgPaint);

    // Danger glow
    final glowPaint = Paint()
      ..color = MinesConstants.bombColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        MinesConstants.glowBlurRadius,
      );

    canvas.drawRRect(rect, glowPaint);

    // Border
    final borderPaint = Paint()
      ..color = MinesConstants.bombColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = MinesConstants.tileBorderWidth * 2;

    canvas.drawRRect(rect, borderPaint);

    // Bomb icon
    _drawBombIcon(canvas);
  }

  void _renderExplodingTile(Canvas canvas, RRect rect) {
    // Explosion animation
    final explosionScale = 1.0 + (_revealProgress * 0.5);
    final explosionOpacity = 1.0 - _revealProgress;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(explosionScale);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Flashing red background
    final bgPaint = Paint()
      ..color = MinesConstants.bombColor.withOpacity(explosionOpacity * 0.8);

    canvas.drawRRect(rect, bgPaint);

    // Bomb icon
    _drawBombIcon(canvas, opacity: explosionOpacity);

    canvas.restore();

    // Explosion particles effect
    if (_revealProgress < 0.5) {
      _drawExplosionParticles(canvas);
    }
  }

  void _drawDiamondIcon(Canvas canvas, {double opacity = 1.0}) {
    final iconSize = size.x * MinesConstants.iconSizeMultiplier;
    final center = Vector2(size.x / 2, size.y / 2);

    final paint = Paint()
      ..color = MinesConstants.diamondColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    // Diamond shape (geometric)
    final path = Path();

    // Top point
    path.moveTo(center.x, center.y - iconSize / 2);

    // Upper left
    path.lineTo(center.x - iconSize / 4, center.y - iconSize / 6);

    // Lower left
    path.lineTo(center.x - iconSize / 3, center.y + iconSize / 2);

    // Bottom center
    path.lineTo(center.x, center.y + iconSize / 2.5);

    // Lower right
    path.lineTo(center.x + iconSize / 3, center.y + iconSize / 2);

    // Upper right
    path.lineTo(center.x + iconSize / 4, center.y - iconSize / 6);

    // Close to top
    path.close();

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = MinesConstants.diamondColor.withOpacity(opacity * 0.2)
        ..style = PaintingStyle.fill,
    );

    // Outline
    canvas.drawPath(path, paint);

    // Inner lines
    canvas.drawLine(
      Offset(center.x - iconSize / 4, center.y - iconSize / 6),
      Offset(center.x, center.y + iconSize / 2.5),
      paint,
    );
    canvas.drawLine(
      Offset(center.x + iconSize / 4, center.y - iconSize / 6),
      Offset(center.x, center.y + iconSize / 2.5),
      paint,
    );
  }

  void _drawBombIcon(Canvas canvas, {double opacity = 1.0}) {
    final iconSize = size.x * MinesConstants.iconSizeMultiplier;
    final center = Vector2(size.x / 2, size.y / 2);

    final paint = Paint()
      ..color = MinesConstants.bombColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Bomb body (circle)
    canvas.drawCircle(Offset(center.x, center.y), iconSize / 2.5, paint);

    // Fuse
    final fusePaint = Paint()
      ..color = MinesConstants.bombColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.x + iconSize / 4, center.y - iconSize / 4),
      Offset(center.x + iconSize / 2.5, center.y - iconSize / 2),
      fusePaint,
    );

    // Spark
    canvas.drawCircle(
      Offset(center.x + iconSize / 2.5, center.y - iconSize / 2),
      3.0,
      Paint()..color = Colors.orange.withOpacity(opacity),
    );
  }

  void _drawExplosionParticles(Canvas canvas) {
    final particlePaint = Paint()
      ..color = MinesConstants.bombColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final center = Vector2(size.x / 2, size.y / 2);

    // Simple particle burst
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final distance = _revealProgress * size.x * 0.4;
      final particlePos = Vector2(
        center.x + math.cos(angle) * distance,
        center.y + math.sin(angle) * distance,
      );

      canvas.drawCircle(
        Offset(particlePos.x, particlePos.y),
        3.0 * (1.0 - _revealProgress),
        particlePaint,
      );
    }
  }

  void reveal() {
    if (state == TileState.hidden) {
      state = TileState.revealed;
      _revealProgress = 0.0;
    }
  }

  void explode() {
    if (state == TileState.hidden) {
      state = TileState.exploding;
      _revealProgress = 0.0;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (state == TileState.hidden) {
      onTap(row, col);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isHovered = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isHovered = false;
  }

  void setHovered(bool hovered) {
    _isHovered = hovered;
  }
}
