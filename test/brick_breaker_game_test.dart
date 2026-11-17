import 'package:flutter_test/flutter_test.dart';
import 'package:game_013_brick_breaker_galaxy/main.dart';

void main() {
  test('launch starts simulation and moves ball', () {
    final game = BrickBreakerGame();
    final initialY = game.ballY;
    game.launch();
    game.tick();
    expect(game.ballY, isNot(initialY));
  });

  test('paddle movement is clamped to playable bounds', () {
    final game = BrickBreakerGame();
    game.movePaddle(-2);
    expect(game.paddle, 0.12);
    game.movePaddle(4);
    expect(game.paddle, 0.88);
  });

  test('losing the final life stops play', () {
    final game = BrickBreakerGame();
    game.lives = 1;
    game.ballY = 0.99;
    game.velocityY = 0.05;
    game.launch();
    game.tick();
    expect(game.lives, 0);
    expect(game.gameOver, isTrue);
    expect(game.launched, isFalse);
  });

  test('clearing the last brick wins the game', () {
    final game = BrickBreakerGame(columns: 1, rows: 1);
    game.ballX = 0.5;
    game.ballY = 0.1;
    game.velocityX = 0;
    game.velocityY = 0.01;
    game.launch();
    game.tick();
    expect(game.won, isTrue);
    expect(game.score, 10);
  });
}
