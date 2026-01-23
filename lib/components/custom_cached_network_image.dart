import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomCachedNetworkImage extends StatefulWidget {
  final String imgUrl;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;
  final Widget? errorWidget;
  final Color? placeholderColor;

  const CustomCachedNetworkImage({
    super.key,
    required this.imgUrl,
    this.height,
    this.width,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.placeholderColor,
  });

  @override
  State<CustomCachedNetworkImage> createState() =>
      _CustomCachedNetworkImageState();
}

class _CustomCachedNetworkImageState extends State<CustomCachedNetworkImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _buildShimmerPlaceholder() {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.placeholderColor?.withOpacity(0.1) ??
                    theme.colorScheme.surfaceVariant.withOpacity(0.3),
                widget.placeholderColor?.withOpacity(0.3) ??
                    theme.colorScheme.surfaceVariant.withOpacity(0.5),
                widget.placeholderColor?.withOpacity(0.1) ??
                    theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ],
              stops: [0.0, 0.5 + (_shimmerAnimation.value * 0.1), 1.0],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.image,
              size: 24,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    final theme = Theme.of(context);
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: 24,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CachedNetworkImage(
        imageUrl: widget.imgUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }
}
