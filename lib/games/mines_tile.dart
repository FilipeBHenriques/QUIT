import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'mines_constants.dart' show MinesConstants, TileState, TileType;
import 'package:quit/theme/game_icons.dart';

class MinesTile extends PositionComponent with TapCallbacks {
  final int row;
  final int col;
  final TileType type;
  final Function(int row, int col) onTap;
  final double tileSize;

  TileState state = TileState.hidden;

  double _revealProgress = 0.0;
  double _pulsePhase = 0.0;
  bool _isHovered = false;

  // Neon palette constants
  static const Color _diamondColor = Color(0xFF00F0FF); // electric cyan
  static const Color _bombColor = Color(0xFFFF1A5C);    // neon rose
  static const Color _tileBg = Color(0xFF0A0C14);
  static const Color _tileBgHover = Color(0xFF0F111C);
  static const Color _tileBorder = Color(0xFF1C1E2A);

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
    if (state == TileState.revealed && _revealProgress < 1.0) {
      _revealProgress = math.min(1.0, _revealProgress + dt * 3.2);
    }
    if (state == TileState.revealed && type == TileType.diamond) {
      _pulsePhase += dt * 2.2;
    }
    if (state == TileState.exploding && _revealProgress < 1.0) {
      _revealProgress = math.min(1.0, _revealProgress + dt * 4.0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );

    switch (state) {
      case TileState.hidden:
        _renderHiddenTile(canvas, rect);
      case TileState.revealed:
        _renderRevealedTile(canvas, rect);
      case TileState.exploding:
        _renderExplodingTile(canvas, rect);
    }
  }

  void _renderHiddenTile(Canvas canvas, RRect rect) {
    // Background
    canvas.drawRRect(
      rect,
      Paint()..color = _isHovered ? _tileBgHover : _tileBg,
    );

    // Hairline border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _tileBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Hover glow
    if (_isHovered) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _renderRevealedTile(Canvas canvas, RRect rect) {
    final scale = 0.82 + (_revealProgress * 0.18);
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
    final pulse = (math.sin(_pulsePhase) * 0.5 + 0.5);

    // Base — deep dark
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF060912));

    // Pulse glow ring
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _diamondColor.withValues(alpha: 0.06 + pulse * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + pulse * 6),
    );

    // Border — bright cyan when pulsing
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _diamondColor.withValues(alpha: 0.35 + pulse * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _drawDiamondIcon(canvas);
  }

  void _renderBomb(Canvas canvas, RRect rect) {
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF0A0608));

    canvas.drawRRect(
      rect,
      Paint()
        ..color = _bombColor.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = _bombColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _drawBombIcon(canvas);
  }

  void _renderExplodingTile(Canvas canvas, RRect rect) {
    final scale = 1.0 + (_revealProgress * 0.45);
    final opacity = 1.0 - _revealProgress;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    canvas.drawRRect(
      rect,
      Paint()..color = _bombColor.withValues(alpha: opacity * 0.75),
    );

    _drawBombIcon(canvas, opacity: opacity);
    canvas.restore();

    if (_revealProgress < 0.5) {
      _drawExplosionParticles(canvas);
    }
  }

  void _drawDiamondIcon(Canvas canvas, {double opacity = 1.0}) {
    final center = Offset(size.x / 2, size.y / 2);

    // Soft glow behind icon
    canvas.drawCircle(
      center,
      size.x * 0.22,
      Paint()
        ..color = _diamondColor.withValues(alpha: 0.22 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final diamondPainter = TextPainter(
      text: TextSpan(
        text: kDiamondGlyph,
        style: TextStyle(
          color: _diamondColor.withValues(alpha: opacity),
          fontSize: size.x * 0.44,
          fontWeight: FontWeight.w700,
          fontFamily: 'MaterialIcons',
          shadows: [
            Shadow(
              color: _diamondColor.withValues(alpha: 0.80 * opacity),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    diamondPainter.paint(
      canvas,
      Offset(
        center.dx - diamondPainter.width / 2,
        center.dy - diamondPainter.height / 2,
      ),
    );
  }

  void _drawBombIcon(Canvas canvas, {double opacity = 1.0}) {
    final iconSize = size.x * MinesConstants.iconSizeMultiplier;
    final center = Offset(size.x / 2, size.y / 2);

    final bodyPaint = Paint()
      ..color = _bombColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, iconSize / 2.5, bodyPaint);

    final fusePaint = Paint()
      ..color = _bombColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx + iconSize / 4, center.dy - iconSize / 4),
      Offset(center.dx + iconSize / 2.5, center.dy - iconSize / 2),
      fusePaint,
    );

    // Spark — amber
    canvas.drawCircle(
      Offset(center.dx + iconSize / 2.5, center.dy - iconSize / 2),
      2.5,
      Paint()..color = const Color(0xFFFFAB00).withValues(alpha: opacity),
    );
  }

  void _drawExplosionParticles(Canvas canvas) {
    final particlePaint = Paint()
      ..color = _bombColor.withValues(alpha: 0.7 * (1 - _revealProgress))
      ..style = PaintingStyle.fill;

    final center = Offset(size.x / 2, size.y / 2);
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final distance = _revealProgress * size.x * 0.45;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        ),
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
    if (state == TileState.hidden) onTap(row, col);
  }

  @override
  void onTapUp(TapUpEvent event) => _isHovered = false;

  @override
  void onTapCancel(TapCancelEvent event) => _isHovered = false;

  void setHovered(bool hovered) => _isHovered = hovered;
}
