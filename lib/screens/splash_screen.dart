import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'home_screen.dart';

/// Animated AI Diagnostic Splash Screen for "SV - Vehicle Fault Detection".
///
/// Features:
/// - Rotating 360° radar sweep and expanding concentric sonar rings.
/// - HUD targeting brackets locking onto the vehicle emblem (`assets/app_icon.png`).
/// - Vertical laser scan beam sweeping across the vehicle icon.
/// - Staggered reveal of "SV - Vehicle Fault Detection", Khmer subtitle, and
///   diagnostic telemetry modules (Optics, AI Engine, Khmer/EN Voice).
/// - Uses a finite [AnimationController] so both real devices and widget tests
///   (`tester.pumpAndSettle()`) transition cleanly to [HomeScreen].
class SplashScreen extends ConsumerStatefulWidget {
  final Duration duration;
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2200),
    this.nextScreen = const HomeScreen(),
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _emblemScale;
  late final Animation<double> _emblemOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _telemetryOpacity;
  late final Animation<double> _progressValue;

  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _emblemScale = Tween<double>(begin: 0.68, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _emblemOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.58, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.55, curve: Curves.easeOut),
      ),
    );
    _telemetryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.70, curve: Curves.easeOut),
      ),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.94, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_showHome) {
        setState(() {
          _showHome = true;
        });
      }
    });

    _controller.forward();
  }

  void _skipToHome() {
    if (_showHome) return;
    _controller.stop();
    setState(() {
      _showHome = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showHome) {
      return widget.nextScreen;
    }

    final strings = ref.watch(appStringsProvider);
    final isKm = strings.isKm;

    return Scaffold(
      backgroundColor: const Color(0xFF071126),
      body: GestureDetector(
        key: const Key('splash_skip_area'),
        behavior: HitTestBehavior.opaque,
        onTap: _skipToHome,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final progress = _progressValue.value;
            final percent = (progress * 100).round();
            // Laser line sweeps top-to-bottom-to-top smoothly
            final scanY = (math.sin(t * math.pi * 3.0 - math.pi / 2) + 1) / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Deep navy background gradient + subtle cyber grid
                CustomPaint(
                  painter: _SplashBackdropPainter(progress: t),
                ),

                // 2. Main centered content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        // Top bar with SV badge & Skip button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF38BDF8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'SV · AI VISION v2.5',
                                    style: TextStyle(
                                      color: Color(0xFFE0F2FE),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('splash_skip_button'),
                              onPressed: _skipToHome,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.72),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(
                                Icons.fast_forward_rounded,
                                size: 15,
                              ),
                              label: Text(
                                isKm ? 'រំលង' : 'Skip',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // 3. Animated Radar & Scanner Emblem
                        Opacity(
                          opacity: _emblemOpacity.value,
                          child: Transform.scale(
                            scale: _emblemScale.value,
                            child: SizedBox(
                              width: 240,
                              height: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer radar sweep & sonar waves
                                  CustomPaint(
                                    size: const Size(240, 240),
                                    painter: _DiagnosticRadarPainter(
                                      animationValue: t,
                                    ),
                                  ),

                                  // App Icon inside glowing squircle with laser scan
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.38),
                                          blurRadius: 28,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF2563EB)
                                              .withValues(alpha: 0.45),
                                          blurRadius: 48,
                                          spreadRadius: 6,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8)
                                            .withValues(alpha: 0.65),
                                        width: 1.8,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(
                                            'assets/app_icon.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: const Color(0xFF09183E),
                                              child: const Icon(
                                                Icons.directions_car_filled,
                                                size: 64,
                                                color: Color(0xFF38BDF8),
                                              ),
                                            ),
                                          ),
                                          // Vertical laser scan beam
                                          Positioned(
                                            top: scanY * 124,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    const Color(0xFF38BDF8)
                                                        .withValues(alpha: 0.0),
                                                    const Color(0xFF38BDF8)
                                                        .withValues(
                                                            alpha: 0.85),
                                                    const Color(0xFFF59E0B)
                                                        .withValues(alpha: 0.9),
                                                    const Color(0xFF38BDF8)
                                                        .withValues(alpha: 0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 4. Brand Title & Khmer Subtitle
                        Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlide.value),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Color(0xFFBAE6FD),
                                      Color(0xFF38BDF8),
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'SV - Vehicle Fault Detection',
                                    key: Key('splash_app_title'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ប្រព័ន្ធ AI វិភាគកំហុស និងការខូចខាតរថយន្ត',
                                  key: const Key('splash_khmer_subtitle'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF93C5FD)
                                        .withValues(alpha: 0.92),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // 5. Telemetry Status Modules & Progress Bar
                        Opacity(
                          opacity: _telemetryOpacity.value,
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildTelemetryChip(
                                    icon: Icons.camera_enhance_outlined,
                                    label: isKm ? 'កាមេរ៉ា AI' : 'OPTICS',
                                    active: progress >= 0.15,
                                  ),
                                  _buildTelemetryChip(
                                    icon: Icons.radar_rounded,
                                    label: isKm ? 'ស្កេនកំហុស' : 'FAULT AI',
                                    active: progress >= 0.45,
                                  ),
                                  _buildTelemetryChip(
                                    icon: Icons.record_voice_over_outlined,
                                    label: isKm ? 'សំឡេង ខ្មែរ/EN' : 'VOICE TTS',
                                    active: progress >= 0.75,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 300),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            strings.splashStatusText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.72),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$percent%',
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 6,
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.12),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(
                                            Color(0xFF38BDF8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTelemetryChip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final color =
        active ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.35);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF0EA5E9).withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  final double progress;

  const _SplashBackdropPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF050C1D),
          Color(0xFF09183E),
          Color(0xFF0B2154),
          Color(0xFF060E24),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Subtle radial cyan aura around center
    final center = Offset(size.width / 2, size.height * 0.42);
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0EA5E9).withValues(alpha: 0.22),
          const Color(0xFF2563EB).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.58),
      );
    canvas.drawCircle(center, size.width * 0.58, auraPaint);

    // Subtle diagnostic coordinate grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DiagnosticRadarPainter extends CustomPainter {
  final double animationValue;

  const _DiagnosticRadarPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Expanding concentric sonar rings
    for (int i = 0; i < 3; i++) {
      final phase = (animationValue * 2.2 + i * 0.33) % 1.0;
      final radius = 68.0 + phase * (maxRadius - 68.0);
      final alpha = (1.0 - phase).clamp(0.0, 1.0) * 0.42;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF38BDF8).withValues(alpha: alpha);
      canvas.drawCircle(center, radius, ringPaint);
    }

    // 2. Fixed outer compass ring + degree ticks
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.28);
    canvas.drawCircle(center, maxRadius - 6, outerRingPaint);

    final tickPaint = Paint()
      ..strokeWidth = 1.4
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45);
    for (int i = 0; i < 36; i++) {
      final angle = (i * 10) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final outer = maxRadius - 6;
      final inner = outer - (isMajor ? 7.0 : 3.5);
      final p1 = Offset(
        center.dx + inner * math.cos(angle),
        center.dy + inner * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outer * math.cos(angle),
        center.dy + outer * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Rotating radar sweep cone
    final sweepAngle = animationValue * 4 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    final sweepRect =
        Rect.fromCircle(center: Offset.zero, radius: maxRadius - 8);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 0.65,
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.0),
          const Color(0xFF38BDF8).withValues(alpha: 0.26),
        ],
      ).createShader(sweepRect);
    canvas.drawArc(sweepRect, 0, math.pi * 0.65, true, sweepPaint);
    canvas.restore();

    // 4. HUD Corner Targeting Brackets around the emblem
    final bracketPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.88);
    const halfBox = 78.0;
    const cornerLen = 18.0;

    final corners = [
      // Top-left
      [
        Offset(center.dx - halfBox, center.dy - halfBox + cornerLen),
        Offset(center.dx - halfBox, center.dy - halfBox),
        Offset(center.dx - halfBox + cornerLen, center.dy - halfBox),
      ],
      // Top-right
      [
        Offset(center.dx + halfBox - cornerLen, center.dy - halfBox),
        Offset(center.dx + halfBox, center.dy - halfBox),
        Offset(center.dx + halfBox, center.dy - halfBox + cornerLen),
      ],
      // Bottom-left
      [
        Offset(center.dx - halfBox, center.dy + halfBox - cornerLen),
        Offset(center.dx - halfBox, center.dy + halfBox),
        Offset(center.dx - halfBox + cornerLen, center.dy + halfBox),
      ],
      // Bottom-right
      [
        Offset(center.dx + halfBox - cornerLen, center.dy + halfBox),
        Offset(center.dx + halfBox, center.dy + halfBox),
        Offset(center.dx + halfBox, center.dy + halfBox - cornerLen),
      ],
    ];

    for (final c in corners) {
      final path = Path()
        ..moveTo(c[0].dx, c[0].dy)
        ..lineTo(c[1].dx, c[1].dy)
        ..lineTo(c[2].dx, c[2].dy);
      canvas.drawPath(path, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagnosticRadarPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
