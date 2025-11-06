// lib/pages/activity2_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

class Activity2Page extends StatefulWidget {
  const Activity2Page({super.key});
  @override
  State<Activity2Page> createState() => _Activity2PageState();
}

/* ===================== ASSETS ===================== */
class Assets {
  static const base = 'assets/activity2';

  // L1 (forest)
  static const l1Player = '$base/lvl1/player';
  static const l1Mon = '$base/lvl1/monsters';
  static const l1Boss = '$l1Mon/boss';

  // L2 (candy house)
  static const l2Player = '$base/lvl2/player';
  static const l2Mon = '$base/lvl2/monsters';
  static const l2Boss = '$l2Mon/boss';

  // L3 (grass field)
  static const l3Player = '$base/lvl3/player';
  static const l3Mon = '$base/lvl3/monsters';
  static const l3Boss = '$l3Mon/boss';

  // Weapons / items folder (per your note)
  static const weapons = '$base/weapons';

  // Player sheets
  static String pIdle(int lvl) => [l1Player, l2Player, l3Player][lvl - 1] + '/idle.png';
  static String pRun(int lvl) => [l1Player, l2Player, l3Player][lvl - 1] + '/run.png';
  static String pAttack(int lvl) => [l1Player, l2Player, l3Player][lvl - 1] + '/attack.png';
  static String pHurt(int lvl) => [l1Player, l2Player, l3Player][lvl - 1] + '/hurt.png';

  // Boss sheets
  static String bossRun(int lvl) => [l1Boss, l2Boss, l3Boss][lvl - 1] + '/run.png';
  static String bossAttack(int lvl) => [l1Boss, l2Boss, l3Boss][lvl - 1] + '/attack.png';
  static String bossCharge(int lvl) => [l1Boss, l2Boss, l3Boss][lvl - 1] + '/charge.png';
  static String bossHurt(int lvl) => [l1Boss, l2Boss, l3Boss][lvl - 1] + '/hurt.png';
  static String bossDeath(int lvl) => [l1Boss, l2Boss, l3Boss][lvl - 1] + '/death.png';

  // Regular monsters
  static const smallWolf = '$l1Mon/small-wolf.png';
  static const mediumWolf = '$l1Mon/medium-wolf.png';
  static const largeWolf = '$l1Mon/large-wolf.png';
  static const redSlime = '$l2Mon/slime-red.png';
  static const greenSlime = '$l2Mon/slime-green.png';
  static const blueSlime = '$l2Mon/slime-blue.png';
  static const strongGreenSlime = '$l2Mon/strong-slime-green.png';
  static const strongBlueSlime = '$l2Mon/strong-slime-blue.png';
  static const femaleMinotaur = '$l3Mon/female-minotaur.png';
  static const minotaur = '$l3Mon/minotaur.png';

  // Weapons & items
  static const fist = '$weapons/fist.png';
  static const forcefield = '$weapons/forcefield.gif';
  static const goose = '$weapons/goose.png';
  static const gun = '$weapons/gun.png';
  static const gunBullet = '$weapons/gun_bullet.png';
  static const heart = '$weapons/heart.png';
  static const scythe = '$weapons/scythe.png';
  static const sword = '$weapons/sword.png';
  static const wand = '$weapons/wand.png';
  static const wandSpark = '$weapons/wand_spark.png';
}

/* ===================== HELPERS & MODELS ===================== */
double clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
enum WeaponKind { fist, wand, gun, sword, scythe, forcefield, goose }
enum GameScreen { home, playing, result }

class Rand {
  final math.Random _r;
  Rand([int? seed]) : _r = math.Random(seed);
  double next() => _r.nextDouble();
  int intN(int n) => _r.nextInt(n);
  double range(double a, double b) => a + (b - a) * _r.nextDouble();
  Offset circle(double r) {
    final t = range(0, math.pi * 2);
    return Offset(math.cos(t), math.sin(t)) * r;
  }
}

class SpriteSheet {
  final ui.Image image;
  final int frames;
  final bool vertical;
  final bool rowRightToLeft; // for horizontal strips play right->left
  late final double frameW, frameH;

  SpriteSheet({
    required this.image,
    required this.frames,
    this.vertical = false,
    this.rowRightToLeft = true,
  }) {
    if (vertical) {
      frameW = image.width.toDouble();
      frameH = image.height / frames;
    } else {
      frameW = image.width / frames;
      frameH = image.height.toDouble();
    }
  }

  Rect srcRectFor(int index) {
    index = index % frames;
    if (vertical) return Rect.fromLTWH(0, frameH * index, frameW, frameH);
    final i = rowRightToLeft ? (frames - 1 - index) : index;
    return Rect.fromLTWH(frameW * i, 0, frameW, frameH);
  }
}

Future<ui.Image> loadImage(BuildContext ctx, String asset) async {
  try {
    // On web, rootBundle can double the assets/ prefix, so use DefaultAssetBundle instead
    // On other platforms, rootBundle works fine
    final ByteData data;
    if (kIsWeb) {
      data = await DefaultAssetBundle.of(ctx).load(asset);
    } else {
      data = await rootBundle.load(asset);
    }
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (e) {
    // Surface the exact asset that failed so the app doesn't crash with "Cannot send Null".
    debugPrint('✖ Failed to load asset: $asset\n$e');
    // Create a 1x1 transparent image so painting continues safely.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = Colors.transparent);
    final pic = recorder.endRecording();
    return pic.toImage(1, 1);
  }
}
class UnitStats {
  double hp, maxHp, dmg, range, speed;
  UnitStats(this.hp, this.maxHp, this.dmg, this.range, this.speed);
}

class EnemyDef {
  final String name, spritePath;
  final UnitStats stats;
  final int exp;
  final double hitbox;
  EnemyDef(this.name, this.spritePath, this.stats, this.exp, this.hitbox);
}

class BossDef {
  final String name;
  final List<String> animPaths; // [run, attack, charge, hurt, death]
  final UnitStats stats;
  final double hitbox;
  final bool verticalFrames;
  BossDef(this.name, this.animPaths, this.stats, this.hitbox, {this.verticalFrames = false});
}

class PlayerDef {
  final List<String> animPaths; // [idle, run, attack, hurt]
  final UnitStats base;
  PlayerDef(this.animPaths, this.base);
}

/* ===================== LEVELS ===================== */
class LevelDef {
  final int index;
  final String name;
  final String theme; // forest, candy, field
  final PlayerDef player;
  final List<EnemyDef> enemies;
  final BossDef boss;
  LevelDef(this.index, this.name, this.theme, this.player, this.enemies, this.boss);
}

LevelDef buildLevel1() {
  final player = PlayerDef([
    Assets.pIdle(1),
    Assets.pRun(1),
    Assets.pAttack(1),
    Assets.pHurt(1),
  ], UnitStats(300, 300, 10, 3, 5));

  final enemies = <EnemyDef>[
    EnemyDef('Small Wolf', Assets.smallWolf, UnitStats(30, 30, 10, 3, 3), 10, 18),
    EnemyDef('Medium Wolf', Assets.mediumWolf, UnitStats(300, 300, 20, 4, 3.2), 50, 22),
    EnemyDef('Large Wolf', Assets.largeWolf, UnitStats(500, 500, 40, 4, 2.8), 100, 26),
  ];

  final boss = BossDef(
    'Big Bad Wolf',
    [Assets.bossRun(1), Assets.bossAttack(1), Assets.bossCharge(1), Assets.bossHurt(1), Assets.bossDeath(1)],
    UnitStats(10000, 10000, 100, 5, 4),
    34,
  );
  return LevelDef(1, 'Little Red Riding Hood', 'forest', player, enemies, boss);
}

LevelDef buildLevel2() {
  final player = PlayerDef([
    Assets.pIdle(2),
    Assets.pRun(2),
    Assets.pAttack(2),
    Assets.pHurt(2),
  ], UnitStats(500, 500, 10, 3, 5));

  final enemies = <EnemyDef>[
    EnemyDef('Red Slime', Assets.redSlime, UnitStats(60, 60, 15, 3, 2.6), 15, 18),
    EnemyDef('Green Slime', Assets.greenSlime, UnitStats(180, 180, 20, 5, 2.6), 30, 20),
    EnemyDef('Blue Slime', Assets.blueSlime, UnitStats(600, 600, 30, 4, 2.4), 80, 24),
    EnemyDef('Strong Green Slime', Assets.strongGreenSlime, UnitStats(1000, 1000, 60, 4, 2.4), 80, 26),
    EnemyDef('Strong Blue Slime', Assets.strongBlueSlime, UnitStats(1500, 1500, 100, 4, 2.2), 80, 28),
  ];

  final boss = BossDef(
    'The Witch',
    [Assets.bossRun(2), Assets.bossAttack(2), Assets.bossCharge(2), Assets.bossHurt(2), Assets.bossDeath(2)],
    UnitStats(20000, 20000, 200, 5, 4),
    36,
    verticalFrames: true, // top→bottom frames
  );
  return LevelDef(2, 'Hansel and Gretel', 'candy', player, enemies, boss);
}

LevelDef buildLevel3() {
  final player = PlayerDef([
    Assets.pIdle(3),
    Assets.pRun(3),
    Assets.pAttack(3),
    Assets.pHurt(3),
  ], UnitStats(600, 600, 15, 4, 5));

  final enemies = <EnemyDef>[
    EnemyDef('Female Minotaur', Assets.femaleMinotaur, UnitStats(80, 80, 18, 3, 3.4), 18, 20),
    EnemyDef('Minotaur', Assets.minotaur, UnitStats(220, 220, 22, 5, 3.2), 40, 24),
    EnemyDef('Large Female Minotaur', Assets.femaleMinotaur, UnitStats(900, 900, 40, 4, 3.0), 100, 28),
    EnemyDef('Large Minotaur', Assets.minotaur, UnitStats(1400, 1400, 50, 4, 2.8), 150, 30),
  ];

  final boss = BossDef(
    'Giant',
		[
		  // L3 boss folder has no run.png; use idle.png for the run animation
		  'assets/activity2/lvl3/monsters/boss/idle.png',
		  Assets.bossAttack(3),
		  Assets.bossCharge(3),
		  Assets.bossHurt(3),
		  Assets.bossDeath(3)
		],
    UnitStats(30000, 30000, 250, 6, 3.6),
    38,
  );
  return LevelDef(3, 'Jack and the Beanstalk', 'field', player, enemies, boss);
}

/* ===================== RUNTIME ENTITIES ===================== */
class SpriteAnim {
  final SpriteSheet sheet;
  final double fps;
  double t = 0;
  SpriteAnim(this.sheet, {this.fps = 8});
  void update(double dt) => t += dt * fps;
  int get frame => t.floor();
}

class Entity {
  Offset pos;
  Offset vel;
  double dir;
  bool facingRight = true;
  final UnitStats stats;
  double invuln = 0;
  SpriteAnim? anim;
  final double radius;
  bool dead = false;
  Entity({required this.pos, required this.stats, required this.radius, this.dir = 0, this.vel = Offset.zero});
}

class Projectile {
  Offset pos, vel;
  double life, dmg, pierce;
  final double radius;
  final String? sprite;
  Projectile(this.pos, this.vel, this.life, this.dmg, this.pierce, this.radius, {this.sprite});
}

class MeleeSwing {
  double t; // 0..1
  double dur, angleStart, angleEnd, range, width, dmg;
  final WeaponKind weapon;
  MeleeSwing({
    required this.dur,
    required this.angleStart,
    required this.angleEnd,
    required this.range,
    required this.width,
    required this.dmg,
    required this.weapon,
  }) : t = 0;
}

/* ===================== GAME STATE ===================== */
class _GameState {
  final LevelDef level;
  final Rand rng = Rand();
  late Entity player;

  // score / progression
  int score = 0;
  int pLevel = 1;
  late int pMaxLevel;
  int exp = 0;
  int expToNext = 50;

  // Weapons
  final Map<WeaponKind, int> wLv = {WeaponKind.fist: 1};
  WeaponKind primary = WeaponKind.fist;

  // Effects
  bool gooseActive = false;
  double shield = 0;

  // Runtime
  double time = 0;
  List<Entity> enemies = [];
  List<Projectile> shots = [];
  List<MeleeSwing> swings = [];

  // Animation sheets
  late SpriteSheet pIdle, pRun, pAttack, pHurt;
  late SpriteSheet bossRun, bossAttack, bossCharge, bossHurt, bossDeath;
  final Map<String, ui.Image> cache = {};
  final Map<String, SpriteSheet> singleFrame = {};

  // Drops
  List<Offset> hearts = [];

  // Camera
  Offset camera = Offset.zero;

  _GameState(this.level) {
    pMaxLevel = [10, 15, 20][level.index - 1];
  }

  Future<void> load(BuildContext ctx) async {
    // Player sheets
    pIdle = SpriteSheet(image: await _img(ctx, level.player.animPaths[0]), frames: 8);
    pRun = SpriteSheet(image: await _img(ctx, level.player.animPaths[1]), frames: 8);
    pAttack = SpriteSheet(image: await _img(ctx, level.player.animPaths[2]), frames: 8);
    pHurt = SpriteSheet(image: await _img(ctx, level.player.animPaths[3]), frames: 8);

    // Boss sheets (L2 boss vertical)
    final v = level.boss.verticalFrames;
    bossRun = SpriteSheet(image: await _img(ctx, level.boss.animPaths[0]), frames: 8, vertical: v);
    bossAttack = SpriteSheet(image: await _img(ctx, level.boss.animPaths[1]), frames: 8, vertical: v);
    bossCharge = SpriteSheet(image: await _img(ctx, level.boss.animPaths[2]), frames: 8, vertical: v);
    bossHurt = SpriteSheet(image: await _img(ctx, level.boss.animPaths[3]), frames: 8, vertical: v);
    bossDeath = SpriteSheet(image: await _img(ctx, level.boss.animPaths[4]), frames: 8, vertical: v);

    // Regular monsters → treat as 4-frame bobbing
    for (final e in level.enemies) {
      final img = await _img(ctx, e.spritePath);
      cache[e.spritePath] = img;
      singleFrame[e.spritePath] = SpriteSheet(image: img, frames: 4);
    }

    // Item images
    for (final p in [
      Assets.fist,
      Assets.forcefield,
      Assets.goose,
      Assets.gun,
      Assets.gunBullet,
      Assets.heart,
      Assets.scythe,
      Assets.sword,
      Assets.wand,
      Assets.wandSpark,
    ]) {
      if (p.endsWith('.gif')) continue;
      cache[p] = await _img(ctx, p);
    }

    player = Entity(pos: Offset.zero, stats: level.player.base, radius: 18)..anim = SpriteAnim(pIdle);
  }

  Future<ui.Image> _img(BuildContext ctx, String asset) async {
    if (cache.containsKey(asset)) return cache[asset]!;
    final img = await loadImage(ctx, asset);
    cache[asset] = img;
    return img;
  }

  void gainExp(int v) {
    exp += v;
    while (exp >= expToNext && pLevel < pMaxLevel) {
      exp -= expToNext;
      pLevel += 1;
      expToNext *= 2;
      _offerWeapons();
    }
  }

  // choose 2 random weapons to offer
  List<WeaponKind> _lastOffer = [];
  void _offerWeapons() {
    final all = WeaponKind.values;
    final picks = <WeaponKind>{};
    while (picks.length < 2) {
      picks.add(all[rng.intN(all.length)]);
    }
    _lastOffer = picks.toList();
  }

  List<WeaponKind> get weaponOffer => _lastOffer;

  void takeWeapon(WeaponKind w) {
    final cur = wLv[w] ?? 0;
    if (cur < 5) wLv[w] = cur + 1;
    if (w == WeaponKind.goose) gooseActive = true;
    if (w == WeaponKind.wand || w == WeaponKind.gun || w == WeaponKind.fist) {
      primary = w;
    }
    if (w == WeaponKind.goose) {
      final lvl = wLv[w]!;
      final bonus = [200, 300, 300, 400, 500][lvl - 1].toDouble();
      player.stats.maxHp += bonus;
      player.stats.hp += bonus;
    }
  }
}

/* ===================== PAGE (HOME/PLAY/RESULT) ===================== */
class _Activity2PageState extends State<Activity2Page> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late _GameState g;
  bool loaded = false;

  // Screens
  GameScreen screen = GameScreen.home;
  bool resultWin = false;

  // Pause & level pick overlay
  bool paused = false;
  bool showWeaponPick = false;

  // Input
  Offset jsPos = Offset.zero;
  Offset jsDrag = Offset.zero;
  bool sprintHeld = false;
  double stamina = 100;
  double staminaMax = 100;

  int currentLevelIndex = 1;

  @override
  void initState() {
    super.initState();
    g = _GameState(buildLevel1());
    _ticker = createTicker(_tick)..start();
    // start on Home
    // assets are lazy-loaded on startGame(level)
  }

Future<void> _startGame(int levelIdx) async {
  setState(() {
    screen = GameScreen.playing;        // go to game screen immediately
    currentLevelIndex = levelIdx;
    loaded = false;
    paused = false;
    showWeaponPick = false;
    stamina = staminaMax = 100;
  });

  try {
    final lvl = [buildLevel1(), buildLevel2(), buildLevel3()][levelIdx - 1];
    g = _GameState(lvl);
    await g.load(context);
    if (!mounted) return;
    setState(() => loaded = true);
  } catch (e) {
    // If *anything* goes wrong (usually a missing asset), show a readable result screen
    if (!mounted) return;
    debugPrint('Game load failed: $e');
    setState(() {
      resultWin = false;
      screen = GameScreen.result;
      paused = true;
      loaded = false;
      // Make it obvious for you during dev:
      g.score = -1; // negative score = load error flag
    });
  }
}


  void _backHome() {
    setState(() {
      screen = GameScreen.home;
      loaded = false;
      paused = false;
      showWeaponPick = false;
      jsPos = Offset.zero;
      jsDrag = Offset.zero;
      sprintHeld = false;
    });
  }

  double _lastTs = 0;
  void _tick(Duration d) {
    if (!mounted || screen != GameScreen.playing || !loaded || paused) return;
    final ts = d.inMicroseconds / 1e6;
    final double dt = (_lastTs == 0) ? 0.0 : (ts - _lastTs);
    _lastTs = ts;
    _update(dt);
  }

  void _endGame(bool win) {
    setState(() {
      resultWin = win;
      screen = GameScreen.result;
      paused = true;
    });
  }

  void _update(double dt) {
    final gstate = g;

    // time & waves
    gstate.time += dt;
    _waves(dt);

    // movement input from joystick
    final mv = jsDrag;
    if (mv.distance > 4) {
      final dir = mv.direction;
      gstate.player.dir = dir;
      gstate.player.facingRight = math.cos(dir) >= 0;
      final spdBase = gstate.level.player.base.speed;
      final spd = sprintHeld && stamina > 0 ? spdBase * 1.8 : spdBase;
      final v = Offset(math.cos(dir), math.sin(dir)) * spd * 60 * dt;
      gstate.player.pos += v;
      stamina -= sprintHeld ? 25 * dt : -15 * dt;
      stamina = clamp(stamina, 0, staminaMax);
      gstate.player.anim = SpriteAnim(gstate.pRun, fps: 10);
    } else {
      gstate.player.anim = SpriteAnim(gstate.pIdle, fps: 6);
      stamina = clamp(stamina + 20 * dt, 0, staminaMax);
    }

    // camera follows player
    gstate.camera = gstate.player.pos;

    // auras
    _applyForcefield(dt);
    _applyGoose(dt);

    // enemy AI
    for (final e in gstate.enemies) {
      if (e.dead) continue;
      final toP = gstate.player.pos - e.pos;
      final dist = toP.distance;
      e.dir = math.atan2(toP.dy, toP.dx);
      e.facingRight = math.cos(e.dir) >= 0;
      final step = e.stats.speed * 60 * dt;
      if (dist > e.stats.range * 8 + e.radius + gstate.player.radius) {
        e.pos += Offset(math.cos(e.dir), math.sin(e.dir)) * step;
      } else {
        if (e.invuln <= 0) {
          _damagePlayer(e.stats.dmg * dt * 0.8);
          e.invuln = 0.1;
        }
      }
      e.invuln = math.max(0, e.invuln - dt);
      e.anim?.update(dt);
    }

    // player fire
    _autoAttack(dt);

    // projectiles
    final hitList = <int>{};
    for (int i = gstate.shots.length - 1; i >= 0; i--) {
      final s = gstate.shots[i];
      s.pos += s.vel * 60 * dt;
      s.life -= dt;
      if (s.life <= 0) {
        gstate.shots.removeAt(i);
        continue;
      }
      for (int j = 0; j < gstate.enemies.length; j++) {
        if (hitList.contains(j)) continue;
        final e = gstate.enemies[j];
        if (e.dead) continue;
        if ((e.pos - s.pos).distance < e.radius + s.radius) {
          _damageEnemy(e, s.dmg);
          s.pierce -= 1;
          if (s.pierce <= 0) {
            gstate.shots.removeAt(i);
          }
          hitList.add(j);
          break;
        }
      }
    }

    // melee swings
    for (int i = gstate.swings.length - 1; i >= 0; i--) {
      final sw = gstate.swings[i];
      sw.t += dt / sw.dur;
      final p = gstate.player.pos;
      for (final e in gstate.enemies) {
        if (e.dead) continue;
        final v = e.pos - p;
        final ang = math.atan2(v.dy, v.dx);
        final tAng = _angleLerp(sw.angleStart, sw.angleEnd, sw.t.clamp(0, 1));
        final diff = _angleDiff(ang, tAng);
        final inRange = v.distance <= sw.range * 8 + e.radius + 6;
        if (inRange && diff.abs() < 0.7) {
          _damageEnemy(e, sw.dmg);
          if (sw.weapon == WeaponKind.scythe) {
            _applyDot(e, sw.dmg * 0.5, 5);
          }
        }
      }
      if (sw.t >= 1) gstate.swings.removeAt(i);
    }

    // cleanup & drops
    for (final e in gstate.enemies) {
      if (!e.dead && e.stats.hp <= 0) {
        e.dead = true;
        if (gstate.rng.next() < 0.08) gstate.hearts.add(e.pos);
        gstate.score += 5;
        gstate.gainExp(20);
      }
    }
    gstate.enemies.removeWhere((e) => e.dead);

    // pickup hearts
    for (int i = gstate.hearts.length - 1; i >= 0; i--) {
      if ((gstate.hearts[i] - gstate.player.pos).distance < 26) {
        gstate.player.stats.hp = math.min(gstate.player.stats.maxHp, gstate.player.stats.hp + 40);
        gstate.hearts.removeAt(i);
      }
    }

    // player anim
    gstate.player.anim?.update(dt);

    // lose
    if (gstate.player.stats.hp <= 0) {
      _endGame(false);
    }

    // level-up overlay
    if (gstate.weaponOffer.isNotEmpty && !showWeaponPick) {
      setState(() => showWeaponPick = true);
    }
    setState(() {});
  }

  // angle helpers
  double _angleLerp(double a, double b, double t) {
    double d = _angleDiff(b, a);
    return a + d * t;
  }
  double _angleDiff(double a, double b) {
    double d = a - b;
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  void _damageEnemy(Entity e, double dmg) {
    double dealt = dmg;
    final swLv = g.wLv[WeaponKind.sword] ?? 0;
    if (swLv > 0) {
      final bonus = [0, 20, 50, 150, 500][swLv - 1].toDouble();
      dealt += bonus;
    }
    e.stats.hp -= dealt;
    if (swLv > 0 && g.player.stats.hp < g.player.stats.maxHp) {
      g.player.stats.hp = math.min(g.player.stats.maxHp, g.player.stats.hp + dealt);
    } else if (swLv >= 3) {
      g.shield = math.min<double>(300.0, g.shield + dealt * 0.2);
    }

    // Win check: if only bosses remain and their HP drop, you can gate victory later if desired.
    // Here we keep scripted victory in _waves() for L3 end; you can call _endGame(true) elsewhere if needed.
  }

  void _applyDot(Entity e, double perSec, int seconds) {
    for (int i = 1; i <= seconds; i++) {
      Future.delayed(Duration(milliseconds: 1000 * i), () {
        if (!mounted || screen != GameScreen.playing) return;
        e.stats.hp -= perSec;
      });
    }
  }

  void _damagePlayer(double dmg) {
    if (g.shield > 0) {
      final take = math.min<double>(g.shield, dmg);
      g.shield -= take;
      dmg -= take;
    }
    if (dmg > 0) g.player.stats.hp -= dmg;
  }

  double _attackTimer = 0;
  void _autoAttack(double dt) {
    _attackTimer -= dt;
    if (_attackTimer > 0) return;
    _attackTimer = 0.35;
    final p = g.player;
    final dir = p.dir;
    final facing = Offset(math.cos(dir), math.sin(dir));

    switch (g.primary) {
      case WeaponKind.fist:
        g.shots.add(Projectile(p.pos + facing * 22, facing * 8, 0.12, p.stats.dmg, 1, 8, sprite: Assets.fist));
        break;
      case WeaponKind.wand:
        final lvl = g.wLv[WeaponKind.wand] ?? 1;
        final mult = [30, 100, 200, 300, 500][lvl - 1].toDouble();
        final rangeBonus = [1, 1, 2, 2, 3][lvl - 1].toDouble();
        final shots = [1, 1, 2, 2, 3][lvl - 1];
        for (int i = 0; i < shots; i++) {
          final spread = (i - (shots - 1) / 2) * 0.12;
          g.shots.add(Projectile(
            p.pos + facing * 24,
            Offset(math.cos(dir + spread), math.sin(dir + spread)) * 10,
            0.8,
            p.stats.dmg + mult,
            1,
            10,
            sprite: Assets.wandSpark,
          ));
        }
        p.stats.range = g.level.player.base.range + rangeBonus;
        break;
      case WeaponKind.gun:
        final lvlG = g.wLv[WeaponKind.gun] ?? 1;
        final multG = [10, 30, 60, 120, 300][lvlG - 1].toDouble();
        final targets = [2, 2, 3, 3, 5][lvlG - 1].toDouble();
        final rangeBonusG = [0, 1, 1, 2, 2][lvlG - 1].toDouble();
        g.shots.add(Projectile(p.pos + facing * 26, facing * 16, 0.9, p.stats.dmg + multG, targets, 8,
            sprite: Assets.gunBullet));
        p.stats.range = g.level.player.base.range + rangeBonusG;
        break;
      default:
        break;
    }

    // sword / scythe melee swings
    if ((g.wLv[WeaponKind.sword] ?? 0) > 0) {
      final bonus = [0, 20, 50, 150, 500][(g.wLv[WeaponKind.sword] ?? 1) - 1].toDouble();
      _startSwing(WeaponKind.sword, p.stats.range * 9, p.stats.dmg + bonus);
    }
    if ((g.wLv[WeaponKind.scythe] ?? 0) > 0) {
      final lvl = g.wLv[WeaponKind.scythe]!;
      final rangeBonus = [1, 2, 3, 4, 5][lvl - 1].toDouble();
      p.stats.range = g.level.player.base.range + rangeBonus;
      final base = [20, 30, 60, 160, 300][lvl - 1].toDouble();
      final period = lvl <= 2 ? 3.0 : 2.0;
      _startSwing(WeaponKind.scythe, p.stats.range * 10, base);
      _attackTimer = period;
    }
  }

  void _startSwing(WeaponKind w, double reachPx, double dmg) {
    final dir = g.player.dir;
    final sw = MeleeSwing(
      dur: 0.25,
      angleStart: dir + 0.9,
      angleEnd: dir - 0.9,
      range: reachPx / 8,
      width: 16,
      dmg: dmg,
      weapon: w,
    );
    g.swings.add(sw);
  }

  void _applyForcefield(double dt) {
    final lvl = g.wLv[WeaponKind.forcefield] ?? 0;
    if (lvl <= 0) return;
    final rBonus = [1, 2, 3, 4, 5][lvl - 1].toDouble();
    final dps = [0, 15, 40, 100, 300][lvl - 1].toDouble();
    final rngTiles = (g.level.player.base.range + rBonus) * 8 + 8;
    for (final e in g.enemies) {
      final d = (e.pos - g.player.pos).distance;
      if (d <= rngTiles) {
        e.vel = e.vel * 0.6;
        if (dps > 0) e.stats.hp -= dps * dt;
      }
    }
  }

  void _applyGoose(double dt) {
    final lvl = g.wLv[WeaponKind.goose] ?? 0;
    if (lvl <= 0) return;
    final heal = [10, 10, 15, 15, 20][lvl - 1].toDouble();
    final sMax = [0, 150, 200, 250, 300][lvl - 1].toDouble();
    g.player.stats.hp = math.min(g.player.stats.maxHp, g.player.stats.hp + heal * dt);
    if (g.player.stats.hp >= g.player.stats.maxHp) {
      g.shield = math.min<double>(sMax, g.shield + heal * 0.5 * dt);
    }
  }

  /* ===================== WAVES ===================== */
  double _spawnTimer = 0;
  void _waves(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;

    final lv = g.level.index;
    final t = g.time;

    void spawn(EnemyDef def, int count, [double near = 120]) {
      for (int i = 0; i < count; i++) {
        final dir = g.rng.range(0, math.pi * 2);
        final dist = g.rng.range(near, near + 80);
        final pos = g.player.pos + Offset(math.cos(dir), math.sin(dir)) * dist;
        final e = Entity(
            pos: pos,
            stats: UnitStats(def.stats.hp, def.stats.maxHp, def.stats.dmg, def.stats.range, def.stats.speed),
            radius: def.hitbox)
          ..anim = SpriteAnim(g.singleFrame[def.spritePath]!, fps: 6);
        g.enemies.add(e);
      }
    }

    if (lv == 1) {
      if (t < 30) {
        spawn(buildLevel1().enemies[0], 3);
        _spawnTimer = 1;
      } else if (t < 60) {
        spawn(buildLevel1().enemies[0], 5);
        spawn(buildLevel1().enemies[1], 3);
        _spawnTimer = 5;
      } else if (t < 120) {
        spawn(buildLevel1().enemies[0], 3);
        spawn(buildLevel1().enemies[1], 3);
        _spawnTimer = 1;
      } else if (t < 150) {
        spawn(buildLevel1().enemies[2], 8);
        _spawnTimer = 5;
      } else if (t < 180) {
        spawn(buildLevel1().enemies[1], 5);
        spawn(buildLevel1().enemies[2], 5);
        _spawnTimer = 1;
      } else {
        if (!g.enemies.any((e) => e.stats.maxHp >= 9000)) {
          final bd = g.level.boss;
          final e = Entity(
            pos: g.player.pos + g.rng.circle(200),
            stats: UnitStats(bd.stats.hp, bd.stats.maxHp, bd.stats.dmg, bd.stats.range, bd.stats.speed),
            radius: bd.hitbox,
          )..anim = SpriteAnim(g.bossRun, fps: 8);
          g.enemies.add(e);
        }
        _spawnTimer = 3;
      }
      // Victory condition for L1: survive until 210s then clear boss
      if (t > 210 && g.enemies.where((e) => e.stats.maxHp >= 9000).isEmpty) _endGame(true);
    } else if (lv == 2) {
      final E = buildLevel2().enemies;
      if (t < 30) {
        spawn(E[0], 4);
        _spawnTimer = 1;
      } else if (t < 60) {
        for (int i = 0; i < 12; i++) {
          spawn(g.rng.next() < 0.5 ? E[0] : E[1], 1);
        }
        _spawnTimer = 5;
      } else if (t < 120) {
        spawn(E[1], 4);
        spawn(E[2], 2);
        _spawnTimer = 1;
      } else if (t < 150) {
        spawn(E[1], 10);
        if (t % 10 < 0.5) spawn(E[2], 10);
        _spawnTimer = 5;
      } else if (t < 180) {
        spawn(E[2], 5);
        spawn(E[1], 3);
        spawn(E[3], 1);
        _spawnTimer = 1;
      } else if (t < 210) {
        spawn(E[3], 6);
        if (t % 10 < 0.5) spawn(E[4], 6);
        _spawnTimer = 5;
      } else if (t < 240) {
        spawn(E[4], 6);
        spawn(E[3], 4);
        spawn(E[1], 1);
        _spawnTimer = 1;
      } else {
        if (!g.enemies.any((e) => e.stats.maxHp >= 19000)) {
          final bd = g.level.boss;
          final e = Entity(
            pos: g.player.pos + g.rng.circle(220),
            stats: UnitStats(bd.stats.hp, bd.stats.maxHp, bd.stats.dmg, bd.stats.range, bd.stats.speed),
            radius: bd.hitbox,
          )..anim = SpriteAnim(g.bossRun, fps: 8);
          g.enemies.add(e);
        }
        spawn(E[0], 3);
        spawn(E[2], 2);
        _spawnTimer = 1.2;
      }
      // Victory: boss cleared after 4:00+
      if (t > 240 && g.enemies.where((e) => e.stats.maxHp >= 19000).isEmpty) _endGame(true);
    } else {
      final E = buildLevel3().enemies;
      if (t < 30) {
        spawn(E[0], 5);
        _spawnTimer = 1;
      } else if (t < 60) {
        spawn(E[0], 15);
        _spawnTimer = 5;
      } else if (t < 120) {
        spawn(E[0], 4);
        spawn(E[1], 2);
        _spawnTimer = 1;
      } else if (t < 150) {
        spawn(E[1], 10);
        if (t % 10 < 0.5) spawn(E[0], 8);
        _spawnTimer = 5;
      } else if (t < 180) {
        spawn(E[0], 4);
        spawn(E[1], 3);
        _spawnTimer = 1;
      } else if (t < 240) {
        if (!g.enemies.any((e) => e.stats.maxHp >= 29000)) {
          final bd = g.level.boss;
          final e = Entity(
            pos: g.player.pos + g.rng.circle(240),
            stats: UnitStats(bd.stats.hp, bd.stats.maxHp, bd.stats.dmg, bd.stats.range, bd.stats.speed),
            radius: bd.hitbox,
          )..anim = SpriteAnim(g.bossRun, fps: 8);
          g.enemies.add(e);
        }
        spawn(E[0], 6);
        spawn(E[1], 6);
        _spawnTimer = 1;
      } else if (t < 300) {
        if (g.enemies.where((e) => e.stats.maxHp >= 29000).length < 2) {
          final bd = g.level.boss;
          final e = Entity(
            pos: g.player.pos + g.rng.circle(240),
            stats: UnitStats(bd.stats.hp, bd.stats.maxHp, bd.stats.dmg, bd.stats.range, bd.stats.speed),
            radius: bd.hitbox,
          )..anim = SpriteAnim(g.bossRun, fps: 8);
          g.enemies.add(e);
        }
        _spawnTimer = 1.5;
      } else {
        final have = g.enemies.where((e) => e.stats.maxHp >= 29000).length;
        for (int i = have; i < 3; i++) {
          final bd = g.level.boss;
          final e = Entity(
            pos: g.player.pos + g.rng.circle(280),
            stats: UnitStats(bd.stats.hp, bd.stats.maxHp, bd.stats.dmg, bd.stats.range, bd.stats.speed),
            radius: bd.hitbox,
          )..anim = SpriteAnim(g.bossRun, fps: 8);
          g.enemies.add(e);
        }
        if (g.enemies.where((e) => e.stats.maxHp >= 29000).isEmpty) {
          _endGame(true);
        }
        _spawnTimer = 2;
      }
    }
  }

  /* ===================== BUILD ===================== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return Stack(
            children: [
              if (screen == GameScreen.home) _buildHome(size),
              if (screen == GameScreen.playing) _buildGame(size),
              if (screen == GameScreen.result) _buildResult(size),
            ],
          );
        },
      ),
    );
  }

  /* ---------- HOME ---------- */
  Widget _buildHome(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 380,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chapter 2 — Adventure',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _levelCard(1, 'Little Red Riding Hood', 'forest', () => _startGame(1)),
              const SizedBox(height: 8),
              _levelCard(2, 'Hansel & Gretel', 'candy', () => _startGame(2)),
              const SizedBox(height: 8),
              _levelCard(3, 'Jack and the Beanstalk', 'field', () => _startGame(3)),
              const SizedBox(height: 12),
              const Text('Tip: Pick upgrades when you level up!', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(int idx, String title, String theme, VoidCallback onPlay) {
    Color c1, c2;
    switch (theme) {
      case 'forest':
        c1 = const Color(0xFF254C2F); c2 = const Color(0xFF2F6C3A); break;
      case 'candy':
        c1 = const Color(0xFFFFE4EC); c2 = const Color(0xFFFBA3C6); break;
      default:
        c1 = const Color(0xFF96D35F); c2 = const Color(0xFF5DAA3B); break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Level $idx — $title',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
          ElevatedButton(
            onPressed: onPlay,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }

  /* ---------- GAME ---------- */
  Widget _buildGame(Size size) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onPanStart: (d) {
        final p = d.localPosition;
        if (p.dx < size.width * 0.5 && p.dy > size.height * 0.5) {
          jsPos = p;
          jsDrag = Offset.zero;
        }
      },
      onPanUpdate: (d) {
        if (jsPos == Offset.zero) return;
        final delta = d.localPosition - jsPos;
        jsDrag = delta.distance > 60 ? delta / delta.distance * 60 : delta;
      },
      onPanEnd: (d) {
        jsPos = Offset.zero;
        jsDrag = Offset.zero;
      },
      child: Stack(
        children: [
          // Game canvas
          CustomPaint(size: size, painter: _GamePainter(g: g, size: size)),

          // HUD
          Positioned(left: 16, top: 28, child: _topHud()),
          Positioned(right: 16, top: 28, child: _levelScoreHud()),

          // Sprint button
          Positioned(
            left: 24, bottom: 140,
            child: GestureDetector(
              onTapDown: (_) => setState(() => sprintHeld = true),
              onTapUp: (_) => setState(() => sprintHeld = false),
              onTapCancel: () => setState(() => sprintHeld = false),
              child: _roundLabel('SPRINT\n(STAMINA)'),
            ),
          ),

          // Joystick
          Positioned(
            left: 24, bottom: 24,
            child: CustomPaint(painter: _JoystickPainter(jsDrag), size: const Size(120, 120)),
          ),

          // Level switch / pause / quit
          Positioned(
            right: 16, bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniIcon(Icons.home, _backHome),
                const SizedBox(width: 8),
                _miniIcon(Icons.restart_alt, () => _startGame(currentLevelIndex)),
                const SizedBox(width: 8),
                _miniIcon(Icons.pause, () => setState(() => paused = !paused), toggled: paused),
              ],
            ),
          ),

          // Forcefield GIF under player
          if ((g.wLv[WeaponKind.forcefield] ?? 0) > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    Assets.forcefield,
                    width: 160 + (g.level.player.base.range + (g.wLv[WeaponKind.forcefield] ?? 1)) * 10,
                    height: 160 + (g.level.player.base.range + (g.wLv[WeaponKind.forcefield] ?? 1)) * 10,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          // Weapon choices
          if (showWeaponPick) _weaponChoiceOverlay(),

          // Paused overlay
          if (paused) _pauseCurtain(),
        ],
      ),
    );
  }

  /* ---------- RESULT ---------- */
  Widget _buildResult(Size size) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 360,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(resultWin ? 'You Win!' : 'Game Over',
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: resultWin ? Colors.green.shade700 : Colors.red.shade700,
                  )),
              const SizedBox(height: 8),
              Text('Score: ${g.score}'),
              Text('Level: ${g.level.index} — ${g.level.name}'),
              Text('Time survived: ${g.time.toStringAsFixed(1)}s'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _startGame(currentLevelIndex),
                    child: const Text('Restart'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _backHome,
                    child: const Text('Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------- UI helpers ---------- */
  Widget _pauseCurtain() {
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paused', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: () => setState(() => paused = false), child: const Text('Resume')),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: () => _startGame(currentLevelIndex), child: const Text('Restart')),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: _backHome, child: const Text('Home')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weaponChoiceOverlay() {
    final offers = g.weaponOffer;
    if (offers.isEmpty) return const SizedBox.shrink();

    Widget tile(WeaponKind kind) {
      final (label, icon) = _weaponLabel(kind);
      return Expanded(
        child: InkWell(
          onTap: () {
            g.takeWeapon(kind);
            setState(() => showWeaponPick = false);
          },
          child: Container(
            height: 120,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Image.asset(icon, width: 48, height: 48, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Lv ${(g.wLv[kind] ?? 0) + 1}', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose an Upgrade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [tile(offers.first), tile(offers.last)]),
            ],
          ),
        ),
      ),
    );
  }

  (String, String?) _weaponLabel(WeaponKind k) {
    switch (k) {
      case WeaponKind.fist:
        return ('Fist (default)', Assets.fist);
      case WeaponKind.wand:
        return ('Magic Wand', Assets.wand);
      case WeaponKind.gun:
        return ('Gun', Assets.gun);
      case WeaponKind.sword:
        return ('Holy Sword', Assets.sword);
      case WeaponKind.scythe:
        return ('Scythe', Assets.scythe);
      case WeaponKind.forcefield:
        return ('Forcefield', Assets.forcefield);
      case WeaponKind.goose:
        return ('Goose (heal+shield)', Assets.goose);
    }
  }

  Widget _miniIcon(IconData icon, VoidCallback onTap, {bool toggled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: toggled ? Colors.redAccent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Icon(icon, color: toggled ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _roundLabel(String t) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      alignment: Alignment.center,
      child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _topHud() {
    final hp = g.player.stats.hp;
    final hpMax = g.player.stats.maxHp;
    final hpPct = math.min(1.0, math.max(0.0, hp / hpMax));
    final expPct = math.min(1.0, math.max(0.0, g.exp / g.expToNext));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(label: 'HP', value: hpPct, color: Colors.redAccent,
            text: '${hp.toStringAsFixed(0)}/${hpMax.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        _bar(label: 'EXP', value: expPct, color: Colors.amber,
            text: 'Lv ${g.pLevel}/${g.pMaxLevel} • ${g.exp}/${g.expToNext}'),
        const SizedBox(height: 6),
        _bar(label: 'STAMINA', value: stamina / staminaMax, color: Colors.lightGreen,
            text: '${stamina.toStringAsFixed(0)}'),
        if (g.shield > 0) ...[
          const SizedBox(height: 6),
          _bar(label: 'SHIELD', value: math.min(1.0, g.shield / 300.0), color: Colors.cyan,
              text: '${g.shield.toStringAsFixed(0)}'),
        ],
      ],
    );
  }

  Widget _levelScoreHud() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _tag('Level ${g.level.index}: ${g.level.name}'),
        const SizedBox(height: 8),
        _tag('Score: ${g.score}'),
        const SizedBox(height: 8),
        _tag('Time: ${g.time.toStringAsFixed(1)}s'),
        const SizedBox(height: 8),
        _tag('Primary: ${_weaponLabel(g.primary).$1.split(' ').first}'),
      ],
    );
  }

  Widget _tag(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _bar({required String label, required double value, required Color color, String? text}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 12,
              color: color,
              backgroundColor: Colors.black12,
            ),
          ),
          if (text != null) ...[
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]
        ],
      ),
    );
  }
}

/* ===================== PAINTERS ===================== */
class _GamePainter extends CustomPainter {
  final _GameState g;
  final Size size;
  _GamePainter({required this.g, required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    _paintTiles(canvas, s);

    final center = Offset(s.width / 2, s.height / 2);

    // Hearts
    for (final h in g.hearts) {
      final sp = _toScreen(h, s);
      _blitImage(canvas, g.cache[Assets.heart]!, Rect.fromCenter(center: sp, width: 26, height: 26));
    }

    // Projectiles
    for (final p in g.shots) {
      final sp = _toScreen(p.pos, s);
      if (p.sprite != null && g.cache.containsKey(p.sprite!)) {
        _blitImage(canvas, g.cache[p.sprite!]!, Rect.fromCenter(center: sp, width: 18, height: 18));
      } else {
        canvas.drawCircle(sp, p.radius, Paint()..color = Colors.white);
      }
    }

    // Melee swings
    for (final sw in g.swings) {
      final p = g.player.pos;
      final pScr = _toScreen(p, s);
      final tAng = _angleLerp(sw.angleStart, sw.angleEnd, sw.t.clamp(0, 1));
      final reach = sw.range * 8;
      final end = pScr + Offset(math.cos(tAng), math.sin(tAng)) * reach;

      final paint = Paint()
        ..color = sw.weapon == WeaponKind.scythe ? Colors.deepPurpleAccent.withOpacity(0.35) : Colors.orange.withOpacity(0.35)
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pScr, end, paint);

      final img = sw.weapon == WeaponKind.scythe ? g.cache[Assets.scythe]! : g.cache[Assets.sword]!;
      final w = 36 + reach * 0.3;
      final h = 36 + reach * 0.2;
      canvas.save();
      canvas.translate(end.dx, end.dy);
      canvas.rotate(tAng + math.pi * 0.5);
      _blitImage(canvas, img, Rect.fromCenter(center: Offset.zero, width: w, height: h));
      canvas.restore();
    }

    // Enemies
    for (final e in g.enemies) {
      final sp = _toScreen(e.pos, s);
      final sheet = e.anim?.sheet;
      if (sheet != null) {
        final frame = e.anim!.frame;
        final src = sheet.srcRectFor(frame);
        final dst = Rect.fromCenter(center: sp, width: sheet.frameW * 0.35, height: sheet.frameH * 0.35);
        canvas.save();
        if (!e.facingRight) {
          canvas.translate(dst.center.dx, dst.center.dy);
          canvas.scale(-1, 1);
          canvas.translate(-dst.center.dx, -dst.center.dy);
        }
        canvas.drawImageRect(sheet.image, src, dst, Paint());
        canvas.restore();
      }
      // HP bar
      final hpPct = math.min(1.0, math.max(0.0, e.stats.hp / e.stats.maxHp));
      final barW = 40.0;
      final bar = Rect.fromLTWH(sp.dx - barW / 2, sp.dy + (e.radius + 18), barW * hpPct, 5);
      final barBg = Rect.fromLTWH(sp.dx - barW / 2, sp.dy + (e.radius + 18), barW, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(barBg, const Radius.circular(3)), Paint()..color = Colors.black26);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(3)), Paint()..color = Colors.redAccent);
    }

    // Player (center)
    final p = g.player;
    final sheet = p.anim!.sheet;
    final src = sheet.srcRectFor(p.anim!.frame);
    final dst = Rect.fromCenter(center: center, width: sheet.frameW * 0.38, height: sheet.frameH * 0.38);
    canvas.save();
    if (!p.facingRight) {
      canvas.translate(dst.center.dx, dst.center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-dst.center.dx, -dst.center.dy);
    }
    canvas.drawImageRect(sheet.image, src, dst, Paint());
    canvas.restore();
  }

  Offset _toScreen(Offset world, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final delta = world - g.camera;
    return center + delta;
  }

  void _paintTiles(Canvas canvas, Size s) {
    final theme = g.level.theme;
    late final Color a, b, deco;
    switch (theme) {
      case 'forest':
        a = const Color(0xFF254C2F);
        b = const Color(0xFF2F6C3A);
        deco = const Color(0xFF1B3A24);
        break;
      case 'candy':
        a = const Color(0xFFFFE4EC);
        b = const Color(0xFFFFD3E1);
        deco = const Color(0xFFFBA3C6);
        break;
      default:
        a = const Color(0xFF96D35F);
        b = const Color(0xFF7DC957);
        deco = const Color(0xFF5DAA3B);
        break;
    }

    canvas.drawRect(Offset.zero & s, Paint()..color = a);

    final tile = 64.0;
    final offX = ((g.camera.dx % tile) + tile) % tile;
    final offY = ((g.camera.dy % tile) + tile) % tile;

    final paintB = Paint()..color = b;
    for (double y = -offY; y < s.height + tile; y += tile) {
      for (double x = -offX; x < s.width + tile; x += tile) {
        final r = Rect.fromLTWH(x, y, tile - 2, tile - 2);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), paintB);
      }
    }

    final decoPaint = Paint()..color = deco.withOpacity(0.12);
    for (double y = -offY + tile / 2; y < s.height + tile / 2; y += tile) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), decoPaint..strokeWidth = 2);
    }
  }

  void _blitImage(Canvas canvas, ui.Image img, Rect dst) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, Paint());
  }

  double _angleLerp(double a, double b, double t) {
    double d = _angleDiff(b, a);
    return a + d * t;
  }

  double _angleDiff(double a, double b) {
    double d = a - b;
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}

class _JoystickPainter extends CustomPainter {
  final Offset drag;
  _JoystickPainter(this.drag);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = Paint()..color = const Color(0x88FFFFFF);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black26;

    canvas.drawCircle(center, 54, base);
    canvas.drawCircle(center, 54, rim);

    final knob = center + _clampMagnitude(drag, 54);
    final knobPaint = Paint()..color = Colors.white;
    canvas.drawCircle(knob, 22, knobPaint);
    canvas.drawCircle(knob, 22, rim);
  }

  Offset _clampMagnitude(Offset v, double m) {
    final d = v.distance;
    if (d <= m) return v;
    return v / d * m;
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) => oldDelegate.drag != drag;
}
