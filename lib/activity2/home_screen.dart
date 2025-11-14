
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'level1_screen.dart';
import 'level2_screen.dart';
import 'level3_screen.dart';




const String kHighScoreKey = 'grimm_runner_high_score';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _highScore = 0;

  late final AnimationController _titleGlow;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _titleGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.2,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _glow = CurvedAnimation(parent: _titleGlow, curve: Curves.easeInOut);

    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(kHighScoreKey) ?? 0;
    if (!mounted) return;
    setState(() {
      _highScore = saved;
    });
  }

  @override
  void dispose() {
    _titleGlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Stack(
        children: [
          
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF111827)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          
          Positioned(
            left: -24,
            bottom: size.height * 0.18,
            child: const Opacity(
              opacity: 0.08,
              child: _SafeImageAsset(
                assetPath: 'images/activity2/monsters/level1/boss.png',
                width: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: -12,
            bottom: size.height * 0.34,
            child: const Opacity(
              opacity: 0.07,
              child: _SafeImageAsset(
                assetPath: 'images/activity2/monsters/level2/boss.png',
                width: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.24,
            top: size.height * 0.08,
            child: const Opacity(
              opacity: 0.06,
              child: _SafeImageAsset(
                assetPath: 'images/activity2/monsters/level3/boss.png',
                width: 260,
                fit: BoxFit.contain,
              ),
            ),
          ),

          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _glow,
                        child: Text(
                          'GRIMM RUNNER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'High Score: $_highScore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      
                      _LevelCard(
                        title: 'Level 1 — Little Red Riding Hood',
                        subtitle: 'Forest • Wolves • 3 Waves',
                        thumbAsset: 'images/activity2/monsters/level1/boss.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Level1Screen()),
                          );
                        },
                        accent: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 14),
                      _LevelCard(
                        title: 'Level 2 — Hansel & Gretel',
                        subtitle: 'Candy House • Slimes • 4 Waves',
                        thumbAsset: 'images/activity2/monsters/level2/boss.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Level2Screen()),
                          );
                        },
                        accent: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 14),
                      _LevelCard(
                        title: 'Level 3 — Jack & the Beanstalk',
                        subtitle: 'Field • Minotaurs • 5 Waves',
                        thumbAsset: 'images/activity2/monsters/level3/boss.png',
                        onTap: () {
                          Navigator.push(
                            context,
                           MaterialPageRoute(builder: (_) => const Level3Screen()),

                          );
                        },
                        accent: const Color(0xFF2563EB),
                      ),

                      const Spacer(),

                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HomeButton(
                            icon: Icons.settings,
                            label: 'Settings',
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF0B1020),
                                  title: const Text(
                                    'Settings',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Add sound, vibration, and control options here.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          _HomeButton(
                            icon: Icons.refresh,
                            label: 'Reset Score',
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setInt(kHighScoreKey, 0);
                              if (!mounted) return;
                              setState(() => _highScore = 0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('High score reset.')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

                  

class _LevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String thumbAsset;
  final VoidCallback onTap;
  final Color accent;

  const _LevelCard({
    required this.title,
    required this.subtitle,
    required this.thumbAsset,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.15), Colors.white.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: _SafeImageAsset(
                  assetPath: thumbAsset,
                  fit: BoxFit.contain,
                  fallback: Icon(Icons.image_not_supported, color: Colors.white.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.play_arrow_rounded, color: Colors.white.withOpacity(0.9), size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafeImageAsset extends StatelessWidget {
  final String assetPath;
  final double? width;
  final BoxFit fit;
  final Widget? fallback;

  const _SafeImageAsset({
    required this.assetPath,
    this.width,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    
    final container = SizedBox(
      width: width,
      height: width,
      child: Image.asset(
        assetPath,
        width: width,
        height: width,
        fit: fit,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          
          if (fallback != null) {
            return fallback!;
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
    
    return container;
  }
}

class _ComingSoon extends StatelessWidget {
  final String levelName;
  const _ComingSoon({required this.levelName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(levelName),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Text(
          '🚧 $levelName — coming soon!\n\nHook this card to your real level screen.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
