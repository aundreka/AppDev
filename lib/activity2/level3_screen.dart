import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'maps/level3_map.dart';

const Map<WeaponType, Color> kWeaponAccentColors = {
  WeaponType.forcefield: Color(0xFF38BDF8), // cyan
  WeaponType.holySword: Color(0xFFFACC15),  // yellow
  WeaponType.reaperScythe: Color.fromARGB(255, 255, 136, 0), // red
  WeaponType.machineGun: Color(0xFFA855F7), // purple
  WeaponType.goldenGoose: Color(0xFF4ADE80), // green
  WeaponType.holyWand: Color(0xFFFB7185), // pink
};

class Level3Screen extends StatelessWidget {
  const Level3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Level3Map();
    return Scaffold(
      body: GameWidget<Level3Map>(
        game: game,
        overlayBuilderMap: {
          'levelUp': (ctx, Level3Map game) {
            return LevelUpOverlay(game: game);
          },
        },
      ),
    );
  }
}

class LevelUpOverlay extends StatelessWidget {
  final Level3Map game;
  const LevelUpOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final choices = game.currentWeaponChoices;
    return Stack(
      children: [
        // Full black background
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.35),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(8), // smaller = more pixel
                border: Border.all(
                  color: const Color.fromARGB(255, 243, 240, 63), // cyan outer frame
                  width: 3,
                ),
                boxShadow: const [
                  // hard offset shadow → pixel-ish
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(0, 0),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pixel-ish title
                  const Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 0,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CHOOSE YOUR BLESSING',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tiny "pixel" separator
                  Container(
                    height: 3,
                    width: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF38BDF8),
                          Color(0xFFF97316),
                          Color(0xFFFACC15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final w in choices) Expanded(
                        child: _WeaponCard(
                          weapon: w,
                          game: game,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeaponCard extends StatelessWidget {
  final Level3Map game;
  final WeaponType weapon;

  const _WeaponCard({
    required this.game,
    required this.weapon,
  });

  @override
  Widget build(BuildContext context) {
    final info = kWeaponInfos[weapon]!;
    final currentLvl = game.stats.weaponLevels[weapon] ?? 0;
    final nextLvl = (currentLvl + 1).clamp(1, 5);
    final desc = weaponDescription(weapon, nextLvl);

    final accent = kWeaponAccentColors[weapon] ?? const Color(0xFF60A5FA);

    return GestureDetector(
      onTap: () {
        game.chooseWeapon(weapon);
      },
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // Slight “pixel gradient” with weapon color
          gradient: LinearGradient(
            colors: [
              accent.withOpacity(0.25),
              accent.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent,
            width: 3,
          ),
          boxShadow: [
            // hard offset shadow → retro
            BoxShadow(
              color: Colors.black.withOpacity(0.9),
              offset: const Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tiny colored bar at top
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),

            // Image
            SizedBox(
              height: 56,
              child: Image.asset(
                info.imagePath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none, // more pixel-y
              ),
            ),
            const SizedBox(height: 6),

            // Weapon name
            Text(
              info.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Level label
            Text(
              'LV. $nextLvl',
              style: TextStyle(
                color: accent.withOpacity(0.95),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
