import 'package:flutter/material.dart';

class OnboardingBottomSection extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color primaryColor;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingBottomSection({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.primaryColor,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = currentPage == totalPages - 1;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          // Main Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (!isLastPage) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (!isLastPage) ...[
            const SizedBox(height: 16),

            // Previous Button (only show on non-first pages)
            if (currentPage > 0)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: () {
                    // Go to previous page logic would go here if needed
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: primaryColor.withOpacity(0.3)),
                    ),
                  ),
                  child: Text(
                    'Previous',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
