import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'login.dart';
import '../data_store.dart';
import '../translations.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool fromLogin;
  const OnboardingScreen({super.key, required this.cameras, this.fromLogin = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finishOnboarding() async {
    try {
      final dir = DataStore().documentsDirectoryPath;
      if (dir != null) {
        final file = File('$dir/onboarding_completed.txt');
        await file.writeAsString('true');
      }
    } catch (e) {
      debugPrint("Erreur sauvegarde statut onboarding: $e");
    }
    if (!mounted) return;
    if (widget.fromLogin) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(cameras: widget.cameras),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching login screen
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E5F5), // Very light purple
                  Colors.white,
                  Color(0xFFEDE7F6), // Very light indigo
                ],
              ),
            ),
          ),
          // Subtle decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        Translations.t('onboarding_btn_skip'),
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Swiping area
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildPage(
                        title: Translations.t('onboarding_title_1'),
                        subtitle: Translations.t('onboarding_subtitle_1'),
                        illustration: _buildMoodDetectionIllustration(),
                      ),
                      _buildPage(
                        title: Translations.t('onboarding_title_2'),
                        subtitle: Translations.t('onboarding_subtitle_2'),
                        illustration: _buildChatbotIllustration(),
                      ),
                      _buildPage(
                        title: Translations.t('onboarding_title_3'),
                        subtitle: Translations.t('onboarding_subtitle_3'),
                        illustration: _buildCoachingIllustration(),
                      ),
                    ],
                  ),
                ),
                // Dots and Actions
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots indicator
                      Row(
                        children: List.generate(
                          3,
                          (index) => _buildDot(index),
                        ),
                      ),
                      // Action button (Next / Get Started)
                      _buildActionButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required Widget illustration,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Center(child: illustration),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4A148C),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Colors.purple.shade900.withOpacity(0.6),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 10,
      width: isActive ? 24 : 10,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF9C27B0) : Colors.purple.shade200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildActionButton() {
    bool isLastPage = _currentPage == 2;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (isLastPage) {
            _finishOnboarding();
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLastPage ? Translations.t('onboarding_btn_start') : Translations.t('onboarding_btn_next'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLastPage ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Mood detection UI mockup with pulsing & scanning animations
  Widget _buildMoodDetectionIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background rings
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.shade100.withOpacity(0.3),
          ),
        ),
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.shade100.withOpacity(0.5),
          ),
        ),
        // Central icon container with pulse animation
        PulsingWidget(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
        // Custom decorative scanner corners
        Positioned(
          top: 15,
          left: 15,
          child: _buildScannerCorner(top: true, left: true),
        ),
        Positioned(
          top: 15,
          right: 15,
          child: _buildScannerCorner(top: true, left: false),
        ),
        Positioned(
          bottom: 15,
          left: 15,
          child: _buildScannerCorner(top: false, left: true),
        ),
        Positioned(
          bottom: 15,
          right: 15,
          child: _buildScannerCorner(top: false, left: false),
        ),
        // Scanning horizontal bar (Animated)
        const ScanningLine(),
        // Detected mood tag mockup
        Positioned(
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sentiment_very_satisfied, color: Colors.green, size: 20),
                const SizedBox(width: 6),
                Text(
                  "Heureux (98%)",
                  style: TextStyle(
                    color: Colors.purple.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerCorner({required bool top, required bool left}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Color(0xFF9C27B0), width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFF9C27B0), width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFF9C27B0), width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFF9C27B0), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  // Slide 2: Chatbot conversation mockup with floating animations
  Widget _buildChatbotIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circles
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.indigo.shade50.withOpacity(0.6),
          ),
        ),
        // Chat bubble user (Right/Top) with floating animation
        Positioned(
          top: 15,
          right: 10,
          child: FloatingWidget(
            offset: 4.0,
            duration: const Duration(seconds: 3),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: const Text(
                "Je me sens stressé aujourd'hui...",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        // Chat bubble AI (Left/Bottom) with floating animation
        Positioned(
          bottom: 15,
          left: 10,
          child: FloatingWidget(
            offset: -4.0,
            duration: const Duration(seconds: 3),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7E57C2), Color(0xFF5C6BC0)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                "Je suis là pour vous aider. Prenons un moment pour respirer ensemble.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        // Robot avatar
        Positioned(
          bottom: 65,
          left: 20,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF5C6BC0)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
        ),
        // User avatar
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.purple.shade800, size: 22),
          ),
        ),
      ],
    );
  }

  // Slide 3: Growth, stats and coaching suggestions mockup
  Widget _buildCoachingIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade50.withOpacity(0.6),
          ),
        ),
        // Stats/Chart card mockup
        Positioned(
          top: 20,
          left: 20,
          child: FloatingWidget(
            offset: 3.0,
            duration: const Duration(seconds: 4),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Progrès",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.trending_up, color: Colors.green, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBar(height: 15, color: Colors.purple.shade200),
                      _buildBar(height: 25, color: Colors.purple.shade300),
                      _buildBar(height: 40, color: Colors.purple.shade400),
                      _buildBar(height: 55, color: const Color(0xFF9C27B0)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Recommandation Card
        Positioned(
          bottom: 25,
          right: 15,
          child: FloatingWidget(
            offset: -3.0,
            duration: const Duration(seconds: 4),
            child: Container(
              width: 170,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF81C784), Color(0xFF4CAF50)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.spa, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        "Conseil du Coach",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Respiration de 5 min conseillée pour vous relaxer.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Wellness central icon
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.self_improvement,
            size: 38,
            color: Color(0xFF9C27B0),
          ),
        ),
      ],
    );
  }

  Widget _buildBar({required double height, required Color color}) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Sub-widgets for premium micro-animations

class PulsingWidget extends StatefulWidget {
  final Widget child;
  const PulsingWidget({super.key, required this.child});

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class ScanningLine extends StatefulWidget {
  const ScanningLine({super.key});

  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2, milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 30 + (120 * _controller.value),
          child: child!,
        );
      },
      child: Container(
        width: 250,
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(0.0),
              Colors.purple.shade400,
              Colors.purple.withOpacity(0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ]
        ),
      ),
    );
  }
}

class FloatingWidget extends StatefulWidget {
  final Widget child;
  final double offset;
  final Duration duration;
  const FloatingWidget({
    super.key,
    required this.child,
    required this.offset,
    required this.duration,
  });

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: widget.offset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
