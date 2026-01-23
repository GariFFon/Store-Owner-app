import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'theme_constants.dart';

/// Animated theme switcher widget with popup visual feedback
class AnimatedThemeSwitcher extends StatefulWidget {
  final Widget child;
  final Duration? animationDuration;
  final Curve? animationCurve;

  const AnimatedThemeSwitcher({
    super.key,
    required this.child,
    this.animationDuration,
    this.animationCurve,
  });

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with TickerProviderStateMixin {
  late AnimationController _overlayController;
  late AnimationController _iconController;
  late Animation<double> _overlayAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Overlay animation controller
    _overlayController = AnimationController(
      duration: widget.animationDuration ?? ThemeManager.animationDuration,
      vsync: this,
    );

    // Icon animation controller
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Overlay fade animation
    _overlayAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(
        parent: _overlayController,
        curve: widget.animationCurve ?? ThemeManager.animationCurve,
      ),
    );

    // Icon rotation animation
    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    // Icon scale animation
    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );

    // Listen to theme manager changes
    ThemeManager().addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (ThemeManager().isAnimating) {
      _startAnimation();
    } else {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _overlayController.forward();
    _iconController.repeat();
  }

  void _stopAnimation() {
    _overlayController.reverse();
    _iconController.stop();
    _iconController.reset();
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    _overlayController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,

        // Animated popup overlay during theme transition
        AnimatedBuilder(
          animation: _overlayAnimation,
          builder: (context, child) {
            return _overlayAnimation.value > 0
                ? Container(
                    color: theme.colorScheme.surface.withOpacity(
                      _overlayAnimation.value,
                    ),
                    child: Center(
                      child: Container(
                        padding: ThemeConstants.paddingLarge,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: ThemeConstants.borderRadiusLargeObj,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated theme icon
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _iconRotationAnimation,
                                _iconScaleAnimation,
                              ]),
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _iconScaleAnimation.value,
                                  child: Transform.rotate(
                                    angle:
                                        _iconRotationAnimation.value *
                                        2 *
                                        3.14159,
                                    child: Icon(
                                      ThemeManager().isDark(context)
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      size: ThemeConstants.iconLarge,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(
                              height: ThemeConstants.spacingMedium,
                            ),

                            // Loading text
                            Text(
                              'Switching Theme...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: ThemeConstants.spacingSmall),

                            // Loading progress indicator
                            SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Theme switch button with enhanced animations
class AnimatedThemeSwitchButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final double? size;
  final Color? color;

  const AnimatedThemeSwitchButton({
    super.key,
    this.onPressed,
    this.size,
    this.color,
  });

  @override
  State<AnimatedThemeSwitchButton> createState() =>
      _AnimatedThemeSwitchButtonState();
}

class _AnimatedThemeSwitchButtonState extends State<AnimatedThemeSwitchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = ThemeManager();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: IconButton(
              onPressed: _handleTap,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  themeManager.isDark(context)
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  key: ValueKey(themeManager.isDark(context)),
                  size: widget.size ?? ThemeConstants.iconMedium,
                  color: widget.color ?? theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
