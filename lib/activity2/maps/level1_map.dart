import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame/events.dart';// import 'package:your_app/lose.dart';

/* ============================ CONFIG ============================ */

// Pan speed (how fast the world pans under the player), px/s
const double kPanSpeed = 240;

// World streaming radii (around the player/camera)
const double kFloorRadiusPx = 3000; // floor tile preload radius
const double kChunkRadiusPx = 3200; // assets chunk preload radius

// Asset chunk size (world-space square per chunk)
const double kChunkSize = 1024;

// Decoration sizing — smaller
const double kDecorationMinScale = 0.18;
const double kDecorationMaxScale = 0.48;

// Decoration density / layout
const int kBaseDecorationsPerChunk = 22;
const int kClustersPerChunk = 3;
const int kClusterItemsMean = 9;
const double kClusterRadius = 160;

// Combat / feel
const double kUnitPx = 10;               // 1 "range" unit == 32 px
const double kEnemyTouchCooldown = 0.6;  // seconds between enemy hits
const double kEnemyNearRadiusMin = 140;  // spawn ring
const double kEnemyNearRadiusMax = 220;
const double kPlayerAttackPeriod = 1.0;  // 1 hit per second (single target)

// Enemy sprite paths (relative to assets/ root in pubspec)
const String FROG_SPRITE_PATH = 'activity2/monsters/level1/frog.png';
const String BAT_SPRITE_PATH  = 'activity2/monsters/level1/bat.png';
const String FOX_SPRITE_PATH  = 'activity2/monsters/level1/fox.png';
const String BOSS_SPRITE_PATH = 'activity2/monsters/level1/boss.png';

// Exact filenames under assets/activity2/maps/level1/assets/
const List<String> kDecorFilenames = [
  'altar.png','bear.png','bridge.png','bush3.png','bush4.png',
  'fern1.png','fern2.png','fern3.png',
  'rock1.png','rock2.png','rock3.png','rock4.png','rock5.png','rock6.png',
  'rock7.png','rock8.png','rock9.png','rock10.png','rock11.png','rock12.png',
  'roots1.png','roots2.png','roots3.png',
  'stick1.png','stick2.png','stick3.png','stick4.png','stick5.png','stick6.png','stick7.png',
  'stump1.png','stump2.png','stump3.png','stump4.png',
  'toadstoolring.png','standingstone1.png','standingstone2.png','standingstone3.png',
  'log1.png','log2.png','log3.png',
  'tree1.png','tree2.png','tree3.png','tree4.png',
  'whitemushrooms.png','redmushrooms1.png','redmushrooms2.png',
  'giantmushroom1.png','giantmushroom2.png','giantmushroom3.png',
  'skeleton.png','skeleton1.png','skeleton2.png',
  'signpost.png','spidernest1.png','spidernest2.png','totem.png','wall.png',
  'beehive.png','nest.png','pillar.png','fence.png','bush1.png','bush2.png','sis.png',
];

/* ============================ PLAYER STATS (with EXP) ============================ */

class PlayerStats {
  static const int maxLevel = 10;

  int level;
  double hp;        // current HP
  double maxHp;     // maximum HP
  double dps;       // damage per hit (single target)
  double range;     // "units" (× kUnitPx)
  int exp;          // current exp toward next level
  int nextLevelExp; // requirement for next level

  PlayerStats._({
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.dps,
    required this.range,
    required this.exp,
    required this.nextLevelExp,
  });

  factory PlayerStats.base() => PlayerStats._(
        level: 0,
        hp: 300,
        maxHp: 300,
        dps: 10,
        range: 1.5,
        exp: 0,
        nextLevelExp: 100, // 100 × (level+1)
      );

  bool get isDead => hp <= 0;

  void takeDamage(double amount) {
    hp = (hp - amount).clamp(0, maxHp);
  }

  void heal(double amount) {
    hp = (hp + amount).clamp(0, maxHp);
  }

  void gainExp(int amount) {
    if (level >= maxLevel) return;
    exp += amount;
    while (level < maxLevel && exp >= nextLevelExp) {
      exp -= nextLevelExp;
      levelUp();
    }
  }

  void levelUp() {
    if (level >= maxLevel) return;
    level += 1;

    // Simple scaling — tweak to taste
    maxHp *= 1.06;
    dps   *= 1.08; // give a bit more punch per level

    hp = maxHp; // restore on level-up
    nextLevelExp = 100 * (level + 1);
  }
}

/* ============================ ENEMIES ============================ */



/* ============================ GAME ============================ */

class Level1Map extends FlameGame {
  // HUD
  late final JoystickComponent _joystick;
  HudPlayer? _playerHud;

  // HUD: HP bar and score label
  HudHpBar? _hpBar;
  TextComponent? _scoreText;

  // Scores
  int _currentScore = 0;
  int _highScore = 0;
  static const _prefsKeyHighScore = 'level1_high_score';

  // Stats
  late final PlayerStats stats;

  // World root
  late final WorldLayer _world;

  // Sprites cache (map/world)
  final Map<String, Sprite> _spriteCache = {};

  // Enemy sprites
  final Map<EnemyKind, Sprite> enemySprites = {};

  // Floor tiling
  late final ui.Image _floorImage;
  late final Sprite _floorSprite;
  int _floorTileW = 512;
  int _floorTileH = 512;

  // Player world center
final Vector2 _worldCenter = Vector2.zero();
Vector2 get playerWorldCenter => _worldCenter; // <- use this everywhere
  final Random _rng  = Random();



  // Managers
  late final FloorGrid _floorGrid;
  late final ChunkManager _chunkManager;



late final HudWaveMeter _waveMeter = HudWaveMeter(
  width: 280,
  height: 10,
  flags: kWaveFlags,
  total: kTimelineTotal,
)
  ..priority = 1003
  ..anchor = Anchor.topLeft; // <- top-left now


  // Total timeline length up to boss spawn (seconds)
  static const double kTimelineTotal = 180;
  // Flag markers (seconds) for W1, W2, Boss
  static const List<double> kWaveFlags = [30, 120, 180];

  // Clock
  double _t = 0;

  // Wave timers / cursors
  double _nextPreW1 = 1;   // 0–30s: 3 bats/sec
  double _nextW1 = 30;     // 30–60s: every 5s, 50 bats total
  int _w1TicksLeft = 6;    // 6 ticks ~10 each
  double _nextPreW2 = 61;  // 60–120s: per second
  double _nextW2 = 120;    // 120–150s: every 5s, 50 foxes total
  int _w2TicksLeft = 6;
  double _nextPreW3 = 151; // 150–180s: per second
  bool _bossSpawned = false;

  // Combat (player)
  double _attackCooldown = 0;

  // Enemy registry
  final Set<Enemy> _enemies = {};
  
  @override
  void onError(Object error, StackTrace stackTrace) {
    debugPrint('❌ Level1Map crashed: $error\n$stackTrace');
  }

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    stats = PlayerStats.base();

    // Map floor + decorations
    await images.load('activity2/maps/level1/floor.png');
    _floorImage = images.fromCache('activity2/maps/level1/floor.png');
    _floorSprite = Sprite(_floorImage);
    _floorTileW = _floorImage.width;
    _floorTileH = _floorImage.height;

    for (final name in kDecorFilenames) {
      final path = 'activity2/maps/level1/assets/$name';
      await images.load(path);
      _spriteCache[name] = Sprite(images.fromCache(path));
    }

    // Player sprite
    await images.load('activity2/players/level1.png');
    final playerSprite = Sprite(images.fromCache('activity2/players/level1.png'));

    // Enemy sprites
    await _safeLoadSprite(EnemyKind.frog,  FROG_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.bat,   BAT_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.fox,   FOX_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.boss,  BOSS_SPRITE_PATH);

    // World
_world = WorldLayer()..priority = 0;
add(_world);

camera.world = _world;                // <-- important!
camera.viewfinder.anchor = Anchor.center;
camera.viewfinder.position = Vector2.zero();


    _floorGrid = FloorGrid(
      floorSprite: _floorSprite,
      tileSize: Vector2(_floorTileW.toDouble(), _floorTileH.toDouble()),
    );
    _world.add(_floorGrid);

    _chunkManager = ChunkManager(
      spriteCache: _spriteCache,
      chunkSize: kChunkSize,
    );
    _world.add(_chunkManager);

    // Camera static
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2.zero();

    // Joystick bottom-right
    _joystick = JoystickComponent(
      knob: CircleComponent(radius: 26, paint: Paint()..color = const Color(0xFF0F172A)),
      background: CircleComponent(radius: 56, paint: Paint()..color = const Color(0x330F172A)),
      margin: const EdgeInsets.only(right: 24, bottom: 24),
    )
      ..priority = 1000
      ..anchor = Anchor.bottomRight;
    await camera.viewport.add(_joystick);

    // Player HUD
    _playerHud = HudPlayer(sprite: playerSprite)..priority = 1001;
    await camera.viewport.add(_playerHud!);
    _playerHud!.position = size / 2;

    // HP bar
    _hpBar = HudHpBar(
      statsProvider: () => stats,
      width: 110,
      height: 12,
      offsetAboveHead: 0,
    )..priority = 1002;
    await _playerHud!.add(_hpBar!);

    final _lvlBadge = HudLevelBadge(
      statsProvider: () => stats,
      barWidth: 110,
      barHeight: 12,
      offsetAboveHead: 0,
    )..priority = 1002;
    await _playerHud!.add(_lvlBadge);


    // Score (top-right)
    _scoreText = TextComponent(
      text: 'Score 0  |  Best 0',
      anchor: Anchor.topRight,
      priority: 1003,
    )..position = Vector2(size.x - 16, 12);
    await camera.viewport.add(_scoreText!);

    await _loadHighScore();

_waveMeter.position = Vector2(8, 32);

await camera.viewport.add(_waveMeter);
_updateHudForSize(size);

    _refreshScoreText();

    _refreshStreaming();
  }

  Future<void> _safeLoadSprite(EnemyKind kind, String path) async {
    try {
      await images.load(path);
      enemySprites[kind] = Sprite(images.fromCache(path));
    } catch (e) {
      debugPrint('⚠️ Failed to load $path: $e');
    }
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    final hud = _playerHud;
    if (hud != null) hud.position = s / 2;
_scoreText?.position = Vector2(s.x - 16, 12);
_updateHudForSize(s);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _t += dt;
    final clamped = _t.clamp(0, kTimelineTotal);
    _waveMeter.progress = clamped / kTimelineTotal;

final mm = (clamped ~/ 60).toString().padLeft(2, '0');
final ss = (clamped % 60).toInt().toString().padLeft(2, '0');

    final dir = _joystick.relativeDelta;
    if (dir.length2 > 1e-4) {
      _worldCenter.add(dir.normalized() * (kPanSpeed * dt));
      camera.viewfinder.position = _worldCenter;  
      _refreshStreaming();
    }

    _runSpawns();

    // Player attack
    _attackCooldown = max(0, _attackCooldown - dt);
    if (_attackCooldown <= 0) {
      if (_attackNearestEnemyInRange()) {
        _attackCooldown = kPlayerAttackPeriod;
      }
    }

    // Lose
    if (stats.isDead) {
      _goToLose();
    }
  }

  /* ===================== PLAYER ATTACK ===================== */

  bool _attackNearestEnemyInRange() {
    if (_enemies.isEmpty) return false;

    final rangePx = stats.range * kUnitPx;
    final range2 = rangePx * rangePx;

    Enemy? target;
    double bestD2 = double.infinity;

    for (final e in _enemies) {
      final d2 = (e.position - _worldCenter).length2;
      if (d2 <= range2 && d2 < bestD2) {
        bestD2 = d2;
        target = e;
      }
    }

    if (target != null) {
      target.takeDamage(stats.dps);
      return true;
    }
    return false;
  }

  /* ===================== SPAWNS ===================== */

  void _runSpawns() {
    // Helper: spawn ring around player
Vector2 spawnNear() {
  final ang = _rng.nextDouble() * pi * 2;
  final rad = ui.lerpDouble(kEnemyNearRadiusMin, kEnemyNearRadiusMax, _rng.nextDouble())!;
  final offset = Vector2(cos(ang), sin(ang)) * rad;
  return playerWorldCenter + offset; // <-- target is player center in world space
}


    // 0–30s: 3 bats every second
    while (_t >= _nextPreW1 && _t < 30) {
      _nextPreW1 += 1;
      for (int i = 0; i < 1; i++) {
        _spawn(EnemyKind.bat, spawnNear());
      }
    }

    // 30–60s: wave 1 — 50 bats total, every 5s (≈10 per tick)
    while (_t >= _nextW1 && _t < 60 && _w1TicksLeft > 0) {
      _nextW1 += 5;
      _w1TicksLeft--;
      final toSpawn = (_w1TicksLeft == 0) ? 15 - (5 * 10) : 10;
      final batch = toSpawn <= 0 ? 10 : toSpawn;
      for (int i = 0; i < batch; i++) {
        _spawn(EnemyKind.bat, spawnNear());
      }
    }

    // 60–120s: 3 frogs + 3 bats every second
    while (_t >= _nextPreW2 && _t < 120) {
      _nextPreW2 += 1;
      for (int i = 0; i < 1; i++) {
        _spawn(EnemyKind.frog, spawnNear());
        _spawn(EnemyKind.bat, spawnNear());
      }
    }

    // 120–150s: wave 2 — 50 foxes total, every 5s (≈10 per tick)
    while (_t >= _nextW2 && _t < 150 && _w2TicksLeft > 0) {
      _nextW2 += 5;
      _w2TicksLeft--;
      final toSpawn = (_w2TicksLeft == 0) ? 15 - (5 * 10) : 10;
      final batch = toSpawn <= 0 ? 10 : toSpawn;
      for (int i = 0; i < batch; i++) {
        _spawn(EnemyKind.fox, spawnNear());
      }
    }

    // 150–180s: 5 bats + 5 foxes every second
    while (_t >= _nextPreW3 && _t < 180) {
      _nextPreW3 += 1;
      for (int i = 0; i < 1; i++) {
        _spawn(EnemyKind.bat, spawnNear());
        _spawn(EnemyKind.fox, spawnNear());
      }
    }

    // 180s: boss spawns once
    if (!_bossSpawned && _t >= 180) {
      _bossSpawned = true;
      _spawn(EnemyKind.boss, spawnNear());
    }
  }

  void _spawn(EnemyKind kind, Vector2 pos) {
    final e = Enemy(kind, pos)..priority = 10;
    _enemies.add(e);
    _world.add(e);
  }

  /* ===================== ENEMY KILL / EXP ===================== */

  void onEnemyKilled(EnemyKind kind, int exp) {
    if (exp > 0) {
      addScore(exp);     // use EXP as score too (matches your values)
      stats.gainExp(exp);
    }
  }

  /* ===================== PLAYER DAMAGE / LOSE ===================== */

  void damagePlayer(double amount) {
    if (stats.isDead) return;
    stats.takeDamage(amount);
  }

  void _goToLose() {
    pauseEngine();
    final ctx = buildContext;
    if (ctx != null) {
      try {
        Navigator.of(ctx).pushReplacementNamed('/lose');
      } catch (e) {
        debugPrint('⚠️ Navigation to /lose failed: $e');
      }
    }
  }

  /* ===================== STREAMING ===================== */

void _refreshStreaming() {
  _floorGrid.ensureTilesAround(playerWorldCenter, kFloorRadiusPx);
  _chunkManager.ensureChunksAround(playerWorldCenter, kChunkRadiusPx);
}


  /* ===================== SCORE ===================== */

  void addScore(int points) {
    _currentScore += points;
    if (_currentScore > _highScore) {
      _highScore = _currentScore;
      _saveHighScore(_highScore);
    }
    _refreshScoreText();
  }

  void resetScore() {
    _currentScore = 0;
    _refreshScoreText();
  }

  void _refreshScoreText() {
    // If you want to show Level too, append " | LVL ${stats.level}"
    _scoreText?.text = 'Score $_currentScore  |  Best $_highScore';
  }

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _highScore = prefs.getInt(_prefsKeyHighScore) ?? 0;
    } catch (e) {
      debugPrint('⚠️ Failed to load high score: $e');
      _highScore = 0;
    }
  }

  Future<void> _saveHighScore(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyHighScore, value);
    } catch (e) {
      debugPrint('⚠️ Failed to save high score: $e');
    }
  }

void _updateHudForSize(Vector2 s) {
  final isCompact = s.x < 500; // mobile portrait threshold

  // top-left positions
  _waveMeter.position = Vector2(8, isCompact ? 32 : 32);


  final barW = (s.x * (isCompact ? 0.72 : 0.5)).clamp(160.0, 380.0);
  final barH = isCompact ? 8.0 : 10.0;
  _waveMeter.setSize(barW, barH);
}



}
enum EnemyKind { frog, bat, fox, boss }

class EnemyStats {
  final double hp;
  final double damage;
  final double range; // in "units"
  final double speed; // px/s
  final int exp;      // exp/score on death

  const EnemyStats(this.hp, this.damage, this.range, this.speed, this.exp);
}

const Map<EnemyKind, EnemyStats> kEnemyStats = {
  EnemyKind.frog: EnemyStats(30,   10, 1, 65,  10),
  EnemyKind.bat:  EnemyStats(300,  20, 1.5, 80,  50),
  EnemyKind.fox:  EnemyStats(500,  40, 2, 60, 100),
  EnemyKind.boss: EnemyStats(10000,100, 3, 40,   0),
};

class Enemy extends PositionComponent with HasGameRef<Level1Map> {
  final EnemyKind kind;
  late double _hp;
  late double _maxHp; 
  double _hitCooldown = 0;

  Enemy(this.kind, Vector2 pos)
      : super(
          position: pos,
          size: Vector2.all(kind == EnemyKind.boss ? 180 : 72),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    final s = kEnemyStats[kind]!;
    _hp = s.hp;
      _maxHp = s.hp;  

    // Sprite
    final sprite = gameRef.enemySprites[kind];
    if (sprite != null) {
      add(SpriteComponent(
        sprite: sprite,
        size: size.clone(),
        anchor: Anchor.center,
        priority: 1,
      ));
    } else {
      // Fallback shape
      add(CircleComponent(
        radius: size.x / 2,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF64748B),
        priority: 1,
      ));
    }

     // Enemy HP bar (red)
    add(EnemyHpBar(
      enemy: this,
      width: kind == EnemyKind.boss ? 120 : 50,
      height: 6,
      gap: 6,
    )..priority = 2);
  }
  

  @override
void update(double dt) {
  super.update(dt);
  final stats = kEnemyStats[kind]!;
  _hitCooldown = max(0, _hitCooldown - dt);

  // Always steer toward the player's world-center
  final target = gameRef.playerWorldCenter;       // <— unified target
  final dir = target - position;
  final d2 = dir.length2;
  if (d2 > 1e-6) {
    final d = sqrt(d2);
    final step = min(d, stats.speed * dt);
    position += dir * (step / d);
  }

  // Contact damage vs the same target
  final rangePx = stats.range * kUnitPx;
  if ((position - target).length2 <= rangePx * rangePx) {
    if (_hitCooldown <= 0) {
      gameRef.damagePlayer(stats.damage);
      _hitCooldown = kEnemyTouchCooldown;
    }
  }

  // Cull based on distance from the player (not from origin)
  final maxRadius = kChunkRadiusPx + 3000;
  if ((position - target).length2 > maxRadius * maxRadius) {
    removeFromParent();
  }
}


  void takeDamage(double dmg) {
    _hp -= dmg;
    if (_hp <= 0) {
      final s = kEnemyStats[kind]!;
      gameRef.onEnemyKilled(kind, s.exp);
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    gameRef._enemies.remove(this);
    super.onRemove();
  }
}
/* ============================ WORLD ROOT ============================ */

class WorldLayer extends World {}

/* ============================ HUD PLAYER ============================ */

class HudPlayer extends SpriteComponent {
  HudPlayer({required Sprite sprite})
      : super(sprite: sprite, size: Vector2.all(120), anchor: Anchor.center);
}

/* ============================ HUD HP BAR ============================ */

class HudHpBar extends PositionComponent {
  final PlayerStats Function() statsProvider;
  final double width;
  final double height;
  final double offsetAboveHead;

  late final RectangleComponent _bg;
  late final RectangleComponent _fg;

  HudHpBar({
    required this.statsProvider,
    this.width = 110,
    this.height = 12,
    this.offsetAboveHead = -100,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    size = Vector2(width, height);

    _bg = RectangleComponent(
      size: size,
      anchor: Anchor.center,
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xCC111827),
      priority: 1,
    );

    _fg = RectangleComponent(
      size: size.clone(),
      anchor: Anchor.centerLeft,
      position: Vector2(-width / 2, 0),
      paint: Paint()..color = const Color(0xFF22C55E),
      priority: 2,
    );

    addAll([_bg, _fg]);
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = _targetLocalPos();
    final s = statsProvider();
    final ratio = s.maxHp <= 0 ? 0.0 : (s.hp / s.maxHp).clamp(0.0, 1.0);
    _fg.size = Vector2(width * ratio, height);
  }

  Vector2 _targetLocalPos() {
    final y = (offsetAboveHead);
    return Vector2(130, y);
  }
}

class HudLevelBadge extends PositionComponent {
  final PlayerStats Function() statsProvider;
  final double barWidth;
  final double barHeight;
  final double offsetAboveHead;

  late final RectangleComponent _bg;
  late final TextComponent _text;

  HudLevelBadge({
    required this.statsProvider,
    required this.barWidth,
    required this.barHeight,
    this.offsetAboveHead = -100,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    size = Vector2(34, barHeight); // small pill

    _bg = RectangleComponent(
      size: size,
      anchor: Anchor.center,
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xFF0F172A),
      priority: 1,
    );

    _text = TextComponent(
      text: 'Lv 0',
      anchor: Anchor.center,
      position: Vector2.zero(),
      priority: 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    addAll([_bg, _text]);
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final s = statsProvider();
    _text.text = 'Lv ${s.level}';
    position = _targetLocalPos();
  }

  Vector2 _targetLocalPos() {
    final y = offsetAboveHead;
    return Vector2(20, y);
  }
}

class EnemyHpBar extends PositionComponent {
  final Enemy enemy;
  final double width;
  final double height;
  final double gap; // vertical gap above the enemy sprite

  late final RectangleComponent _bg;
  late final RectangleComponent _fg;

  EnemyHpBar({
    required this.enemy,
    this.width = 50,
    this.height = 6,
    this.gap = 6,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    size = Vector2(width, height);

    _bg = RectangleComponent(
      size: size,
      anchor: Anchor.center,
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xCC1F2937), // dark bg
      priority: 10,
    );

    _fg = RectangleComponent(
      size: size.clone(),
      anchor: Anchor.centerLeft,
      position: Vector2(-width / 2, 0),
      paint: Paint()..color = const Color(0xFFE11D48), // red
      priority: 11,
    );

    addAll([_bg, _fg]);
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = _targetLocalPos();

    final ratio = (enemy._maxHp <= 0)
        ? 0.0
        : (enemy._hp / enemy._maxHp).clamp(0.0, 1.0);
    _fg.size = Vector2(width * ratio, height);
  }

  Vector2 _targetLocalPos() {
    // hover just above the enemy’s head
    final y = -(enemy.size.y / 2 + gap + height / 2);
    return Vector2(0, y);
  }
}

class HudWaveMeter extends PositionComponent {
  final double width;
  final double height;
  final List<double> flags; // seconds
  final double total;

  double _progress = 0.0;
  double get progress => _progress;
  set progress(double v) {
    _progress = v.clamp(0.0, 1.0);
    if (_isLoaded) {
      _fg.size = Vector2(size.x * _progress, size.y);
    }
  }

  late RectangleComponent _bg;
  late RectangleComponent _fg;
  final List<TextComponent> _flagMarks = [];

  bool _isLoaded = false;

  HudWaveMeter({
    required this.width,
    required this.height,
    required this.flags,
    required this.total,
  }) : super(anchor: Anchor.topLeft, size: Vector2(width, height));

  @override
  Future<void> onLoad() async {
    _bg = RectangleComponent(
      size: size,
      anchor: Anchor.topLeft,
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xFF1F2937),
    );

    _fg = RectangleComponent(
      size: Vector2(size.x * _progress, size.y),
      anchor: Anchor.topLeft,
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xFF10B981),
      priority: 2,
    );

    add(_bg);
    add(_fg);

    // Flags along 0..width
    for (final t in flags) {
      final x = size.x * (t / total);
      final flag = TextComponent(
        text: '⚑',
        anchor: Anchor.bottomCenter,
        position: Vector2(x, -2),
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        priority: 3,
      );
      _flagMarks.add(flag);
      add(flag);
    }

    _isLoaded = true;
  }

  void setSize(double newWidth, double newHeight) {
    size = Vector2(newWidth, newHeight);
    if (!_isLoaded) return;

    _bg
      ..size = size
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();

    _fg
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero()
      ..size = Vector2(newWidth * _progress, newHeight);

    for (int i = 0; i < _flagMarks.length; i++) {
      final t = flags[i];
      final x = newWidth * (t / total);
      _flagMarks[i]
        ..anchor = Anchor.bottomCenter
        ..position = Vector2(x, -2);
    }
  }
}

/* ============================ FLOOR GRID (TILED MAP) ============================ */

class FloorGrid extends Component {
  final Sprite floorSprite;
  final Vector2 tileSize; // (w, h)

  final Map<String, SpriteComponent> _tiles = {};

  FloorGrid({
    required this.floorSprite,
    required this.tileSize,
  });

  String _key(int tx, int ty) => '$tx,$ty';

  void ensureTilesAround(Vector2 worldCenter, double radiusPx) {
    final halfW = tileSize.x / 2;
    final halfH = tileSize.y / 2;

    int toTileX(double x) => ((x + (x >= 0 ? halfW : -halfW)) / tileSize.x).floor();
    int toTileY(double y) => ((y + (y >= 0 ? halfH : -halfH)) / tileSize.y).floor();

    final int centerTx = toTileX(worldCenter.x);
    final int centerTy = toTileY(worldCenter.y);

    final int rx = (radiusPx / tileSize.x).ceil();
    final int ry = (radiusPx / tileSize.y).ceil();

    for (int dx = -rx; dx <= rx; dx++) {
      for (int dy = -ry; dy <= ry; dy++) {
        final tx = centerTx + dx;
        final ty = centerTy + dy;
        final key = _key(tx, ty);
        if (_tiles.containsKey(key)) continue;

        final tile = SpriteComponent(
          sprite: floorSprite,
          size: tileSize,
          anchor: Anchor.topLeft,
          position: Vector2(tx * tileSize.x, ty * tileSize.y),
          priority: -1000,
        );

        _tiles[key] = tile;
        add(tile);
      }
    }

    final toRemove = <String>[];
    _tiles.forEach((key, tile) {
      final tx = (tile.position.x / tileSize.x).round();
      final ty = (tile.position.y / tileSize.y).round();
      if ((tx - centerTx).abs() > rx + 1 || (ty - centerTy).abs() > ry + 1) {
        toRemove.add(key);
      }
    });
    for (final key in toRemove) {
      _tiles[key]?.removeFromParent();
      _tiles.remove(key);
    }
  }
}

/* ============================ ASSET CHUNK MANAGER ============================ */

class ChunkManager extends Component {
  final Map<String, Sprite> spriteCache;
  final double chunkSize;

  final Map<String, Chunk> _chunks = {};

  ChunkManager({
    required this.spriteCache,
    required this.chunkSize,
  });

  String _key(int cx, int cy) => '$cx,$cy';
  int _worldToChunk(double coord) => (coord / chunkSize).floor();

  void ensureChunksAround(Vector2 worldCenter, double radiusPx) {
    final int centerCx = _worldToChunk(worldCenter.x);
    final int centerCy = _worldToChunk(worldCenter.y);
    final int r = (radiusPx / chunkSize).ceil();

    for (int dx = -r; dx <= r; dx++) {
      for (int dy = -r; dy <= r; dy++) {
        final cx = centerCx + dx;
        final cy = centerCy + dy;
        final key = _key(cx, cy);
        if (_chunks.containsKey(key)) continue;

        final chunk = Chunk(cx: cx, cy: cy, chunkSize: chunkSize, spriteCache: spriteCache)
          ..priority = 5;
        _chunks[key] = chunk;
        add(chunk);
      }
    }

    final toRemove = <String>[];
    _chunks.forEach((key, chunk) {
      final dcx = (chunk.cx - centerCx).abs();
      final dcy = (chunk.cy - centerCy).abs();
      if (dcx > r + 1 || dcy > r + 1) {
        toRemove.add(key);
      }
    });
    for (final key in toRemove) {
      _chunks[key]?.removeFromParent();
      _chunks.remove(key);
    }
  }
}

/* ============================ CHUNK (ASSETS) ============================ */

class Chunk extends PositionComponent {
  final int cx, cy;
  final double chunkSize;
  final Map<String, Sprite> spriteCache;
  late final Random rng;

  Chunk({
    required this.cx,
    required this.cy,
    required this.chunkSize,
    required this.spriteCache,
  }) : super(
          position: Vector2(cx * chunkSize, cy * chunkSize),
          size: Vector2.all(chunkSize),
          anchor: Anchor.topLeft,
        ) {
    final seed = cx * 73856093 ^ cy * 19349663;
    rng = Random(seed);
  }

  @override
  Future<void> onLoad() async {
    final base = _poissonLikePositions(count: kBaseDecorationsPerChunk, minDist: 48);
    for (final p in base) {
      add(_randomDecoration(p));
    }

    for (int i = 0; i < kClustersPerChunk; i++) {
      final center = _randPointInChunk();
      final n = max(1, (rng.nextGaussian() * 4 + kClusterItemsMean).round());
      for (int j = 0; j < n; j++) {
        final a = rng.nextDouble() * pi * 2;
        final r = rng.nextDouble() * kClusterRadius;
        final p = center + Vector2(cos(a), sin(a)) * r;
        if (_insideChunk(p)) add(_randomDecoration(p));
      }
    }
  }

  bool _insideChunk(Vector2 p) =>
      p.x >= 0 && p.y >= 0 && p.x <= size.x && p.y <= size.y;

  Vector2 _randPointInChunk() =>
      Vector2(rng.nextDouble() * size.x, rng.nextDouble() * size.y);

  List<Vector2> _poissonLikePositions({required int count, required double minDist}) {
    final pts = <Vector2>[];
    int attempts = 0;
    while (pts.length < count && attempts < count * 60) {
      attempts++;
      final p = _randPointInChunk();
      bool ok = true;
      for (final q in pts) {
        if (p.distanceToSquared(q) < minDist * minDist) {
          ok = false;
          break;
        }
      }
      if (ok) pts.add(p);
    }
    return pts;
  }

  SpriteComponent _randomDecoration(Vector2 localPos) {
    final filename = kDecorFilenames[rng.nextInt(kDecorFilenames.length)];
    final sprite = spriteCache[filename]!;
    final s = rng.nextDouble() * (kDecorationMaxScale - kDecorationMinScale) + kDecorationMinScale;
    final rot = rng.nextDouble() * pi * 2;

    return SpriteComponent(
      sprite: sprite,
      anchor: Anchor.center,
      position: localPos,
      angle: rot,
      scale: Vector2.all(s),
    );
  }
}

/* ============================ gaussian ============================ */

extension _Gaussian on Random {
  double nextGaussian() {
    final u1 = max(1e-9, nextDouble());
    final u2 = nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2 * pi * u2);
  }
}
