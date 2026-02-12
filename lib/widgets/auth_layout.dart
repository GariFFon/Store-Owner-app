import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String subtitle;
  final String leftHeadline;

  const AuthLayout({
    super.key,
    required this.child,
    required this.title,
    required this.subtitle,
    this.leftHeadline = "Unlock Your\nStore Business",
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F4F8,
      ), // Cool Bluish-Grey ("Bluish Cherry" interpretation - crisp & premium)
      body: isDesktop
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // LEFT SIDE - Branding & Illustration
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(isMobile: false),
                const SizedBox(height: 60),
                _buildHeadline(isMobile: false),
                const Spacer(),
                const Center(child: ModernAbstractIllustration()),
                const Spacer(),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center everything
          children: [
            // Mobile Branding
            _buildLogo(isMobile: true),
            const SizedBox(height: 16),
            _buildHeadline(isMobile: true),

            const SizedBox(height: 48), // Spacing between Header and Card
            // Form Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4285F4).withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Stretch for inputs
                children: [
                  _buildFormHeader(context, isMobile: true), // Will be centered
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildCopyright(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo({bool isMobile = false}) {
    return Text(
      'exanor',
      style: GoogleFonts.poppins(
        fontSize: isMobile ? 38 : 42,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4285F4),
      ),
    );
  }

  Widget _buildHeadline({required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: [
          // Elegant Typographic Headline ("Elite/Cursy/Italic")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              leftHeadline.replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28, // Reduced size
                fontStyle: FontStyle.italic,
                fontWeight:
                    FontWeight.w700, // Updated to w700 as per instruction
                color: const Color(0xFF2D2D2D),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Manage inventory, orders & more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    // Desktop Layout (Unchanged)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          leftHeadline,
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Manage inventory, orders & more.',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormHeader(BuildContext context, {bool isMobile = false}) {
    return Column(
      // On mobile, center the title/subtitle. On desktop, start aligned.
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 26 : 32, // Smaller on mobile
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
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

// A cleaner, abstract illustration using standard Icons and Shapes
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
          // Background Blobs (Updated to Blue/Cool tones)
          Positioned(
            right: 20,
            top: 40,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFBBDEFB).withOpacity(0.5), // Soft Blue
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
                color: const Color(0xFFE1BEE7).withOpacity(0.5), // Soft Purple
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Icons composition
          // Main Store Icon
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
              color: Color(0xFF4285F4), // Blue Icon
            ),
          ),

          // Floating Elements
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
            ), // Purple
          ),
          Positioned(
            right: 80,
            top: 20,
            child: _buildFloatingIcon(
              Icons.local_shipping_outlined,
              const Color(0xFF1976D2), // Darker Blue
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
