import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';

import '../lose2.dart';
import '../win2.dart';

// ====================== CONSTANTS ======================

const double kPanSpeed = 240;
const double kFloorRadiusPx = 3000;
const double kChunkRadiusPx = 3200;
const double kChunkSize = 1024;

const double kDecorationMinScale = 0.18;
const double kDecorationMaxScale = 0.48;

const int kBaseDecorationsPerChunk = 22;
const int kClustersPerChunk = 3;
const int kClusterItemsMean = 9;
const double kClusterRadius = 160;

const double kUnitPx = 32;
const double kEnemyTouchCooldown = 0.6;
const double kEnemyNearRadiusMin = 320;
const double kEnemyNearRadiusMax = 520;

// ============ LEVEL 2 MONSTER SPRITES ============
// (paths are relative to your Flame image root)
const String TROLL_SPRITE_PATH =
    'activity2/monsters/level3/troll.png';
const String ORC_SPRITE_PATH =
    'activity2/monsters/level3/orc.png';
const String WYVERN_SPRITE_PATH = 'activity2/monsters/level3/wyvern.png';
const String GOLEM_SPRITE_PATH =
    'activity2/monsters/level3/golem.png';
const String GIANT_SPRITE_PATH =
    'activity2/monsters/level3/giant.png';
const String BOSS_SPRITE_PATH = 'activity2/monsters/level3/boss.png';

// Weapons (unchanged)
const String FIST_SPRITE_PATH = 'activity2/weapons/fist.png';
const String GUN_BULLET_SPRITE_PATH = 'activity2/weapons/gun_fx.png';
const String WAND_PROJECTILE_SPRITE_PATH = 'activity2/weapons/wand_fx.png';
const String FORCEFIELD_ICON_PATH = 'activity2/weapons/forcefield.png';
const String HOLY_SWORD_ICON_PATH = 'activity2/weapons/sword.png';
const String REAPER_SCYTHE_ICON_PATH = 'activity2/weapons/scythe.png';
const String MACHINE_GUN_ICON_PATH = 'activity2/weapons/gun.png';
const String GOLDEN_GOOSE_ICON_PATH = 'activity2/weapons/goose.png';
const String HOLY_WAND_ICON_PATH = 'activity2/weapons/wand.png';

const List<String> kDecorFilenames = [
  'bag.png',
  'bag2.png',
  'Cage.png',
  'Caravan.png',
  'Cart.png',
  'coveredcart.png',
  'Firewood.png',
  'hut.png',
  'largetent.png',
  'Platform.png',
  'pot.png',
  'rack.png',
  'rock.png',
  'skull.png',
  'Tent.png',
  'wall.png',
];

enum WeaponType {
  forcefield,
  holySword,
  reaperScythe,
  machineGun,
  goldenGoose,
  holyWand,
}

class WeaponInfo {
  final WeaponType type;
  final String name;
  final String imagePath;

  const WeaponInfo(this.type, this.name, this.imagePath);
}

const Map<WeaponType, WeaponInfo> kWeaponInfos = {
  WeaponType.forcefield: WeaponInfo(
    WeaponType.forcefield,
    'Forcefield',
    'images/activity2/weapons/forcefield.png',
  ),
  WeaponType.holySword: WeaponInfo(
    WeaponType.holySword,
    'Holy Sword',
    'images/activity2/weapons/sword.png',
  ),
  WeaponType.reaperScythe: WeaponInfo(
    WeaponType.reaperScythe,
    'Reaper Scythe',
    'images/activity2/weapons/scythe.png',
  ),
  WeaponType.machineGun: WeaponInfo(
    WeaponType.machineGun,
    'Machine Gun',
    'images/activity2/weapons/gun.png',
  ),
  WeaponType.goldenGoose: WeaponInfo(
    WeaponType.goldenGoose,
    'Golden Goose',
    'images/activity2/weapons/goose.png',
  ),
  WeaponType.holyWand: WeaponInfo(
    WeaponType.holyWand,
    'Holy Wand',
    'images/activity2/weapons/wand.png',
  ),
};

String weaponDescription(WeaponType type, int nextLevel) {
  final lvl = nextLevel.clamp(1, 5);
  switch (type) {
    case WeaponType.forcefield:
      const desc = {
        1: 'Range +1. Enemies in range are slowed.',
        2: 'Range +2. Enemies in range are slowed and take 15 dmg/sec.',
        3: 'Range +3. Enemies in range are slowed and take 40 dmg/sec.',
        4: 'Range +4. Enemies in range are slowed and take 100 dmg/sec.',
        5: 'Range +5. Enemies in range are slowed and take 300 dmg/sec.',
      };
      return desc[lvl]!;
    case WeaponType.holySword:
      const desc = {
        1: 'Damage heals you if HP is not full.',
        2: 'Same heal effect, +20 dmg.',
        3: 'Same heal, +50 dmg, overheal becomes a 300 shield.',
        4: 'Same heal, +150 dmg, overheal becomes a 300 shield.',
        5: 'Same heal, +500 dmg, overheal becomes a 300 shield.',
      };
      return desc[lvl]!;
    case WeaponType.reaperScythe:
      const desc = {
        1: 'Range +1. Slash DoT around you.',
        2: 'Range +2. Stronger slash DoT around you.',
        3: 'Range +3. Faster, stronger slash DoT.',
        4: 'Range +4. High DPS slash DoT.',
        5: 'Range +5. Massive slash DoT.',
      };
      return desc[lvl]!;
    case WeaponType.machineGun:
      const desc = {
        1: '+10 dmg. Hit 2 enemies at once.',
        2: '+1 range, +30 dmg. Hit 2 enemies at once.',
        3: '+1 range, +60 dmg. Hit 3 enemies at once.',
        4: '+2 range, +120 dmg. Hit 3 enemies at once.',
        5: '+2 range, +300 dmg. Hit 5 enemies at once.',
      };
      return desc[lvl]!;
    case WeaponType.goldenGoose:
      const desc = {
        1: '+200 HP, heal 10 HP/sec.',
        2: '+300 HP, heal 10 HP/sec. Excess heal becomes 150 shield.',
        3: '+300 HP, heal 15 HP/sec. Excess heal → 200 shield.',
        4: '+400 HP, heal 15 HP/sec. Excess heal → 250 shield.',
        5: '+500 HP, heal 20 HP/sec. Excess heal → 300 shield.',
      };
      return desc[lvl]!;
    case WeaponType.holyWand:
      const desc = {
        1: '+1 range, +30 dmg.',
        2: '+1 range, +100 dmg.',
        3: '+2 range, +200 dmg. Attacks twice per hit.',
        4: '+2 range, +300 dmg. Attacks twice per hit.',
        5: '+3 range, +500 dmg. Attacks 3× per hit.',
      };
      return desc[lvl]!;
  }
}

// ====================== PLAYER STATS ======================

class PlayerStats {
  // 🔼 Max level 15 now
  static const int maxLevel = 15;

  int level;
  double hp;
  double maxHp;
  double dps;
  double attackSpeed;
  double range;
  int exp;
  int level1Exp;
  int nextLevelExp;

  final Map<WeaponType, int> weaponLevels;
  double hpRegenPerSec;
  double shield;
  double maxShield;

  PlayerStats._({
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.dps,
    required this.attackSpeed,
    required this.range,
    required this.exp,
    required this.level1Exp,
    required this.nextLevelExp,
    required this.weaponLevels,
    required this.hpRegenPerSec,
    required this.shield,
    required this.maxShield,
  });

  factory PlayerStats.base() => PlayerStats._(
        level: 0,
        hp: 300,
        maxHp: 300,
        dps: 10,
        attackSpeed: 3.0,
        range: 5,
        exp: 0,
        level1Exp: 25,
        nextLevelExp: 25,
        weaponLevels: {
          for (final w in WeaponType.values) w: 0,
        },
        hpRegenPerSec: 0,
        shield: 0,
        maxShield: 0,
      );

  bool get isDead => hp <= 0;

  void takeDamage(double amount) {
    double remaining = amount;
    if (shield > 0) {
      final used = min(shield, remaining);
      shield -= used;
      remaining -= used;
    }
    if (remaining > 0) {
      hp = (hp - remaining).clamp(0, maxHp);
    }
  }

  void heal(double amount) {
    hp = (hp + amount).clamp(0, maxHp);
  }

  void tick(double dt) {
    if (hpRegenPerSec > 0) {
      final healAmount = hpRegenPerSec * dt;
      if (hp < maxHp) {
        heal(healAmount);
      } else if (maxShield > 0) {
        shield = (shield + healAmount).clamp(0, maxShield);
      }
    }
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
    maxHp *= 1.06;
    dps *= 1.08;
    attackSpeed *= 1.04;
    hp = maxHp;
    level1Exp *= 2;
    nextLevelExp = level1Exp;
  }
}

// ====================== LEVEL 2 GAME ======================

class Level3Map extends FlameGame {
  late final JoystickComponent _joystick;

  HudPlayer? _playerHud;
  HudHpBar? _hpBar;
  TextComponent? _scoreText;
  int _currentScore = 0;
  int _highScore = 0;
  static const _prefsKeyHighScore = 'level3_high_score';

  late final PlayerStats stats;

  late final WorldLayer _world;
  final Map<String, Sprite> _spriteCache = {};
  final Map<EnemyKind, Sprite> enemySprites = {};

  late final Sprite fistSprite;
  late final Sprite bulletSprite;
  late final Sprite wandProjectileSprite;

  late final ui.Image _floorImage;
  late final Sprite _floorSprite;
  int _floorTileW = 512;
  int _floorTileH = 512;
  final Vector2 _worldCenter = Vector2.zero();
  Vector2 get playerWorldCenter => _worldCenter;
  final Random _rng = Random();
  late final FloorGrid _floorGrid;
  late final ChunkManager _chunkManager;
  late final AuraRing _auraRing;

  // 🔄 New timeline: 4 waves + boss (~4 minutes)
  static const double kTimelineTotal = 240;
  static const List<double> kWaveFlags = [30, 90, 150, 210];

  double _t = 0;

  // Wave timers
  double _nextPreW1 = 1;
  double _nextW1 = 30;
  int _w1TicksLeft = 6;

  double _nextPreW2 = 61;
  double _nextW2 = 90;
  int _w2TicksLeft = 6;

  double _nextPreW3 = 121;
  double _nextW3 = 150;
  int _w3TicksLeft = 6;

  double _nextPreW4 = 181;
  double _nextW4 = 210;
  int _w4TicksLeft = 6;

  bool _bossSpawned = false;

  double _attackCooldown = 0;
  final Map<WeaponType, Sprite> weaponIconSprites = {};
  HudWeaponIcons? _weaponIcons;

  final Set<Enemy> _enemies = {};
  final Map<WeaponType, int> _weaponLevels = {
    for (final w in WeaponType.values) w: 0,
  };
  final Set<WeaponType> _equippedWeapons = {};
  List<WeaponType> _currentWeaponChoices = [];
  List<WeaponType> get currentWeaponChoices => _currentWeaponChoices;
  double _scytheSlashTimer = 0;
  double _scytheGlowTimer = 0;
  double get scytheGlowTime => _scytheGlowTimer;

  bool _levelUpOverlayActive = false;
  double _forcefieldSfxCooldown = 0;
  double _scytheSfxCooldown = 0;

  late final HudWaveMeter _waveMeter = HudWaveMeter(
    width: 280,
    height: 10,
    flags: kWaveFlags,
    total: kTimelineTotal,
  )
    ..priority = 1003
    ..anchor = Anchor.topLeft;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    stats = PlayerStats.base();

    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.load('level3_theme.mp3');

    // Floor
    await images.load('activity2/maps/level3/floor.png');
    _floorImage = images.fromCache('activity2/maps/level3/floor.png');
    _floorSprite = Sprite(_floorImage);
    _floorTileW = _floorImage.width;
    _floorTileH = _floorImage.height;

    // Decorations
    for (final name in kDecorFilenames) {
      final path = 'activity2/maps/level3/assets/$name';
      await images.load(path);
      _spriteCache[name] = Sprite(images.fromCache(path));
    }

    // Player sprite
    await images.load('activity2/players/level3.png');
    final playerSprite =
        Sprite(images.fromCache('activity2/players/level3.png'));

    // Enemies
    await _safeLoadSprite(EnemyKind.troll, TROLL_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.orc, ORC_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.golem, GOLEM_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.wyvern, WYVERN_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.giant, GIANT_SPRITE_PATH);
    await _safeLoadSprite(EnemyKind.boss, BOSS_SPRITE_PATH);

    // Projectiles
    await images.load(FIST_SPRITE_PATH);
    fistSprite = Sprite(images.fromCache(FIST_SPRITE_PATH));
    await images.load(GUN_BULLET_SPRITE_PATH);
    bulletSprite = Sprite(images.fromCache(GUN_BULLET_SPRITE_PATH));
    await images.load(WAND_PROJECTILE_SPRITE_PATH);
    wandProjectileSprite =
        Sprite(images.fromCache(WAND_PROJECTILE_SPRITE_PATH));

    // Weapon icons
    await _loadWeaponIcon(WeaponType.forcefield, FORCEFIELD_ICON_PATH);
    await _loadWeaponIcon(WeaponType.holySword, HOLY_SWORD_ICON_PATH);
    await _loadWeaponIcon(WeaponType.reaperScythe, REAPER_SCYTHE_ICON_PATH);
    await _loadWeaponIcon(WeaponType.machineGun, MACHINE_GUN_ICON_PATH);
    await _loadWeaponIcon(WeaponType.goldenGoose, GOLDEN_GOOSE_ICON_PATH);
    await _loadWeaponIcon(WeaponType.holyWand, HOLY_WAND_ICON_PATH);

    _world = WorldLayer()..priority = 0;
    add(_world);

    camera.world = _world;
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

    _auraRing = AuraRing()..priority = 3;
    _world.add(_auraRing);

    _joystick = JoystickComponent(
      knob: CircleComponent(
          radius: 26, paint: Paint()..color = const Color(0xFF0F172A)),
      background: CircleComponent(
          radius: 56, paint: Paint()..color = const Color(0x330F172A)),
      margin: const EdgeInsets.only(right: 24, bottom: 24),
    )
      ..priority = 1000
      ..anchor = Anchor.bottomRight;
    await camera.viewport.add(_joystick);

    _playerHud = HudPlayer(sprite: playerSprite)..priority = 1001;
    await camera.viewport.add(_playerHud!);
    _playerHud!.position = size / 2;

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

    _weaponIcons = HudWeaponIcons(
      statsProvider: () => stats,
      iconSprites: weaponIconSprites,
      equippedProvider: () => _equippedWeapons,
    )..priority = 1003;
    await _playerHud!.add(_weaponIcons!);

    _scoreText = TextComponent(
      text: 'Score 0  |  Best 0',
      anchor: Anchor.topRight,
      priority: 1003,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    )..position = Vector2(size.x - 16, 12);
    await camera.viewport.add(_scoreText!);

    await _loadHighScore();

    _waveMeter.position = Vector2(8, 32);
    await camera.viewport.add(_waveMeter);
    _updateHudForSize(size);

    _refreshScoreText();
    _refreshStreaming();

    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('level3_theme.mp3');
  }

  Future<void> _safeLoadSprite(EnemyKind kind, String path) async {
    try {
      await images.load(path);
      enemySprites[kind] = Sprite(images.fromCache(path));
    } catch (e) {
      debugPrint('⚠️ Failed to load $path: $e');
    }
  }

  Future<void> _loadWeaponIcon(WeaponType type, String path) async {
    try {
      await images.load(path);
      weaponIconSprites[type] = Sprite(images.fromCache(path));
    } catch (e) {
      debugPrint('⚠️ Failed to load weapon icon $path: $e');
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
    stats.tick(dt);

    _t += dt;
    final clamped = _t.clamp(0, kTimelineTotal);
    _waveMeter.progress = clamped / kTimelineTotal;

    final dir = _joystick.relativeDelta;
    if (dir.length2 > 1e-4) {
      _worldCenter.add(dir.normalized() * (kPanSpeed * dt));
      camera.viewfinder.position = _worldCenter;
      _refreshStreaming();
    }

    _runSpawns();
    _updateForcefield(dt);
    _updateReaperScythe(dt);

    _scytheGlowTimer = max(0, _scytheGlowTimer - dt);
    _forcefieldSfxCooldown = max(0, _forcefieldSfxCooldown - dt);
    _scytheSfxCooldown = max(0, _scytheSfxCooldown - dt);

    final attackPeriod = 1.0 / stats.attackSpeed;
    _attackCooldown = max(0, _attackCooldown - dt);
    if (_attackCooldown <= 0) {
      if (_attackNearestEnemyInRange()) {
        _attackCooldown = attackPeriod;
      }
    }

    if (stats.isDead) {
      _goToLose();
    }
  }

  bool _attackNearestEnemyInRange() {
    if (_enemies.isEmpty) return false;

    final rangePx = stats.range * kUnitPx;
    final range2 = rangePx * rangePx;

    final inRange = <Enemy>[];
    for (final e in _enemies) {
      final d2 = (e.position - playerWorldCenter).length2;
      if (d2 <= range2) {
        inRange.add(e);
      }
    }
    if (inRange.isEmpty) return false;

    inRange.sort((a, b) {
      final da = (a.position - playerWorldCenter).length2;
      final db = (b.position - playerWorldCenter).length2;
      return da.compareTo(db);
    });

    final mgLvl = stats.weaponLevels[WeaponType.machineGun] ?? 0;
    final wandLvl = stats.weaponLevels[WeaponType.holyWand] ?? 0;
    final swordLvl = stats.weaponLevels[WeaponType.holySword] ?? 0;

    const mgTargets = [1, 2, 2, 3, 3, 5];
    final maxTargets = mgTargets[mgLvl.clamp(0, 5)];

    const wandHits = [1, 1, 1, 2, 2, 3];
    final hitsPerTarget = wandHits[wandLvl.clamp(0, 5)];

    final chosen = inRange.take(maxTargets).toList();
    if (chosen.isEmpty) return false;

    final playerPos = playerWorldCenter.clone();
    final primaryWeapon = _primaryWeaponForAttack();
    bool playedHitSound = false;

    for (final enemy in chosen) {
      for (int h = 0; h < hitsPerTarget; h++) {
        if (enemy.parent == null) break;

        final dmg = stats.dps;
        enemy.takeDamage(dmg);

        if (!playedHitSound) {
          _playHitSfx(primaryWeapon);
          playedHitSound = true;
        }

        if (swordLvl > 0) {
          if (stats.hp < stats.maxHp) {
            stats.heal(dmg);
          } else if (swordLvl >= 3 && stats.maxShield > 0) {
            stats.shield = min(stats.maxShield, stats.shield + dmg);
          }
        }

        _spawnProjectile(playerPos, enemy.position.clone());
      }
    }
    return true;
  }

  Sprite _chooseProjectileSprite() {
    final wandLvl = stats.weaponLevels[WeaponType.holyWand] ?? 0;
    final gunLvl = stats.weaponLevels[WeaponType.machineGun] ?? 0;

    if (wandLvl > 0) return wandProjectileSprite;
    if (gunLvl > 0) return bulletSprite;
    return fistSprite;
  }

  void _spawnProjectile(Vector2 start, Vector2 targetPos) {
    final proj = FistProjectile(
      start: start,
      end: targetPos,
      projectileSprite: _chooseProjectileSprite(),
    )..priority = 20;

    _world.add(proj);
  }

  WeaponType? _primaryWeaponForAttack() {
    final wandLvl = stats.weaponLevels[WeaponType.holyWand] ?? 0;
    final gunLvl = stats.weaponLevels[WeaponType.machineGun] ?? 0;
    final swordLvl = stats.weaponLevels[WeaponType.holySword] ?? 0;
    final scytheLvl = stats.weaponLevels[WeaponType.reaperScythe] ?? 0;

    if (wandLvl > 0) return WeaponType.holyWand;
    if (gunLvl > 0) return WeaponType.machineGun;
    if (swordLvl > 0) return WeaponType.holySword;
    if (scytheLvl > 0) return WeaponType.reaperScythe;
    return null;
  }

  void _playHitSfx(WeaponType? weapon) {
    if (weapon == null) {
      FlameAudio.play('fist.mp3');
      return;
    }

    switch (weapon) {
      case WeaponType.holyWand:
        FlameAudio.play('wand.mp3');
        break;
      case WeaponType.machineGun:
        FlameAudio.play('gun.mp3');
        break;
      case WeaponType.holySword:
        FlameAudio.play('sword.mp3');
        break;
      case WeaponType.reaperScythe:
        FlameAudio.play('scythe.mp3');
        break;
      case WeaponType.forcefield:
        FlameAudio.play('forcefield.mp3');
        break;
      case WeaponType.goldenGoose:
        break;
    }
  }

  // ===================== SPAWNS (LEVEL 2 WAVES) =====================

  void _runSpawns() {
    Vector2 spawnNear() {
      final ang = _rng.nextDouble() * pi * 2;
      final rad = ui.lerpDouble(
        kEnemyNearRadiusMin,
        kEnemyNearRadiusMax,
        _rng.nextDouble(),
      )!;
      final offset = Vector2(cos(ang), sin(ang)) * rad;
      return playerWorldCenter + offset;
    }

    // -------- PRE-WAVE 1 (0–30s): light lollipop spawns --------
    while (_t >= _nextPreW1 && _t < 30) {
      _nextPreW1 += 2;
      _spawn(EnemyKind.troll, spawnNear());
    }

    // -------- WAVE 1 (30–60s): lollipop swarm --------
    while (_t >= _nextW1 && _t < 60 && _w1TicksLeft > 0) {
      _nextW1 += 4;
      _w1TicksLeft--;
      for (int i = 0; i < 8; i++) {
        _spawn(EnemyKind.troll, spawnNear());
        _spawn(EnemyKind.orc, spawnNear());
        
      }
    }

    // -------- PRE-WAVE 2 (60–90s): mix lollipop + cupcake --------
    while (_t >= _nextPreW2 && _t < 90) {
      _nextPreW2 += 1;
      _spawn(EnemyKind.orc, spawnNear());
            _spawn(EnemyKind.golem, spawnNear());

    }

    // -------- WAVE 2 (90–120s): cupcake wave --------
    while (_t >= _nextW2 && _t < 120 && _w2TicksLeft > 0) {
      _nextW2 += 3;
      _w2TicksLeft--;
      for (int i = 0; i < 8; i++) {
        _spawn(EnemyKind.golem, spawnNear());
      _spawn(EnemyKind.wyvern, spawnNear());
              _spawn(EnemyKind.orc, spawnNear());

      }
    }

    // -------- PRE-WAVE 3 (120–150s): cupcake + cake --------
    while (_t >= _nextPreW3 && _t < 150) {
      _nextPreW3 += 1;
      _spawn(EnemyKind.golem, spawnNear());
      _spawn(EnemyKind.wyvern, spawnNear());
    }

    // -------- WAVE 3 (150–180s): cake wave --------
    while (_t >= _nextW3 && _t < 180 && _w3TicksLeft > 0) {
      _nextW3 += 3;
      _w3TicksLeft--;
      for (int i = 0; i < 8; i++) {
        _spawn(EnemyKind.wyvern, spawnNear());
        _spawn(EnemyKind.giant, spawnNear());
                _spawn(EnemyKind.golem, spawnNear());
              _spawn(EnemyKind.orc, spawnNear());

      }
    }

    // -------- PRE-WAVE 4 (180–210s): cake + icecream --------
    while (_t >= _nextPreW4 && _t < 210) {
      _nextPreW4 += 1;
      _spawn(EnemyKind.wyvern, spawnNear());
      _spawn(EnemyKind.giant, spawnNear());
              _spawn(EnemyKind.golem, spawnNear());

    }

    // -------- Boss at 240s --------
    if (!_bossSpawned && _t >= 210) {
      _bossSpawned = true;
      _spawn(EnemyKind.boss, spawnNear());
    }
  }

  void _spawn(EnemyKind kind, Vector2 pos) {
    final e = Enemy(kind, pos)..priority = 10;
    _enemies.add(e);
    _world.add(e);

    if (kind == EnemyKind.boss) {
      FlameAudio.play('level3_boss.mp3');
    }
  }

  void onEnemyKilled(EnemyKind kind, int exp) {
    addScore(exp);
    _grantPlayerExp(exp);
  }

  void _grantPlayerExp(int amount) {
    final before = stats.level;
    stats.gainExp(amount);
    final after = stats.level;

    if (after > before) {
      final levelsGained = after - before;
      for (int i = 0; i < levelsGained; i++) {
        _showLevelUpModal();
      }
    }
  }

  void damagePlayer(double amount) {
    if (stats.isDead) return;
    stats.takeDamage(amount);
  }

  void _goToLose() {
    pauseEngine();
    FlameAudio.bgm.stop();
    final ctx = buildContext;
    if (ctx != null) {
      try {
        Navigator.of(ctx).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoseScreen(),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Navigation to LoseScreen failed: $e');
      }
    }
  }

  void _goToWin() {
    pauseEngine();
    FlameAudio.bgm.stop();
    final ctx = buildContext;
    if (ctx != null) {
      try {
        Navigator.of(ctx).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WinScreen(
              highScore: _highScore,
            ),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Navigation to WinScreen failed: $e');
      }
    }
  }

  void _refreshStreaming() {
    _floorGrid.ensureTilesAround(playerWorldCenter, kFloorRadiusPx);
    _chunkManager.ensureChunksAround(playerWorldCenter, kChunkRadiusPx);
  }

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
    final isCompact = s.x < 500;
    _waveMeter.position = Vector2(8, isCompact ? 32 : 32);

    final barW = (s.x * (isCompact ? 0.72 : 0.5)).clamp(160.0, 380.0);
    final barH = isCompact ? 8.0 : 10.0;
    _waveMeter.setSize(barW, barH);
  }

  void _showLevelUpModal() {
    final equippedCount = _equippedWeapons.length;

    Iterable<WeaponType> pool;
    if (equippedCount < 4) {
      pool = WeaponType.values.where(
        (w) => (_weaponLevels[w] ?? 0) < 5,
      );
    } else {
      pool = _equippedWeapons.where(
        (w) => (_weaponLevels[w] ?? 0) < 5,
      );
    }

    final available = pool.toList();
    if (available.isEmpty) return;
    if (_levelUpOverlayActive) return;

    available.shuffle(_rng);
    _currentWeaponChoices = available.take(
      available.length >= 2 ? 2 : available.length,
    ).toList();

    FlameAudio.play('level_up.mp3');

    pauseEngine();
    overlays.add('levelUp');
    _levelUpOverlayActive = true;
  }

  void _applyWeaponBuffs(WeaponType weapon, int oldLevel, int newLevel) {
    double delta(List<double> values) {
      final before = values[oldLevel];
      final after = values[newLevel];
      return after - before;
    }

    switch (weapon) {
      case WeaponType.forcefield:
        final ranges = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];
        final dr = delta(ranges);
        stats.range += dr;
        break;
      case WeaponType.machineGun:
        final dmgBonus = [0.0, 10.0, 30.0, 60.0, 120.0, 300.0];
        final rangeBonus = [0.0, 1.0, 1.0, 2.0, 2.0, 3.0];
        stats.dps += delta(dmgBonus);
        stats.range += delta(rangeBonus);
        break;
      case WeaponType.goldenGoose:
        final hpBonus = [0.0, 200.0, 300.0, 300.0, 400.0, 500.0];
        final regen = [0.0, 10.0, 10.0, 15.0, 15.0, 20.0];
        final shieldMax = [0.0, 0.0, 150.0, 200.0, 250.0, 300.0];
        stats.maxHp += delta(hpBonus);
        stats.hp += delta(hpBonus);
        stats.hpRegenPerSec += delta(regen);
        stats.maxShield += delta(shieldMax);
        break;
      case WeaponType.holyWand:
        final dmgBonus = [0.0, 30.0, 100.0, 200.0, 300.0, 500.0];
        final rangeBonus = [0.0, 1.0, 1.0, 2.0, 2.0, 3.0];
        stats.dps += delta(dmgBonus);
        stats.range += delta(rangeBonus);
        break;
      case WeaponType.holySword:
        final dmgBonus = [0.0, 0.0, 20.0, 50.0, 150.0, 500.0];
        final shieldMax = [0.0, 0.0, 300.0, 300.0, 300.0, 300.0];
        stats.dps += delta(dmgBonus);
        stats.maxShield += delta(shieldMax);
        break;
      case WeaponType.reaperScythe:
        final rangeBonus = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];
        stats.range += delta(rangeBonus);
        break;
    }
  }

  void chooseWeapon(WeaponType weapon) {
    final current = _weaponLevels[weapon] ?? 0;
    final isNew = current == 0;

    if (isNew && _equippedWeapons.length >= 4) {
      _closeLevelUpModal();
      return;
    }

    if (current >= 5) {
      _closeLevelUpModal();
      return;
    }

    final newLevel = (current + 1).clamp(0, 5);

    if (isNew) {
      _equippedWeapons.add(weapon);
    }

    _weaponLevels[weapon] = newLevel;
    stats.weaponLevels[weapon] = newLevel;

    _applyWeaponBuffs(weapon, current, newLevel);
    _closeLevelUpModal();
  }

  void _closeLevelUpModal() {
    if (_levelUpOverlayActive) {
      overlays.remove('levelUp');
      _levelUpOverlayActive = false;
      resumeEngine();
    }
  }

  void _updateForcefield(double dt) {
    final lvl = stats.weaponLevels[WeaponType.forcefield] ?? 0;
    if (lvl <= 0) return;

    final auraRadius = stats.range * kUnitPx;
    final auraR2 = auraRadius * auraRadius;

    const slowFactor = 0.5;
    final slowDuration = 0.3 + 0.05 * lvl;

    const dpsByLevel = [0.0, 0.0, 15.0, 40.0, 100.0, 300.0];
    final dotDps = dpsByLevel[lvl];
    const dotDuration = 0.5;

    bool anyInAura = false;

    for (final e in _enemies) {
      final d2 = (e.position - playerWorldCenter).length2;
      if (d2 <= auraR2) {
        anyInAura = true;
        e.applySlow(slowFactor, slowDuration);
        if (dotDps > 0) {
          e.applyDot(dotDps, dotDuration);
        }
      }
    }

    if (anyInAura && _forcefieldSfxCooldown <= 0) {
      FlameAudio.play('forcefield.mp3');
      _forcefieldSfxCooldown = 0.7;
    }
  }

  void _updateReaperScythe(double dt) {
    final lvl = stats.weaponLevels[WeaponType.reaperScythe] ?? 0;
    if (lvl <= 0) return;

    const intervalByLevel = [0.0, 3.0, 3.0, 2.0, 2.0, 2.0];
    const baseDmgByLevel = [0.0, 20.0, 30.0, 60.0, 160.0, 300.0];
    const burnDpsByLevel = [0.0, 10.0, 15.0, 30.0, 80.0, 150.0];
    const burnDurByLevel = [0.0, 5.0, 6.0, 7.0, 8.0, 10.0];

    _scytheSlashTimer -= dt;
    if (_scytheSlashTimer > 0) return;
    _scytheSlashTimer = intervalByLevel[lvl];

    FlameAudio.play('scythe.mp3');
    _scytheGlowTimer = 0.35;

    final radius = stats.range * kUnitPx;
    final r2 = radius * radius;
    final baseDmg = baseDmgByLevel[lvl];
    final burnDps = burnDpsByLevel[lvl];
    final burnDur = burnDurByLevel[lvl];

    for (final e in _enemies.toList()) {
      final d2 = (e.position - playerWorldCenter).length2;
      if (d2 <= r2) {
        e.takeDamage(baseDmg);
        e.applyDot(burnDps, burnDur);
      }
    }
  }
}

// ====================== ENEMIES (LEVEL 2) ======================

enum EnemyKind { troll, orc, golem, wyvern, giant, boss }

class EnemyStats {
  final double hp;
  final double damage;
  final double range; // in "units"
  final double speed; // px/s
  final int exp; // exp/score on death

  const EnemyStats(this.hp, this.damage, this.range, this.speed, this.exp);
}

// Tuned to scale up: lollipop < cupcake < cake < icecream < boss
const Map<EnemyKind, EnemyStats> kEnemyStats = {
  EnemyKind.troll: EnemyStats(40, 10, 1, 70, 10),
  EnemyKind.orc: EnemyStats(140, 20, 1.5, 80, 35),
  EnemyKind.golem: EnemyStats(350, 40, 2, 75, 80),
  EnemyKind.wyvern: EnemyStats(700, 60, 2.2, 70, 140),
  EnemyKind.giant: EnemyStats(1200, 100, 2.2, 70, 140),
  EnemyKind.boss: EnemyStats(12000, 300, 3, 80, 0),
};

class Enemy extends PositionComponent with HasGameRef<Level3Map> {
  final EnemyKind kind;
  late double _hp;
  late double _maxHp;
  double _hitCooldown = 0;
  double _slowMultiplier = 1.0;
  double _slowTimeLeft = 0.0;
  double _dotPerSecond = 0.0;
  double _dotTimeLeft = 0.0;

  Enemy(this.kind, Vector2 pos)
      : super(
          position: pos,
          size: Vector2.all(kind == EnemyKind.boss ? 250 : 110),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    final s = kEnemyStats[kind]!;
    _hp = s.hp;
    _maxHp = s.hp;

    final sprite = gameRef.enemySprites[kind];
    if (sprite != null) {
      add(
        SpriteComponent(
          sprite: sprite,
          size: size.clone(),
          anchor: Anchor.center,
          priority: 1,
        ),
      );
    } else {
      add(
        CircleComponent(
          radius: size.x / 2,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFF64748B),
          priority: 1,
        ),
      );
    }

    add(
      EnemyHpBar(
        enemy: this,
        width: kind == EnemyKind.boss ? 120 : 50,
        height: 6,
        gap: 6,
      )..priority = 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final stats = kEnemyStats[kind]!;
    _hitCooldown = max(0, _hitCooldown - dt);

    if (_slowTimeLeft > 0) {
      _slowTimeLeft = max(0, _slowTimeLeft - dt);
      if (_slowTimeLeft <= 0) {
        _slowMultiplier = 1.0;
      }
    }

    if (_dotTimeLeft > 0 && _dotPerSecond > 0) {
      final tickDmg = _dotPerSecond * dt;
      _dotTimeLeft = max(0, _dotTimeLeft - dt);
      if (tickDmg > 0) {
        takeDamage(tickDmg);
      }
    }

    final target = gameRef.playerWorldCenter;
    final dir = target - position;
    final d2 = dir.length2;
    if (d2 > 1e-6) {
      final d = sqrt(d2);
      final baseSpeed = stats.speed;
      final speed = baseSpeed * _slowMultiplier;
      final step = min(d, speed * dt);
      position += dir * (step / d);
    }

    final rangePx = stats.range * kUnitPx;
    if ((position - target).length2 <= rangePx * rangePx) {
      if (_hitCooldown <= 0) {
        gameRef.damagePlayer(stats.damage);
        _hitCooldown = kEnemyTouchCooldown;
      }
    }

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

      if (kind == EnemyKind.boss) {
        FlameAudio.play('boss_death.mp3');
        gameRef._goToWin();
      } else {
        FlameAudio.play('enemy_death.mp3');
      }

      removeFromParent();
    }
  }

  void applySlow(double factor, double duration) {
    if (factor < _slowMultiplier || _slowTimeLeft <= 0) {
      _slowMultiplier = factor;
      _slowTimeLeft = duration;
    } else {
      _slowTimeLeft = max(_slowTimeLeft, duration);
    }
  }

  void applyDot(double dps, double duration) {
    _dotPerSecond = max(_dotPerSecond, dps);
    _dotTimeLeft = max(_dotTimeLeft, duration);
  }

  @override
  void onRemove() {
    gameRef._enemies.remove(this);
    super.onRemove();
  }
}

// ============================ FIST PROJECTILE ============================

class FistProjectile extends PositionComponent with HasGameRef<Level3Map> {
  final Vector2 start;
  final Vector2 end;
  final double speed;
  final Sprite projectileSprite;

  late final SpriteComponent _sprite;

  FistProjectile({
    required this.start,
    required this.end,
    required this.projectileSprite,
    this.speed = 520,
  }) : super(
          position: start.clone(),
          size: Vector2.all(48),
          anchor: Anchor.center,
        ) {
    final dir = end - start;
    angle = atan2(dir.y, dir.x);
  }

  @override
  Future<void> onLoad() async {
    _sprite = SpriteComponent(
      sprite: projectileSprite,
      size: size.clone(),
      anchor: Anchor.center,
      priority: 1,
    );
    add(_sprite);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final dir = end - position;
    final d2 = dir.length2;
    if (d2 < 1e-4) {
      removeFromParent();
      return;
    }

    final d = sqrt(d2);
    final step = speed * dt;

    if (step >= d) {
      position = end.clone();
      removeFromParent();
    } else {
      position += dir * (step / d);
    }
  }
}

// ============================ WORLD ROOT ============================

class WorldLayer extends World {}

// ============================ HUD PLAYER ============================

class HudPlayer extends SpriteComponent {
  HudPlayer({required Sprite sprite})
      : super(sprite: sprite, size: Vector2.all(120), anchor: Anchor.center);
}

// ============================ HUD HP BAR ============================

class HudHpBar extends PositionComponent {
  final PlayerStats Function() statsProvider;
  final double width;
  final double height;
  final double offsetAboveHead;

  late final RectangleComponent _bg;
  late final RectangleComponent _hpFg;
  late final RectangleComponent _shieldFg;

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

    _hpFg = RectangleComponent(
      size: size.clone(),
      anchor: Anchor.centerLeft,
      position: Vector2(-width / 2, 0),
      paint: Paint()..color = const Color(0xFF22C55E),
      priority: 2,
    );

    _shieldFg = RectangleComponent(
      size: Vector2.zero(),
      anchor: Anchor.centerLeft,
      position: Vector2(-width / 2, 0),
      paint: Paint()
        ..color =
            const ui.Color.fromARGB(255, 187, 235, 255).withOpacity(0.85),
      priority: 3,
    );

    addAll([_bg, _hpFg, _shieldFg]);
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = _targetLocalPos();

    final s = statsProvider();

    final hpRatio =
        (s.maxHp <= 0) ? 0.0 : (s.hp / s.maxHp).clamp(0.0, 1.0);
    final hpWidth = width * hpRatio;

    _hpFg
      ..size = Vector2(hpWidth, height)
      ..position = Vector2(-width / 2, 0);

    final hasShield = s.maxShield > 0 && s.shield > 0;

    if (!hasShield) {
      _shieldFg.size = Vector2.zero();
      return;
    }

    final shieldRatio = (s.shield / s.maxShield).clamp(0.0, 1.0);
    final shieldWidth = width * shieldRatio;
    final startX = -width / 2 + (width - shieldWidth);

    _shieldFg
      ..size = Vector2(shieldWidth, height)
      ..position = Vector2(startX, 0);
  }

  Vector2 _targetLocalPos() {
    final y = (offsetAboveHead);
    return Vector2(125, y);
  }
}

// ============================ HUD LEVEL BADGE ============================

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
    size = Vector2(34, barHeight);

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
    return Vector2(15, y);
  }
}

// ============================ ENEMY HP BAR ============================

class EnemyHpBar extends PositionComponent {
  final Enemy enemy;
  final double width;
  final double height;
  final double gap;

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
      paint: Paint()..color = const Color(0xCC1F2937),
      priority: 10,
    );

    _fg = RectangleComponent(
      size: size.clone(),
      anchor: Anchor.centerLeft,
      position: Vector2(-width / 2, 0),
      paint: Paint()..color = const Color(0xFFE11D48),
      priority: 11,
    );

    addAll([_bg, _fg]);
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = _targetLocalPos();

    final ratio =
        (enemy._maxHp <= 0) ? 0.0 : (enemy._hp / enemy._maxHp).clamp(0.0, 1.0);
    _fg.size = Vector2(width * ratio, height);
  }

  Vector2 _targetLocalPos() {
    final y = -(enemy.size.y / 2 + gap + height / 2);
    return Vector2(30, y);
  }
}

// ============================ HUD WAVE METER ============================

class HudWaveMeter extends PositionComponent {
  final double width;
  final double height;
  final List<double> flags;
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

// ============================ HUD WEAPON ICONS ============================

class HudWeaponIcons extends PositionComponent with HasGameRef<Level3Map> {
  final PlayerStats Function() statsProvider;
  final Map<WeaponType, Sprite> iconSprites;
  final Set<WeaponType> Function() equippedProvider;

  HudWeaponIcons({
    required this.statsProvider,
    required this.iconSprites,
    required this.equippedProvider,
  }) : super(anchor: Anchor.center);

  final Map<WeaponType, Color> bgColors = {
    WeaponType.forcefield: Color(0xFF3B82F6),
    WeaponType.holySword: Color(0xFFFACC15),
    WeaponType.reaperScythe: Color(0xFFEF4444),
    WeaponType.machineGun: Color(0xFF6B7280),
    WeaponType.goldenGoose: Color(0xFF22C55E),
    WeaponType.holyWand: Color(0xFFA855F7),
  };

  @override
  Future<void> onLoad() async {
    position = _targetLocalPos();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = _targetLocalPos();
  }

  Vector2 _targetLocalPos() {
    return Vector2(70, -35);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final stats = statsProvider();
    final equipped = equippedProvider().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (equipped.isEmpty) return;

    final count = min(4, equipped.length);
    const double iconSize = 22.0;
    const double circleSize = 28.0;
    const double spacing = 8.0;

    final totalWidth = count * circleSize + (count - 1) * spacing;
    final startX = -totalWidth / 2;

    final glowTime = gameRef.scytheGlowTime;
    final glowActive = glowTime > 0;
    double glowPhase = 0;

    if (glowActive) {
      const glowDuration = 0.35;
      final tNorm = (glowDuration - glowTime) / glowDuration;
      glowPhase = sin(tNorm * pi);
    }

    for (int i = 0; i < count; i++) {
      final w = equipped[i];
      final sprite = iconSprites[w];
      if (sprite == null) continue;

      final dx = startX + i * (circleSize + spacing);
      final pos = Offset(dx, 0);

      final bgPaint = Paint()
        ..color = (bgColors[w] ?? Colors.white).withOpacity(0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        pos,
        circleSize / 2,
        bgPaint,
      );

      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(
        pos,
        circleSize / 2,
        borderPaint,
      );

      if (w == WeaponType.reaperScythe) {
        final lvl = stats.weaponLevels[w] ?? 0;
        if (lvl > 0 && glowActive) {
          final glowPaint = Paint()
            ..color =
                Colors.redAccent.withOpacity(0.25 + 0.4 * glowPhase)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);

          canvas.drawCircle(
            pos,
            (circleSize / 2) + 6 + glowPhase * 4,
            glowPaint,
          );
        }
      }

      sprite.render(
        canvas,
        position: Vector2(dx, 0),
        size: Vector2.all(iconSize),
        anchor: Anchor.center,
      );
    }
  }
}

// ============================ FLOOR GRID ============================

class FloorGrid extends Component {
  final Sprite floorSprite;
  final Vector2 tileSize;

  final Map<String, SpriteComponent> _tiles = {};

  FloorGrid({
    required this.floorSprite,
    required this.tileSize,
  });

  String _key(int tx, int ty) => '$tx,$ty';

  void ensureTilesAround(Vector2 worldCenter, double radiusPx) {
    final halfW = tileSize.x / 2;
    final halfH = tileSize.y / 2;

    int toTileX(double x) =>
        ((x + (x >= 0 ? halfW : -halfW)) / tileSize.x).floor();
    int toTileY(double y) =>
        ((y + (y >= 0 ? halfH : -halfH)) / tileSize.y).floor();

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

        final chunk = Chunk(
          cx: cx,
          cy: cy,
          chunkSize: chunkSize,
          spriteCache: spriteCache,
        )..priority = 5;
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
    final base =
        _poissonLikePositions(count: kBaseDecorationsPerChunk, minDist: 48);
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

  List<Vector2> _poissonLikePositions({
    required int count,
    required double minDist,
  }) {
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
    final s = rng.nextDouble() *
            (kDecorationMaxScale - kDecorationMinScale) +
        kDecorationMinScale;
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

class AuraRing extends PositionComponent with HasGameRef<Level3Map> {
  double _t = 0; // time accumulator

  AuraRing() : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    // Always follow the player
    position = gameRef.playerWorldCenter;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final stats = gameRef.stats;
    final ffLvl = stats.weaponLevels[WeaponType.forcefield] ?? 0;
    final scLvl = stats.weaponLevels[WeaponType.reaperScythe] ?? 0;

    // No forcefield / scythe → no ring
    if (ffLvl <= 0 && scLvl <= 0) return;

    // Base radius from current range
    final baseRadius = stats.range * kUnitPx;

    // --- Pulse animation ---
    // One full pulse every ~2 seconds
    const pulseSpeed = 2 * pi / 2.0; // radians per second
    final s = sin(_t * pulseSpeed);  // -1..1

    // Scale radius between ~0.95x and 1.05x
    final scale = 1.0 + 0.05 * s;
    final radius = baseRadius * scale;

    // Opacity between ~0.12 and ~0.28
    final opacity = 0.8 + 0.08 * ((s + 1) / 2); // map -1..1 → 0..1

    Color c;
    if (ffLvl > 0 && scLvl > 0) {
      c = const Color(0xFF7C3AED); 
    } else if (ffLvl > 0) {
      c = const Color(0xFF22C55E);
    } else {
      c = const Color(0xFFF97373); 
    }

    final paint = Paint()
      ..color = c.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(Offset.zero, radius, paint);
  }
}

extension _Gaussian on Random {
  double nextGaussian() {
    final u1 = max(1e-9, nextDouble());
    final u2 = nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2 * pi * u2);
  }
}
