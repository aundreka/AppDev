import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../styles.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _clouds;
  late final AnimationController _grassWind;
  late final AnimationController _titleGlow;
  late final AnimationController _buttonFloat;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleScale;
  late final Animation<double> _houseRise;
  late final Animation<double> _glowIntensity;
  late final Animation<double> _floatAnimation;
  late final AudioPlayer _bgm;
  bool _muted = false;

  // Precompute light particle field once (no per-frame RNG)
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _titleFade = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.65, curve: Curves.easeOut));
    _titleScale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.65, curve: Curves.elasticOut)),
    );
    _houseRise = CurvedAnimation(parent: _intro, curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic));

    // Slightly slower loops -> fewer visual changes per second
    _clouds = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
    _grassWind = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _titleGlow = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _buttonFloat = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _glowIntensity = Tween(begin: 0.3, end: 0.8).animate(CurvedAnimation(parent: _titleGlow, curve: Curves.easeInOut));
    _floatAnimation = Tween(begin: -3.0, end: 3.0).animate(CurvedAnimation(parent: _buttonFloat, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _intro.forward();

      // Precaching avoids jank the first time these draw
      final ctx = context;
      precacheImage(const AssetImage('assets/house.png'), ctx);
      precacheImage(const AssetImage('assets/opening.mp3'), ctx); // harmless if not an image
    });

    // Background music
    _bgm = AudioPlayer();
    _unawaited(_bgm.setAudioSource(AudioSource.asset('assets/opening.mp3')));
    _unawaited(_bgm.setLoopMode(LoopMode.one));
    _unawaited(_bgm.setVolume(0.25));
    _unawaited(_bgm.play());
  }

  @override
  void dispose() {
    _intro.dispose();
    _clouds.dispose();
    _grassWind.dispose();
    _titleGlow.dispose();
    _buttonFloat.dispose();
    _bgm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 900;
    final horizonY = size.height * (isNarrow ? 0.53 : 0.55);

    // Prepare particle field sized to screen only once
    if (_particles.isEmpty) {
      final rng = math.Random(42);
      final count = size.width < 500 ? 16 : 24; // fewer on phones
      for (int i = 0; i < count; i++) {
        _particles.add(
          _Particle(
            x: rng.nextDouble() * size.width,
            y: rng.nextDouble() * size.height * 0.6,
            r: 0.6 + rng.nextDouble() * 1.2,
            drift: 10 + rng.nextDouble() * 18,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.red,
      body: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: AppDecorations.sky())),

          // Particles: extremely light now, only paints tiny circles
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _clouds,
              builder: (_, __) => _AtmosphericParticles(progress: _clouds.value, particles: _particles, screenSize: size),
            ),
          ),

          // Grass: painter complexity reduced & isolated
          Positioned(
            left: 0,
            right: 0,
            top: horizonY - (isNarrow ? 70 : 50),
            height: isNarrow ? 150 : 135,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _grassWind,
                  builder: (_, __) => CustomPaint(
                    painter: _GrassLitePainter(
                      windPhase: _grassWind.value * 2 * math.pi,
                      screenWidth: size.width,
                      densityBoost: isNarrow ? 1.3 : 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // House + ground shadow
          Align(
            alignment: Alignment(0, isNarrow ? 0.20 : 0.16),
            child: AnimatedBuilder(
              animation: _intro,
              builder: (_, __) {
                final rise = lerpDouble(80, 0, _houseRise.value)!;
                final opacity = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1.0, curve: Curves.easeOut)).value;
                final houseW = math.min(size.width * 0.9, 1600.0); // downscale target to avoid huge textures

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, rise),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Container(
                            margin: EdgeInsets.only(top: isNarrow ? 200 : 250),
                            width: math.min(size.width * 0.7, 800),
                            height: isNarrow ? 36 : 44,
                            decoration: AppDecorations.groundShadowEllipse(),
                          ),
                        ),
                        // Downscale decode with cacheWidth to reduce GPU upload size
                        Image.asset(
                          'assets/house.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          cacheWidth: (houseW).round(),
                          width: houseW,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating buttons (unchanged visuals)
          Align(
            alignment: const Alignment(0, 0.88),
            child: AnimatedBuilder(
              animation: _buttonFloat,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 32,
                  runSpacing: 20,
                  children: [
                    _EnhancedPillButton(
                      label: 'Activity 1',
                      route: '/a1',
                      delay: 0,
                      base: const Color(0xFF5C0B0B),
                      glow: const Color(0xFFFF5A5A),
                      beforeNav: () { try { _bgm.stop(); } catch (_) {} },
                    ),
                    _EnhancedPillButton(
                      label: 'Activity 2',
                      route: '/a2',
                      delay: 0.25,
                      base: const Color(0xFF4A0C14),
                      glow: const Color(0xFFFF7A5A),
                      beforeNav: () { try { _bgm.stop(); } catch (_) {} },
                    ),
                    _EnhancedPillButton(
                      label: 'Activity 3',
                      route: '/a3',
                      delay: 0.5,
                      base: const Color(0xFF3B0E1C),
                      glow: const Color(0xFFFF9A6A),
                      beforeNav: () { try { _bgm.stop(); } catch (_) {} },
                    ),
                    _EnhancedPillButton(
                      label: 'Activity 4',
                      route: '/a4',
                      delay: 0.75,
                      base: const Color(0xFF2D1024),
                      glow: const Color(0xFFFFBA7A),
                      beforeNav: () { try { _bgm.stop(); } catch (_) {} },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Title stack
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                children: [
                  SizedBox(height: isNarrow ? 40 : 60),
                  AnimatedBuilder(
                    animation: Listenable.merge([_intro, _titleGlow]),
                    builder: (_, __) => Opacity(
                      opacity: _titleFade.value,
                      child: Transform.scale(
                        scale: _titleScale.value,
                        child: Text('HOME', textAlign: TextAlign.center, style: AppTextStyles.title(size.width)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('ALL LABORATORY ACTIVITIES', textAlign: TextAlign.center, style: AppTextStyles.subheading(size.width)),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Side Japanese text (glow anim only affects opacity -> cheap)
          Align(
            alignment: isNarrow ? const Alignment(-0.96, -0.82) : const Alignment(-0.78, -0.75),
            child: AnimatedBuilder(
              animation: _titleGlow,
              builder: (_, __) => RotatedBox(
                quarterTurns: 3,
                child: Opacity(
                  opacity: 0.55 + (_glowIntensity.value - 0.3) * 0.25,
                  child: Text('普通に死ねるなら幸運だ', style: AppTextStyles.japanese(isNarrow, 1, size.width)),
                ),
              ),
            ),
          ),

          Align(
            alignment: isNarrow ? const Alignment(0.96, 0.82) : const Alignment(0.78, 0.75),
            child: RotatedBox(
              quarterTurns: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: AppDecorations.authorTag(),
                child: Text('BY  AUNDREKA  PEREZ', style: AppTextStyles.authorTag(isNarrow, size.width)),
              ),
            ),
          ),

          // Mute button
          Positioned(
            right: 14,
            top: 14,
            child: _MusicButton(
              muted: _muted,
              onToggle: () async {
                setState(() => _muted = !_muted);
                await _bgm.setVolume(_muted ? 0.0 : 0.25);
              },
            ),
          ),

          // Cloud shadow (lightweight gradient ovals, isolated)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _clouds,
              builder: (_, __) => _CloudShadowLite(
                progress: _clouds.value,
                topFraction: isNarrow ? 0.13 : 0.18,
                screenSize: size,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _unawaited(Future<void> f) {}

/// ------------------------------------------------------------
/// Lightweight particles (precomputed)
/// ------------------------------------------------------------
class _Particle {
  final double x, y, r, drift;
  const _Particle({required this.x, required this.y, required this.r, required this.drift});
}

class _AtmosphericParticles extends StatelessWidget {
  final double progress;
  final Size screenSize;
  final List<_Particle> particles;
  const _AtmosphericParticles({
    required this.progress,
    required this.particles,
    required this.screenSize,
  });
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: screenSize,
        painter: _ParticlesPainter(progress: progress, particles: particles),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  _ParticlesPainter({required this.progress, required this.particles});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.10);
    for (final p in particles) {
      // simple horizontal drift
      final x = (p.x + progress * p.drift) % size.width;
      canvas.drawCircle(Offset(x, p.y), p.r, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => old.progress != progress || old.particles != particles;
}

/// ------------------------------------------------------------
/// Cloud shadow (gradient blobs, no expensive MaskFilter blur)
/// ------------------------------------------------------------
class _CloudShadowLite extends StatelessWidget {
  final double progress;
  final double topFraction;
  final Size screenSize;
  const _CloudShadowLite({required this.progress, required this.topFraction, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final travelLeft = lerpDouble(-0.6 * screenSize.width, 1.2 * screenSize.width, progress)!;
    final width = math.max(screenSize.width * 1.5, 1200.0);
    final height = screenSize.height * 1.3;
    final top = screenSize.height * topFraction - height * 0.35;

    return Positioned(
      top: top,
      left: travelLeft - width / 2,
      child: IgnorePointer(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: _CloudShadowLitePainter()),
        ),
      ),
    );
  }
}

class _CloudShadowLitePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    Paint oval(Color c, double a) => Paint()
      ..shader = RadialGradient(
        colors: [c.withOpacity(a), c.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(0, 0), radius: 1)); // shader updated per oval

    void drawOval(Offset center, Size s, Color color, double alpha) {
      final rect = Rect.fromCenter(center: center, width: s.width, height: s.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(alpha), color.withOpacity(0)],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
    }

    drawOval(Offset(w * 0.15, h * 0.20), Size(w * 0.55, h * 0.50), Colors.black, 0.25);
    drawOval(Offset(w * 0.60, h * 0.25), Size(w * 0.60, h * 0.56), Colors.black, 0.22);
    drawOval(Offset(w * 1.05, h * 0.23), Size(w * 0.62, h * 0.58), Colors.black, 0.22);

    drawOval(Offset(w * 0.30, h * 0.65), Size(w * 0.32, h * 0.24), Colors.black, 0.12);
    drawOval(Offset(w * 0.75, h * 0.68), Size(w * 0.34, h * 0.24), Colors.black, 0.12);
  }

  @override
  bool shouldRepaint(covariant _CloudShadowLitePainter oldDelegate) => false;
}

/// ------------------------------------------------------------
/// Grass (lighter painter)
/// ------------------------------------------------------------
class _GrassLitePainter extends CustomPainter {
  final double windPhase;
  final double screenWidth;
  final double densityBoost;
  static const Color _grassBack = Color(0xFF1A1A1A);
  static const Color _grassMid = Color(0xFF0F0F0F);
  static const Color _grassFront = Color(0xFF000000);
  _GrassLitePainter({required this.windPhase, required this.screenWidth, this.densityBoost = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    _paintLayer(canvas, size, 0, _grassBack, 1.00, 2.0 * densityBoost);
    _paintLayer(canvas, size, 1, _grassMid, 1.18, 1.8 * densityBoost);
    _paintLayer(canvas, size, 2, _grassFront, 1.34, 1.6 * densityBoost);
  }

  void _paintLayer(Canvas canvas, Size size, int layer, Color base, double heightMul, double densityMul) {
    final rng = math.Random(13 * layer + 7);
    final baseY = size.height;
    final step = 7.0 / densityMul; // bigger step => fewer blades
    for (double x = -60; x < size.width + 60; x += step + rng.nextDouble() * 2.0) {
      if (rng.nextDouble() < 0.16) continue; // sparser
      final clump = 2 + rng.nextInt(4);
      for (int i = 0; i < clump; i++) {
        final bladeX = x + (i - clump / 2) * (1.2 + rng.nextDouble() * 1.4);
        _blade(canvas, size, rng, bladeX, baseY, base, heightMul, layer);
      }
    }
  }

  void _blade(Canvas canvas, Size size, math.Random rng, double x, double baseY, Color base, double heightMul, int layer) {
    final height = (24 + rng.nextDouble() * 44) * heightMul;
    final width = 1.6 + rng.nextDouble() * 2.2;
    final windStrength = 0.42 + layer * 0.25;
    final windOffset = math.sin(windPhase + x * 0.008) * windStrength * (height / 36);
    final colorVariation = rng.nextDouble() * 0.2 - 0.1;
    final grassColor = Color.lerp(base, colorVariation > 0 ? const Color(0xFF2A2A2A) : const Color(0xFF000000), colorVariation.abs())!;
    final paint = Paint()..color = grassColor;

    final path = Path();
    path.moveTo(x - width / 2, baseY);
    const segments = 4; // fewer segments => cheaper path
    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final y = baseY - height * t;
      final segX = x + windOffset * t * t * t;
      final segW = width * (1 - t * 0.8);
      if (i == segments) {
        path.lineTo(segX, y);
      } else {
        path.lineTo(segX - segW / 2, y);
      }
    }
    for (int i = segments - 1; i >= 0; i--) {
      final t = i / segments;
      final y = baseY - height * t;
      final segX = x + windOffset * t * t * t;
      final segW = width * (1 - t * 0.8);
      path.lineTo(segX + segW / 2, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GrassLitePainter old) =>
      old.windPhase != windPhase || old.densityBoost != densityBoost;
}

/// ------------------------------------------------------------
/// Buttons + Mute
/// ------------------------------------------------------------
class _EnhancedPillButton extends StatefulWidget {
  final String label;
  final String route;
  final double delay;
  final Color base;
  final Color glow;
  final VoidCallback? beforeNav;
  const _EnhancedPillButton({
    required this.label,
    required this.route,
    required this.delay,
    required this.base,
    required this.glow,
    this.beforeNav,
  });
  @override
  State<_EnhancedPillButton> createState() => _EnhancedPillButtonState();
}

class _EnhancedPillButtonState extends State<_EnhancedPillButton> with TickerProviderStateMixin {
  bool _hover = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _shimmerAnimation = Tween(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _shimmerController.repeat(period: const Duration(seconds: 6));
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 900;
    final double? pillWidth = isNarrow ? (width * 0.30).clamp(180.0, 260.0).toDouble() : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          widget.beforeNav?.call();
          Navigator.pushNamed(context, widget.route);
        },
        child: SizedBox(
          width: pillWidth,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..scale(_hover ? 1.06 : 1.0),
            child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: AppDecorations.pill(
                  hover: _hover,
                  shimmerStop: _shimmerAnimation.value,
                  base: widget.base,
                  glow: widget.glow,
                ),
                child: Text(widget.label, style: AppTextStyles.pillButton(_hover, width)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onToggle;
  const _MusicButton({required this.muted, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: muted ? 'Unmute' : 'Mute',
      preferBelow: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
