import 'dart:math' as math;

import '../core/arcade.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';

/// Brick types: 1..3 = hit points, 8 = steel (unbreakable), 9 = bomb.
const int kSteel = 8;
const int kBomb = 9;

class BrickLevel {
  final ArcadeMeta meta;
  final int cols;
  final int rows;
  final List<int> bricks; // row-major, 0 = empty
  final double ballSpeed;
  final bool powerups;
  final bool movingPaddleShrink;

  const BrickLevel({
    required this.meta,
    required this.cols,
    required this.rows,
    required this.bricks,
    required this.ballSpeed,
    required this.powerups,
    required this.movingPaddleShrink,
  });

  int get breakable => bricks.where((b) => b > 0 && b != kSteel).length;
}

const double kBrickTop = 220;
const double kBrickH = 44;
const double kPaddleY = 1460;

List<int> _layout(SeededRandom r, int cols, int rows, int d, LevelSpec? spec) {
  final b = List<int>.filled(cols * rows, 0);
  final pattern = r.nextInt(5);
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final mx = x < cols / 2 ? x : cols - 1 - x; // mirror symmetry
      bool on;
      switch (pattern) {
        case 0:
          on = true;
        case 1:
          on = (mx + y).isEven || y == 0;
        case 2:
          on = mx >= y ~/ 2;
        case 3:
          on = y % 3 != 2;
        default:
          on = (mx * 7 + y * 3) % 5 != 0;
      }
      if (!on) continue;
      var v = 1;
      if ((spec?.has('armor') ?? false) || d >= 5) {
        if (r.chance(0.15 + d * 0.03)) v = d >= 7 ? 3 : 2;
      }
      b[y * cols + x] = v;
    }
  }
  if (spec?.has('steel') ?? false) {
    // Steel only in alternate cells of one row so the ball can pass.
    final row = r.range(1, rows - 1);
    for (var x = 1; x < cols; x += 4) {
      b[row * cols + x] = kSteel;
    }
  }
  if (spec?.has('bombs') ?? false) {
    for (var k = 0; k < 2 + d ~/ 3; k++) {
      final i = r.nextInt(b.length);
      if (b[i] != kSteel) b[i] = kBomb;
    }
  }
  if (!b.any((v) => v > 0 && v != kSteel)) b[0] = 1;
  return b;
}

BrickLevel generateBrickLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final r = SeededRandom(mixSeed([spec.seed, 13]));
  final d = spec.difficulty;
  const cols = 10;
  final rows = (4 + d ~/ 2).clamp(4, 9);
  return BrickLevel(
    meta: m,
    cols: cols,
    rows: rows,
    bricks: _layout(r, cols, rows, d, spec),
    ballSpeed: 10.5 + d * 0.7 + (spec.has('fast') ? 2 : 0),
    powerups: true,
    movingPaddleShrink: spec.has('shrink'),
  );
}

class Ball {
  double x, y, vx, vy;
  Ball(this.x, this.y, this.vx, this.vy);
}

class Drop {
  double x, y;
  final int kind; // 0 multi, 1 wide, 2 slow, 3 life
  Drop(this.x, this.y, this.kind);
}

class BrickSim extends ArcadeSim {
  final BrickLevel level;
  late List<int> bricks;
  double paddleX = kWorldW / 2;
  double paddleW = 190;
  int wideTicks = 0;
  int slowBallTicks = 0;
  final List<Ball> balls = [];
  final List<Drop> drops = [];
  bool attached = true;
  int broken = 0;
  int powerupsCaught = 0;
  int bombsBlown = 0;
  int stage = 1;
  int _idleHits = 0;
  int lastEvent = 0; // 1 brick, 2 paddle, 3 power

  /// Autopilot memory (not part of the game state).
  int botPlanAt = -100;
  double botOffset = 0;

  BrickSim(this.level) : super(level.meta) {
    bricks = [...level.bricks];
    _attach();
  }

  double get brickW => kWorldW / level.cols;

  /// 'shrink': the paddle gets smaller as the wall is cleared.
  double get baseWidth => level.movingPaddleShrink ? 190 - 60 * progress.clamp(0.0, 1.0) : 190;
  double get speed => level.ballSpeed * (slowBallTicks > 0 ? 0.7 : 1);
  int get remaining => bricks.where((b) => b > 0 && b != kSteel).length;

  Rect2 brickRect(int i) {
    final x = (i % level.cols) * brickW, y = kBrickTop + (i ~/ level.cols) * kBrickH;
    return Rect2(x + 3, y + 3, brickW - 6, kBrickH - 6);
  }

  void _attach() {
    balls
      ..clear()
      ..add(Ball(paddleX, kPaddleY - 20, 0, 0));
    attached = true;
  }

  void _launch() {
    attached = false;
    final b = balls.first;
    final dir = rng.chance(0.5) ? 1 : -1;
    b.vx = dir * speed * 0.45;
    b.vy = -math.sqrt(speed * speed - b.vx * b.vx);
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (wideTicks > 0 && --wideTicks == 0) paddleW = baseWidth;
    if (wideTicks == 0) paddleW = baseWidth;
    if (slowBallTicks > 0) slowBallTicks--;
    final maxStep = 46.0;
    if (input.hasPointer && input.down) {
      paddleX = moveToward(paddleX, input.x, maxStep);
    } else if (input.dirX != 0) {
      paddleX += input.dirX * 20;
    }
    final half = paddleW / 2;
    paddleX = clampD(paddleX, half, kWorldW - half);
    if (attached) {
      balls.first
        ..x = paddleX
        ..y = kPaddleY - 20;
      if (input.tap || input.swipe == 0 || ticks > 60 * 4) _launch();
      return;
    }
    for (final b in [...balls]) {
      for (var s = 0; s < 3; s++) {
        _moveBall(b, 1 / 3);
      }
    }
    balls.removeWhere((b) => b.y > kWorldH + 30);
    if (balls.isEmpty) {
      if (meta.zen) {
        _attach();
      } else {
        hit();
        if (!over) _attach();
      }
    }
    for (final d in [...drops]) {
      d.y += 6;
      if (d.y > kPaddleY - 14 && d.y < kPaddleY + 14 && (d.x - paddleX).abs() < paddleW / 2 + 20) {
        _power(d.kind);
        drops.remove(d);
      } else if (d.y > kWorldH) {
        drops.remove(d);
      }
    }
    if (remaining == 0) {
      if (meta.goal) {
        win();
      } else {
        stage++;
        bricks = _layout(SeededRandom(mixSeed([meta.seed, stage])), level.cols, level.rows,
            meta.difficulty, null);
        score += 500;
        _attach();
      }
    }
  }

  void _power(int k) {
    powerupsCaught++;
    lastEvent = 3;
    score += 25;
    switch (k) {
      case 0:
        if (balls.isNotEmpty && balls.length < 6) {
          final b = balls.first;
          balls.add(Ball(b.x, b.y, -b.vx, b.vy));
          balls.add(Ball(b.x, b.y, b.vx * 0.5, -(b.vy.abs())));
          for (final n in balls) {
            _normalize(n);
          }
        }
      case 1:
        paddleW = 280;
        wideTicks = 60 * 12;
      case 2:
        slowBallTicks = 60 * 8;
        for (final n in balls) {
          _normalize(n);
        }
      default:
        if (!meta.zen) lives = math.min(lives + 1, 5);
    }
  }

  void _normalize(Ball b) {
    final len = math.sqrt(b.vx * b.vx + b.vy * b.vy);
    if (len == 0) return;
    b.vx = b.vx / len * speed;
    b.vy = b.vy / len * speed;
    if (b.vy.abs() < speed * 0.3) {
      b.vy = (b.vy < 0 ? -1 : 1) * speed * 0.3;
      b.vx = (b.vx < 0 ? -1 : 1) * math.sqrt(speed * speed - b.vy * b.vy);
    }
  }

  void _moveBall(Ball b, double f) {
    const r = 14.0;
    b.x += b.vx * f;
    b.y += b.vy * f;
    if (b.x < r) {
      b.x = r;
      b.vx = b.vx.abs();
    } else if (b.x > kWorldW - r) {
      b.x = kWorldW - r;
      b.vx = -b.vx.abs();
    }
    if (b.y < 120 + r) {
      b.y = 120 + r;
      b.vy = b.vy.abs();
    }
    // paddle
    if (b.vy > 0 && b.y + r >= kPaddleY - 12 && b.y < kPaddleY + 10 && (b.x - paddleX).abs() <= paddleW / 2 + r) {
      final off = clampD((b.x - paddleX) / (paddleW / 2), -1, 1);
      b.vx = off * speed * 0.8;
      b.vy = -math.sqrt(speed * speed - b.vx * b.vx);
      b.y = kPaddleY - 12 - r;
      lastEvent = 2;
      _idleHits++;
      if (meta.zen && b.vy == 0) b.vy = -speed;
    }
    if (meta.zen && b.y > kPaddleY + 40) {
      b.vy = -b.vy.abs();
    }
    // bricks (only near rows)
    if (b.y - r > kBrickTop + level.rows * kBrickH || b.y + r < kBrickTop) return;
    for (var i = 0; i < bricks.length; i++) {
      if (bricks[i] == 0) continue;
      final rc = brickRect(i);
      final cx = clampD(b.x, rc.x, rc.x + rc.w), cy = clampD(b.y, rc.y, rc.y + rc.h);
      final dx = b.x - cx, dy = b.y - cy;
      if (dx * dx + dy * dy > r * r) continue;
      // reflect on the axis of least penetration
      final penX = math.min((b.x + r) - rc.x, (rc.x + rc.w) - (b.x - r));
      final penY = math.min((b.y + r) - rc.y, (rc.y + rc.h) - (b.y - r));
      if (penX < penY) {
        b.vx = b.x < rc.x + rc.w / 2 ? -b.vx.abs() : b.vx.abs();
      } else {
        b.vy = b.y < rc.y + rc.h / 2 ? -b.vy.abs() : b.vy.abs();
      }
      _hitBrick(i);
      _idleHits = 0;
      break;
    }
    // Anti-loop: after many paddle hits without bricks, nudge the angle.
    if (_idleHits > 6 && b.vy < 0) {
      b.vx += (rng.nextDouble() - 0.5) * 3;
      _normalize(b);
      _idleHits = 0;
    }
  }

  void _hitBrick(int i) {
    final v = bricks[i];
    lastEvent = 1;
    if (v == kSteel) return;
    if (v == kBomb) {
      bricks[i] = 0;
      bombsBlown++;
      broken++;
      score += 30;
      final cx = i % level.cols, cy = i ~/ level.cols;
      for (var y = cy - 1; y <= cy + 1; y++) {
        for (var x = cx - 1; x <= cx + 1; x++) {
          if (x < 0 || y < 0 || x >= level.cols || y >= level.rows) continue;
          final j = y * level.cols + x;
          if (bricks[j] > 0 && bricks[j] != kSteel && j != i) _hitBrick(j);
        }
      }
      return;
    }
    if (v > 1) {
      bricks[i] = v - 1;
      score += 5;
      return;
    }
    bricks[i] = 0;
    broken++;
    score += 10;
    if (level.powerups && rng.chance(0.12)) {
      final rc = brickRect(i);
      drops.add(Drop(rc.x + rc.w / 2, rc.y + rc.h, rng.weighted([3, 3, 2, 1])));
    }
  }

  @override
  void onLifeLost() {
    drops.clear();
    paddleW = baseWidth;
    wideTicks = 0;
  }

  @override
  double get progress => 1 - remaining / math.max(1, level.breakable);

  @override
  String get goalText => meta.goal ? '${level.breakable - remaining}/${level.breakable}' : 'x$stage';

  @override
  Map<String, int> get stats => {
        'bricks_broken': broken,
        'powerups_caught': powerupsCaught,
        'bombs': bombsBlown,
      };

  @override
  int get stars => lifeStars(this, 3);
}

class Rect2 {
  final double x, y, w, h;
  const Rect2(this.x, this.y, this.w, this.h);
}

/// Predicts where a ball crosses the paddle line (with wall bounces).
double predictLanding(Ball b) {
  if (b.vy <= 0) return b.x;
  final t = (kPaddleY - 26 - b.y) / b.vy;
  var x = b.x + b.vx * t;
  const lo = 14.0, hi = kWorldW - 14;
  final span = hi - lo;
  var u = (x - lo) % (2 * span);
  if (u < 0) u += 2 * span;
  x = u <= span ? lo + u : lo + 2 * span - u;
  return x;
}

/// Score of returning [land] with paddle offset [off] (-1..1).
int _tryRebound(BrickSim g, double land, double off) {
  final t = BrickSim(g.level);
  t.bricks = [...g.bricks];
  final sp = g.speed;
  final vx = off * sp * 0.8;
  t.balls
    ..clear()
    ..add(Ball(land, kPaddleY - 27, vx, -math.sqrt(sp * sp - vx * vx)));
  t.attached = false;
  t.paddleX = -1000;
  final before = t.remaining;
  final hp = t.bricks.fold<int>(0, (a, b) => b == kSteel ? a : a + b);
  for (var i = 0; i < 260; i++) {
    t.update(ArcadeInput.idle);
    if (t.balls.isEmpty) break;
    final b = t.balls.first;
    if (b.vy > 0 && b.y > 1250) break;
  }
  final hpAfter = t.bricks.fold<int>(0, (a, b) => b == kSteel ? a : a + b);
  return (before - t.remaining) * 10 + (hp - hpAfter);
}

ArcadeInput brickBot(ArcadeSim s) {
  final g = s as BrickSim;
  if (g.attached) return ArcadeInput(down: true, tap: g.ticks % 30 == 0, x: g.paddleX, y: kPaddleY);
  Ball? target;
  var best = 1e9;
  for (final b in g.balls) {
    if (b.vy <= 0) continue;
    final t = (kPaddleY - b.y) / b.vy;
    if (t < best) {
      best = t;
      target = b;
    }
  }
  if (target == null) {
    for (final d in g.drops) {
      return ArcadeInput(down: true, x: d.x, y: kPaddleY);
    }
    return ArcadeInput(down: true, x: g.balls.first.x, y: kPaddleY);
  }
  final land = predictLanding(target);
  final contact = g.ticks + best.round();
  if (best < 45 && (contact - g.botPlanAt).abs() > 6) {
    g.botPlanAt = contact;
    var bestV = -1;
    for (final off in const [0.0, -0.3, 0.3, -0.6, 0.6, -0.85, 0.85]) {
      final v = _tryRebound(g, land, off);
      if (v > bestV) {
        bestV = v;
        g.botOffset = off;
      }
    }
  } else if (best >= 45) {
    g.botOffset = 0;
  }
  final px = land - g.botOffset * g.paddleW / 2;
  return ArcadeInput(down: true, x: clampD(px, 0, kWorldW), y: kPaddleY);
}
