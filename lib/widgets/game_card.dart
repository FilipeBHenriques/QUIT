import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum GameCardVariant { success, destructive, muted, gold, primary }

enum GameCardSize { sm, defaultSize, lg }

class GameCard extends StatefulWidget {
  final IconData icon;
  final String? iconGlyph;
  final String label;
  final VoidCallback? onClick;
  final GameCardVariant variant;
  final GameCardSize size;

  const GameCard({
    super.key,
    required this.icon,
    this.iconGlyph,
    required this.label,
    this.onClick,
    this.variant = GameCardVariant.muted,
    this.size = GameCardSize.defaultSize,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isTapped = false;

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _yAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _yAnimation = Tween<double>(
      begin: 0.0,
      end: -5.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isTapped = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isTapped = false);
  }

  void _handleTapCancel() {
    setState(() => _isTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color borderColor;
    Color hoverBorderColor;
    Color hoverBackgroundColor;

    switch (widget.variant) {
      case GameCardVariant.success:
        backgroundColor = const Color(0xFF0F141B);
        borderColor = const Color(0xFF1F2937);
        hoverBorderColor = const Color(0xFF9CA3AF);
        hoverBackgroundColor = const Color(0xFF131A22);
        break;
      case GameCardVariant.destructive:
        backgroundColor = const Color(0xFF150C0F);
        borderColor = const Color(0xFF3B1118);
        hoverBorderColor = const Color(0xFFEF4444);
        hoverBackgroundColor = const Color(0xFF1C0E12);
        break;
      case GameCardVariant.gold:
        backgroundColor = Colors.amber.withOpacity(0.2);
        borderColor = Colors.amber.withOpacity(0.5);
        hoverBorderColor = Colors.amber;
        hoverBackgroundColor = Colors.amber.withOpacity(0.3);
        break;
      case GameCardVariant.primary:
        backgroundColor = const Color(0xFF10141E);
        borderColor = const Color(0xFF1B2A45);
        hoverBorderColor = const Color(0xFF60A5FA);
        hoverBackgroundColor = const Color(0xFF131B2A);
        break;
      case GameCardVariant.muted:
        backgroundColor = theme.colorScheme.secondary;
        borderColor = theme.colorScheme.border;
        hoverBorderColor = theme.colorScheme.mutedForeground;
        hoverBackgroundColor = theme.colorScheme.secondary.withOpacity(0.8);
        break;
    }

    double minWidth;
    double verticalPadding;
    double horizontalPadding;

    switch (widget.size) {
      case GameCardSize.sm:
        minWidth = 100;
        verticalPadding = 16;
        horizontalPadding = 20;
        break;
      case GameCardSize.lg:
        minWidth = 150;
        verticalPadding = 24;
        horizontalPadding = 32;
        break;
      case GameCardSize.defaultSize:
        minWidth = 120;
        verticalPadding = 20;
        horizontalPadding = 24;
        break;
    }

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onClick,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double currentScale = _isTapped ? 0.98 : _scaleAnimation.value;
            return Transform.translate(
              offset: Offset(0, _yAnimation.value),
              child: Transform.scale(scale: currentScale, child: child),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: BoxConstraints(minWidth: minWidth),
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: _isHovered ? hoverBackgroundColor : backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered ? hoverBorderColor : borderColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isHovered ? hoverBorderColor : borderColor)
                      .withOpacity(0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    widget.iconGlyph == null
                        ? Icon(
                            widget.icon,
                            size: 22,
                            color: theme.colorScheme.foreground,
                          )
                        : Text(
                            widget.iconGlyph!,
                            style: TextStyle(
                              color: theme.colorScheme.foreground,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Play for time',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
