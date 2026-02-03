import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum GameCardVariant { success, destructive, muted, gold, primary }

enum GameCardSize { sm, defaultSize, lg }

class GameCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onClick;
  final GameCardVariant variant;
  final GameCardSize size;

  const GameCard({
    super.key,
    required this.icon,
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
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green.withOpacity(0.5);
        hoverBorderColor = Colors.green;
        hoverBackgroundColor = Colors.green.withOpacity(0.3);
        break;
      case GameCardVariant.destructive:
        backgroundColor = theme.colorScheme.destructive.withOpacity(0.2);
        borderColor = theme.colorScheme.destructive.withOpacity(0.5);
        hoverBorderColor = theme.colorScheme.destructive;
        hoverBackgroundColor = theme.colorScheme.destructive.withOpacity(0.3);
        break;
      case GameCardVariant.gold:
        backgroundColor = Colors.amber.withOpacity(0.2);
        borderColor = Colors.amber.withOpacity(0.5);
        hoverBorderColor = Colors.amber;
        hoverBackgroundColor = Colors.amber.withOpacity(0.3);
        break;
      case GameCardVariant.primary:
        backgroundColor = theme.colorScheme.primary.withOpacity(0.2);
        borderColor = theme.colorScheme.primary.withOpacity(0.5);
        hoverBorderColor = theme.colorScheme.primary;
        hoverBackgroundColor = theme.colorScheme.primary.withOpacity(0.3);
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 24,
                  color: theme.colorScheme.foreground,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
