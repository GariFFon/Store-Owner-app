import 'package:flutter/material.dart';
import 'package:exanor/screens/onboarding_screen.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData? data;
  final bool isActive;
  final String? title;
  final String? subtitle;
  final Widget? content;

  const OnboardingPage({
    super.key,
    this.data,
    required this.isActive,
    this.title,
    this.subtitle,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If we have content, use the custom layout
    if (content != null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Title
              if (title != null)
                Text(
                  title!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 28,
                  ),
                ),

              // Subtitle
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Content
              content!,

              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    // Full screen image layout for standard onboarding
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen image
          AnimatedScale(
            scale: isActive ? 1.0 : 1.1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: data?.image != null
                ? _buildFullScreenImage(
                    data!.image,
                    data!.title,
                    data!.primaryColor,
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.business,
                      size: 120,
                      color: theme.colorScheme.primary,
                    ),
                  ),
          ),

          // Dark gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath, String title, Color primaryColor) {
    // Check if the image path is a URL or local asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Network image
      return Image.network(
        imagePath,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: primaryColor,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback icon if network image fails to load
          return Icon(_getIconForPage(title), size: 120, color: primaryColor);
        },
      );
    } else {
      // Local asset image
      return Image.asset(
        imagePath,
        width: 200,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          // Fallback icon if asset doesn't exist
          return Icon(_getIconForPage(title), size: 120, color: primaryColor);
        },
      );
    }
  }

  Widget _buildFullScreenImage(
    String imagePath,
    String title,
    Color primaryColor,
  ) {
    // Check if the image path is a URL or local asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Network image
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback gradient background with icon if network image fails to load
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.3),
                  primaryColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                _getIconForPage(title),
                size: 120,
                color: primaryColor,
              ),
            ),
          );
        },
      );
    } else {
      // Local asset image
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          // Fallback gradient background with icon if asset doesn't exist
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.3),
                  primaryColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                _getIconForPage(title),
                size: 120,
                color: primaryColor,
              ),
            ),
          );
        },
      );
    }
  }

  IconData _getIconForPage(String title) {
    if (title.contains('Find')) {
      return Icons.search;
    } else if (title.contains('Book')) {
      return Icons.calendar_today;
    } else if (title.contains('Track')) {
      return Icons.track_changes;
    }
    return Icons.star;
  }
}
