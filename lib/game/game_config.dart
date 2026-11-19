import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/arcade.dart';
import '../core/game_rules.dart';
import 'brick_engine.dart';
import 'rules.dart';

void paintBricks(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as BrickSim;
  c.drawRect(const Rect.fromLTWH(0, 112, kWorldW, 6), Paint()..color = Colors.white24);
  for (var i = 0; i < s.bricks.length; i++) {
    final v = s.bricks[i];
    if (v == 0) continue;
    final r = s.brickRect(i);
    final rect = Rect.fromLTWH(r.x, r.y, r.w, r.h);
    Color col;
    if (v == kSteel) {
      col = const Color(0xFF8D99AE);
    } else if (v == kBomb) {
      col = const Color(0xFFE63946);
    } else {
      col = p.piece((i ~/ s.level.cols) % 7);
      if (v > 1) col = Color.lerp(col, Colors.black, 0.25 * (v - 1))!;
    }
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = col);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.x + 4, r.y + 4, r.w - 8, 8), const Radius.circular(4)),
        Paint()..color = Colors.white24);
    if (v == kBomb) paintText(c, '✸', rect.center, 28, Colors.white);
    if (v == kSteel) paintText(c, '▦', rect.center, 24, Colors.white70);
    if (v > 1 && v < kSteel) paintText(c, '$v', rect.center, 24, Colors.white);
    if (p.colorBlind && v < kSteel) paintText(c, ['●', '■', '▲', '◆', '★', '✚', '♥'][(i ~/ s.level.cols) % 7], rect.center.translate(r.w * 0.3, 0), 18, Colors.white70);
  }
  for (final d in s.drops) {
    const icons = ['⁂', '↔', '◷', '♥'];
    const cols = [Color(0xFF00BBF9), Color(0xFF9B5DE5), Color(0xFFFEE440), Color(0xFFFF595E)];
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(d.x, d.y), width: 64, height: 36), const Radius.circular(18)),
        Paint()..color = cols[d.kind]);
    paintText(c, icons[d.kind], Offset(d.x, d.y), 26, Colors.black87);
  }
  final pr = Rect.fromCenter(center: Offset(s.paddleX, kPaddleY), width: s.paddleW, height: 24);
  c.drawRRect(RRect.fromRectAndRadius(pr, const Radius.circular(12)), Paint()..color = p.piece(0));
  c.drawRRect(RRect.fromRectAndRadius(pr.deflate(5), const Radius.circular(8)), Paint()..color = Colors.white30);
  for (final b in s.balls) {
    c.drawCircle(Offset(b.x, b.y), 16, Paint()..color = Colors.white);
    c.drawCircle(Offset(b.x - 4, b.y - 4), 5, Paint()..color = Colors.white70);
  }
  if (s.attached && !p.reducedMotion) {
    final b = s.balls.first;
    for (var k = 1; k <= 4; k++) {
      c.drawCircle(Offset(b.x, b.y - k * 36), 4, Paint()..color = Colors.white.withValues(alpha: 0.5 - k * 0.1));
    }
  }
}

Sfx? brickSound(ArcadeSim sim) => switch ((sim as BrickSim).lastEvent) {
      1 => Sfx.clear,
      2 => Sfx.tap,
      3 => Sfx.coin,
      _ => null,
    };

final gameConfig = GameConfig(
  gameId: 'game-013-brick-breaker-galaxy',
  title: const ['Tuğla Kırıcı Galaksi', 'Brick Breaker Galaxy', 'Ziegelbrecher Galaxie', 'Rompeladrillos Galaxia', 'Casse-Briques Galaxie'],
  tagline: const ['Galaksideki bütün tuğlaları kır!', 'Smash every brick across the galaxy!', 'Zerschlage jeden Ziegel!', '¡Rompe todos los ladrillos!', 'Cassez toutes les briques !'],
  seedColor: const Color(0xFFFCA311),
  icon: Icons.grid_view,
  rules: BrickRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => BrickSim((ctx.generated as GeneratedLevel<BrickLevel>).puzzle),
    paint: paintBricks,
    sound: brickSound,
    howTo: const [
      'Raketi sürükle, topu fırlatmak için dokun.',
      'Drag the paddle, tap to launch the ball.',
      'Schläger ziehen, tippen zum Abschießen.',
      'Arrastra la pala, toca para lanzar.',
      'Glissez la raquette, touchez pour lancer.',
    ],
  ),
  tutorial: const [
    TutorialStep(Icons.swipe, [
      'Raketi parmağınla sürükle (klavye: ←/→). Topun açısı raketin neresine çarptığına bağlı.',
      'Drag the paddle (keys ←/→). The bounce angle depends on where the ball hits.',
      'Schläger ziehen (←/→). Der Winkel hängt vom Treffpunkt ab.',
      'Arrastra la pala (←/→). El ángulo depende del punto de impacto.',
      'Glissez la raquette (←/→). L\'angle dépend du point d\'impact.',
    ]),
    TutorialStep(Icons.grid_view, [
      'Zırhlı tuğlalar birkaç vuruş ister, çelik kırılmaz, bomba çevresini patlatır.',
      'Armored bricks need several hits, steel never breaks, bombs blast neighbours.',
      'Panzerziegel brauchen mehrere Treffer, Stahl bricht nie, Bomben sprengen Nachbarn.',
      'Los blindados necesitan varios golpes, el acero no se rompe.',
      'Les briques blindées demandent plusieurs coups, l\'acier ne casse pas.',
    ]),
    TutorialStep(Icons.auto_awesome, [
      'Düşen güçlendirmeleri yakala: çoklu top, geniş raket, yavaş top, can.',
      'Catch power-ups: multi-ball, wide paddle, slow ball, extra life.',
      'Fange Power-ups: Multiball, breiter Schläger, langsamer Ball, Leben.',
      'Atrapa potenciadores: multibola, pala ancha, bola lenta, vida.',
      'Attrapez les bonus : multi-balle, raquette large, balle lente, vie.',
    ]),
  ],
);
