import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math; // For rotation

class AuthLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String subtitle;
  final String leftHeadline;
  final VoidCallback? onBack;

  const AuthLayout({
    super.key,
    required this.child,
    required this.title,
    required this.subtitle,
    this.leftHeadline = "Unlock Your\nStore Business",
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Revert to Light Neutral Grey
      resizeToAvoidBottomInset: true, // Allow scaffold to resize for keyboard
      body: isDesktop
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    // Icon color for Darker Grey Background
    final iconColor = const Color(0xFF4285F4).withOpacity(0.08);

    return Row(
      children: [
        // LEFT SIDE - Branding & Illustration pattern on Darker Grey Background
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(
              0xFFE2E8F0,
            ), // Darker Grey for "Tablet Image Part"
            child: Stack(
              children: [
                // Background Pattern (Scattered Icons)
                _buildBackgroundIcon(
                  Icons.receipt_long_rounded,
                  top: 40,
                  right: 40,
                  size: 140,
                  angle: -0.2,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.point_of_sale_rounded,
                  top: 150,
                  left: -40,
                  size: 180,
                  angle: 0.1,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.shopping_cart_outlined,
                  bottom: 80,
                  right: -20,
                  size: 160,
                  angle: -0.15,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.inventory_2_outlined,
                  bottom: 150,
                  left: 40,
                  size: 120,
                  angle: 0.2,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.qr_code_scanner_rounded,
                  top: 300,
                  right: 100,
                  size: 80,
                  angle: 0.1,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.calculate_outlined,
                  bottom: 40,
                  left: 150,
                  size: 100,
                  angle: -0.1,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.store_rounded,
                  top: 80,
                  left: 80,
                  size: 90,
                  angle: 0.05,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.local_shipping_outlined,
                  bottom: 300,
                  right: 30,
                  size: 110,
                  angle: -0.1,
                  color: iconColor,
                ),

                // Content Overlay
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogo(isMobile: false), // Default Dark Colors
                        const SizedBox(height: 16),
                        _buildHeadline(isMobile: false), // Default Dark Colors
                        const SizedBox(height: 60),
                        const Center(child: ModernAbstractIllustration()),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // RIGHT SIDE - Form
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFormHeader(context),
                      const SizedBox(height: 40),
                      child,
                      const SizedBox(height: 80),
                      _buildCopyright(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final iconColor = Colors.white.withOpacity(0.08); // White icons for Blue bg

    return Stack(
      children: [
        // 1. Solid Blue Top Background with POS Icons Pattern
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * 0.5,
          child: Container(
            color: const Color(0xFF4285F4), // Brand Blue
            child: Stack(
              children: [
                // Varied POS Icons scattered as background pattern
                _buildBackgroundIcon(
                  Icons.receipt_long_rounded,
                  top: 40,
                  right: 20,
                  size: 100,
                  angle: -0.2,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.point_of_sale_rounded,
                  top: 80,
                  left: -20,
                  size: 120,
                  angle: 0.1,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.shopping_cart_outlined,
                  bottom: 40,
                  right: -10,
                  size: 90,
                  angle: -0.15,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.inventory_2_outlined,
                  bottom: 80,
                  left: 30,
                  size: 80,
                  angle: 0.2,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.qr_code_scanner_rounded,
                  top: 150,
                  right: 80,
                  size: 60,
                  angle: 0.1,
                  color: iconColor,
                ),
                _buildBackgroundIcon(
                  Icons.calculate_outlined,
                  top: 20,
                  left: 100,
                  size: 70,
                  angle: -0.1,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),

        // 2. Scrollable Content
        Positioned.fill(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    // Distribute Vertical Space
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // LOGO SECTION (Centered)
                      Image.asset(
                        'assets/icon/exanor_logo_atxigv.png',
                        width: 240, // Bumped up slightly as requested
                        color: Colors.white,
                      ),

                      const SizedBox(height: 48),

                      // CARD SECTION
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFormHeader(context, isMobile: true),
                            const SizedBox(height: 32),
                            child,
                          ],
                        ),
                      ),

                      // Bottom Spacer
                      const Spacer(flex: 2),

                      // COPYRIGHT
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildCopyright(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper for background icons pattern
  Widget _buildBackgroundIcon(
    IconData icon, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double angle,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _buildLogo({bool isMobile = false, Color? color}) {
    return Transform.translate(
      offset: Offset(isMobile ? 0 : -36, 0), // Shifted further left to counteract image padding
      child: Align(
        alignment: isMobile ? Alignment.center : Alignment.centerLeft,
        child: Image.asset(
          'assets/icon/exanor_logo_atxigv.png',
          height: isMobile ? 72 : 120, // Increased height to make it bolder on tablet
          color: color ?? Colors.black, // Switched to Black for tablet mode
          alignment: isMobile ? Alignment.center : Alignment.centerLeft,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildHeadline({required bool isMobile, Color? color}) {
    if (isMobile) {
      return const SizedBox.shrink(); // Removed on mobile
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          leftHeadline,
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: color ?? const Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Manage inventory, orders & more.',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: color?.withOpacity(0.8) ?? Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormHeader(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(
                height: 40,
                width: 40,
                child: Icon(Icons.arrow_back, size: 24, color: Colors.black54),
              ),
            ),
          ),
        Text(
          title,
          textAlign: TextAlign.start,
          maxLines: 1,
          style: isMobile
              ? GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF2D2D2D),
                )
              : GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D2D2D),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.start,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCopyright() {
    return Center(
      child: Text(
        "© 2026 all rights reserved",
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
      ),
    );
  }
}

class ModernAbstractIllustration extends StatelessWidget {
  const ModernAbstractIllustration({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      width: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 20,
            top: 40,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFBBDEFB).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 40,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFE1BEE7).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.store_mall_directory_rounded,
              size: 80,
              color: Color(0xFF4285F4),
            ),
          ),
          Positioned(
            left: 40,
            top: 60,
            child: _buildFloatingIcon(
              Icons.shopping_bag_outlined,
              Colors.orange,
            ),
          ),
          Positioned(
            right: 40,
            bottom: 80,
            child: _buildFloatingIcon(
              Icons.checkroom_rounded,
              const Color(0xFFAB47BC),
            ),
          ),
          Positioned(
            right: 80,
            top: 20,
            child: _buildFloatingIcon(
              Icons.local_shipping_outlined,
              const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
