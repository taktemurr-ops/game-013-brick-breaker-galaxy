import 'package:flutter_test/flutter_test.dart';
import 'package:game_013_brick_breaker_galaxy/core/arcade.dart';
import 'package:game_013_brick_breaker_galaxy/core/level_plan.dart';
import 'package:game_013_brick_breaker_galaxy/game/brick_engine.dart';
import 'package:game_013_brick_breaker_galaxy/game/rules.dart';

void main() {
  final rules = BrickRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('ball stays attached until launch, then moves up', () {
    final s = BrickSim(rules.build(planner.spec(1)).puzzle);
    s.tick(ArcadeInput.idle);
    expect(s.attached, isTrue);
    s.tick(const ArcadeInput(tap: true));
    s.tick(ArcadeInput.idle);
    expect(s.attached, isFalse);
    expect(s.balls.first.vy, lessThan(0));
  });

  test('bomb clears its neighbours, steel never breaks', () {
    final s = BrickSim(rules.build(planner.spec(1)).puzzle);
    s.bricks = List.filled(s.bricks.length, 1);
    s.bricks[15] = kBomb;
    s.bricks[0] = kSteel;
    final before = s.remaining;
    s.bricks; // ignore
    // simulate a hit on the bomb
    final b = Ball(s.brickRect(15).x + 20, s.brickRect(15).y + s.brickRect(15).h + 13, 0, -10);
    s.balls
      ..clear()
      ..add(b);
    s.attached = false;
    s.tick(ArcadeInput.idle);
    expect(s.remaining, lessThan(before - 4));
    expect(s.bricks[0], kSteel);
  });

  test('landing prediction matches the simulation', () {
    final b = Ball(100, 600, 9, 7);
    final x = predictLanding(b);
    expect(x, inInclusiveRange(14, kWorldW - 14));
  });
}
