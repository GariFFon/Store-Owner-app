import 'package:flutter/material.dart';

class OnboardingPageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;

  const OnboardingPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: index == currentPage ? 24.0 : 12.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: index == currentPage ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4.0),
          ),
        );
      }),
    );
  }
}
