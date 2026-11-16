import 'package:flutter_test/flutter_test.dart';
import 'package:game_013_brick_breaker_galaxy/main.dart';

void main() {
  test('game starts with bricks and three lives', () {
    final game = BrickBreakerGame();
    expect(game.bricks.where((b) => b).length, 40);
    expect(game.lives, 3);
    expect(game.score, 0);
  });

  test('paddle clamps to play area', () {
    final game = BrickBreakerGame();
    game.movePaddle(-1);
    expect(game.paddle, 0.12);
    game.movePaddle(2);
    expect(game.paddle, 0.88);
  });

  test('ball does not move before launch', () {
    final game = BrickBreakerGame();
    final oldY = game.ballY;
    game.tick();
    expect(game.ballY, oldY);
    game.launch();
    game.tick();
    expect(game.ballY, lessThan(oldY));
  });

  testWidgets('renders controls and score', (tester) async {
    await tester.pumpWidget(const BrickBreakerApp());
    expect(find.text('Launch / Step'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.textContaining('Lives 3'), findsOneWidget);
  });
}
