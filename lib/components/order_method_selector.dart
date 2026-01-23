import 'dart:ui';
import 'package:flutter/material.dart';

class OrderMethodSelector extends StatelessWidget {
  final List<dynamic> methods;
  final String? selectedMethodId;
  final Function(String) onMethodSelected;

  const OrderMethodSelector({
    super.key,
    required this.methods,
    required this.selectedMethodId,
    required this.onMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(
                      0.15,
                    ), // Daker for visibility on off-white background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                // Inner highlight attempt (simulated via gradient or just relied on border)
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int selectedIndex = methods.indexWhere(
                  (m) => m['id'] == selectedMethodId,
                );
                final double tabWidth = constraints.maxWidth / methods.length;

                return Stack(
                  children: [
                    // Moving Liquid Indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      left: selectedIndex < 0 ? 0 : selectedIndex * tabWidth,
                      top: 4,
                      bottom: 4,
                      width: tabWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      theme.colorScheme.primary.withOpacity(
                                        0.9,
                                      ),
                                      theme.colorScheme.primary.withOpacity(
                                        0.7,
                                      ),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.7),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tab Items
                    Row(
                      children: methods.map((method) {
                        final bool isSelected =
                            method['id'] == selectedMethodId;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onMethodSelected(method['id']),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontFamily:
                                      'SF Pro Display', // Assuming standard iOS font or similar
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                  letterSpacing: 0.5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (method['img_url'] != null &&
                                        method['img_url'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6.0,
                                        ),
                                        child: Image.network(
                                          method['img_url'],
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const SizedBox.shrink(),
                                        ),
                                      ),
                                    Text(
                                      // Try to find the name field, fallback to 'Unknown'
                                      method['order_method_name'] ??
                                          method['name'] ??
                                          'Unknown',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
