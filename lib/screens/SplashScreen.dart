import 'package:flutter/material.dart';
import 'package:exanor/screens/store_selection_screen.dart';
import 'package:exanor/screens/onboarding_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/in_app_update_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

// ------------------------------------------------
//  OPTIMIZED STAR MODEL
// ------------------------------------------------
class BeamStar {
  final double launchTime; // 0.0 -> 1.0 relative to blast window
  final double theta;
  final Color baseColor;

  BeamStar({
    required this.launchTime,
    required this.theta,
    required this.baseColor,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  // -- Animations --
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _lineReveal;
  late Animation<double> _fillProgress;
  late Animation<double> _blastOpen;
  late Animation<Color?> _activeColor;

  // -- Pre-computed Stars --
  final List<BeamStar> _stars = [];

  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    developer.log(
      '🚀 Cinematic Clear Splash: Initializing',
      name: 'SplashScreen',
    );

    final configLineColor = _hexToColor(
      FirebaseRemoteConfigService.getSplashScreenLineColor(),
    );
    final configBlastColor = _hexToColor(
      FirebaseRemoteConfigService.getSplashScreenColor(),
    );

    _generateStars();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3200,
      ), // Extended for Cinematic feel
    );

    // 1. ENTRANCE (0.0 - 0.20)
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    // 2. REVEAL (0.32 - 0.40)
    _lineReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.40, curve: Curves.easeOutBack),
      ),
    );

    // 3. FILL (0.40 - 0.55)
    _fillProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.55, curve: Curves.easeInOutCubic),
      ),
    );

    // 4. BLAST (Start 0.55 -> End 0.90)
    // Beams play during this window.
    // By 0.90, the blast animation value hits 1.0.
    _blastOpen = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.90, curve: Curves.easeInOutQuad),
      ),
    );

    // COLOR
    _activeColor = ColorTween(begin: configLineColor, end: configBlastColor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.55, 0.70, curve: Curves.easeOut),
          ),
        );

    _controller.forward();
    _initializeApp();
  }

  void _generateStars() {
    final colors = [
      Colors.white,
      Colors.white,
      Colors.white,
      const Color(0xFF2962FF),
      Colors.cyanAccent,
      const Color(0xFFB388FF),
    ];
    final rng = Random(333);
    int starCount = 80;

    for (int i = 0; i < starCount; i++) {
      double fraction = i / starCount;
      // Stars launch between 0.0 and 0.50 of the blast window
      double launch = fraction * 0.50;
      double theta = rng.nextDouble() * 2 * pi;
      Color c = colors[rng.nextInt(colors.length)];

      _stars.add(BeamStar(launchTime: launch, theta: theta, baseColor: c));
    }
  }

  Color _hexToColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Future<void> _initializeApp() async {
    // 3000ms Trigger (Cinematic)
    // Beams finish at 0.85 * 3200 = 2720ms.
    // We wait until 3000ms.
    // Buffer: ~280ms of "Silence" where beams are gone.
    final minSplashDuration = Future.delayed(
      const Duration(milliseconds: 3000),
    );

    final configFuture = _initRemoteConfig();
    final userCheckFuture = _checkUserSession();

    await minSplashDuration;

    await configFuture;
    _isLoggedIn = await userCheckFuture;

    if (mounted) {
      try {
        await InAppUpdateService.instance.checkForCriticalUpdates(context);
      } catch (e) {
        /* proceed */
      }
    }

    if (mounted) await _navigate();
  }

  Future<void> _initRemoteConfig() async {
    try {
      final config = ApiService.getCurrentConfiguration();
      if (config['isConfigurationCached'] != true) {
        await ApiService.initializeConfiguration();
      }
    } catch (e) {
      /* ignore */
    }
  }

  Future<bool> _checkUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      // Check if access token exists
      if (accessToken != null && accessToken.isNotEmpty) {
        developer.log(
          '✅ User session valid - access token verified',
          name: 'SplashScreen',
        );
        return true;
      }
      developer.log(
        '❌ No access token found - user not logged in',
        name: 'SplashScreen',
      );
      return false;
    } catch (e) {
      developer.log('❌ Error checking user session: $e', name: 'SplashScreen');
      return false;
    }
  }

  Future<void> _navigate() async {
    Route createRoute(Widget page) {
      return PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          // FLOAT ARRIVAL
          // Combines Slide, Scale, and Fade for a polished "Landing" feel.
          const curve = Curves.easeOutBack;

          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 0.25),
                end: Offset.zero,
              ).chain(CurveTween(curve: curve)),
            ),
            child: ScaleTransition(
              scale: animation.drive(
                Tween(begin: 0.90, end: 1.0).chain(CurveTween(curve: curve)),
              ),
              child: FadeTransition(
                opacity: animation.drive(
                  Tween(
                    begin: 0.0,
                    end: 1.0,
                  ).chain(CurveTween(curve: Curves.easeOut)),
                ),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(
          milliseconds: 600,
        ), // FASTER CINEMATIC
      );
    }

    if (_isLoggedIn) {
      // NOTE: User app checks profile completion here. Store app might not need that yet or has it differently.
      // Defaulting to StoreSelectionScreen as requested.
      Navigator.of(
        context,
      ).pushReplacement(createRoute(const StoreSelectionScreen()));
    } else {
      Navigator.of(
        context,
      ).pushReplacement(createRoute(const OnboardingScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color matteGrey = Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenW = constraints.maxWidth;
          final double screenH = constraints.maxHeight;
          final double maxDiagonal = sqrt(
            screenW * screenW + screenH * screenH,
          );

          return SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. UI LAYER
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    double t = _controller.value;
                    double shrinkVal = 1.0;

                    if (t >= 0.25 && t <= 0.32) {
                      double dt = (t - 0.25) / 0.07;
                      // Playful "Pop" Anticipation
                      shrinkVal = 1.0 - Curves.easeInBack.transform(dt);
                    } else if (t > 0.32) {
                      shrinkVal = 0.0;
                    }

                    final double logoS = _logoScale.value;
                    final double logoO = _logoOpacity.value;
                    final double lineScale = _lineReveal.value;
                    final double fill = _fillProgress.value;
                    final double blast = _blastOpen.value;
                    final Color currentColor =
                        _activeColor.value ?? const Color(0xFF2962FF);

                    double fixedBarWidth = 220.0;
                    double fixedBarHeight = 4.0;

                    double barW = fixedBarWidth * lineScale;
                    double barH = fixedBarHeight;

                    if (blast > 0) {
                      barW = fixedBarWidth + (blast * (screenW * 4.0));
                      barH = fixedBarHeight + (blast * (screenH * 4.0));
                    }

                    double squeezeSX = logoS * shrinkVal;
                    double squeezeSY = logoS * pow(shrinkVal, 3.0);
                    if (squeezeSX < 0) squeezeSX = 0;
                    if (squeezeSY < 0) squeezeSY = 0;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (shrinkVal > 0.001)
                          Transform(
                            transform: Matrix4.identity()
                              ..scale(squeezeSX, squeezeSY),
                            alignment: Alignment.center,
                            child: Opacity(
                              opacity: logoO,
                              child: SizedBox(
                                width: 250,
                                height: 250,
                                child: Image.asset(
                                  'assets/icon/exanor_store_partner_logo_512x512px.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                        if (lineScale > 0.01)
                          Container(
                            width: barW,
                            height: barH,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                blast > 0.01 ? 0 : 2.0,
                              ),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              children: [
                                Container(color: matteGrey),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (blast > 0) ? 1.0 : fill,
                                    heightFactor: 1.0,
                                    child: Container(color: currentColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // 2. BIG BEAM LAYER
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        if (_blastOpen.value <= 0.01)
                          return const SizedBox.shrink();

                        return CustomPaint(
                          painter: PreComputedBeamPainter(
                            progress: _blastOpen.value,
                            maxDist: maxDiagonal / 1.5,
                            stars: _stars,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------
//  OPTIMIZED PAINTER
// ------------------------------------------------
class PreComputedBeamPainter extends CustomPainter {
  final double progress;
  final double maxDist;
  final List<BeamStar> stars;

  PreComputedBeamPainter({
    required this.progress,
    required this.maxDist,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If progress is 1.0 in the blast phase, everything should be gone.
    // Cutoff to save frames once they are off screen.
    if (progress > 0.95) return;

    final Paint paint = Paint()..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    for (var star in stars) {
      // Blast runs from 0.0 -> 1.0
      double starAge = progress - star.launchTime;

      if (starAge < 0) continue;
      if (starAge > 0.45) continue; // Life duration relative to blast time

      double lifePercent = starAge / 0.45;
      double travelCurve = pow(lifePercent, 2.0).toDouble();

      double dist = (maxDist * 2.5) * travelCurve;
      double length = (40.0 + (travelCurve * 400.0));
      double width = 3.0 + (travelCurve * 15.0);

      double dx = center.dx + dist * cos(star.theta);
      double dy = center.dy + dist * sin(star.theta);

      // FIX: Clamp tail distance to 0.0 to prevent crossing center
      double tailDist = dist - length;
      if (tailDist < 0) tailDist = 0;

      double tailX = center.dx + tailDist * cos(star.theta);
      double tailY = center.dy + tailDist * sin(star.theta);

      double fade = 1.0;
      if (lifePercent < 0.3) {
        fade = lifePercent / 0.3;
      }

      paint.color = star.baseColor.withOpacity(fade);
      paint.strokeWidth = width;

      canvas.drawLine(Offset(tailX, tailY), Offset(dx, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PreComputedBeamPainter old) =>
      old.progress != progress;
}
