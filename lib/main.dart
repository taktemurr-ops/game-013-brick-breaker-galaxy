import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const BrickBreakerApp());

class BrickBreakerGame {
  BrickBreakerGame({this.columns = 8, this.rows = 5})
      : bricks = List.generate(rows * columns, (_) => true);

  final int columns;
  final int rows;
  final List<bool> bricks;
  double paddle = 0.5;
  double ballX = 0.5;
  double ballY = 0.78;
  double velocityX = 0.018;
  double velocityY = -0.025;
  int score = 0;
  int lives = 3;
  bool launched = false;
  bool won = false;

  bool get gameOver => lives <= 0 || won;

  void movePaddle(double position) {
    paddle = position.clamp(0.12, 0.88);
    if (!launched && !gameOver) ballX = paddle;
  }

  void launch() {
    if (!gameOver) launched = true;
  }

  void tick() {
    if (!launched || gameOver) return;
    var nextX = ballX + velocityX;
    var nextY = ballY + velocityY;
    if (nextX < 0 || nextX > 1) {
      velocityX = -velocityX;
      nextX = (ballX + velocityX).clamp(0.0, 1.0);
    }
    if (nextY < 0) {
      velocityY = velocityY.abs();
      nextY = ballY + velocityY;
    }
    if (velocityY > 0 && nextY >= 0.9 && nextY <= 0.96 &&
        (nextX - paddle).abs() <= 0.14) {
      velocityY = -velocityY.abs();
      velocityX = (nextX - paddle) * 0.16;
      nextY = ballY + velocityY;
    }
    if (nextY > 1) {
      lives--;
      launched = false;
      ballX = paddle;
      ballY = 0.78;
      velocityX = 0.018;
      velocityY = -0.025;
      return;
    }
    if (nextY >= 0.05 && nextY < 0.05 + rows * 0.065) {
      final col = (nextX * columns).floor().clamp(0, columns - 1);
      final row = ((nextY - 0.05) / 0.065).floor().clamp(0, rows - 1);
      final index = row * columns + col;
      if (bricks[index]) {
        bricks[index] = false;
        score += 10;
        velocityY = -velocityY;
        nextY = ballY + velocityY;
        won = bricks.every((brick) => !brick);
      }
    }
    ballX = nextX;
    ballY = nextY;
  }
}

class BrickBreakerApp extends StatelessWidget {
  const BrickBreakerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Brick Breaker Galaxy',
        theme: ThemeData.dark(useMaterial3: true),
        home: const BrickBreakerScreen(),
      );
}

class BrickBreakerScreen extends StatefulWidget {
  const BrickBreakerScreen({super.key});

  @override
  State<BrickBreakerScreen> createState() => _BrickBreakerScreenState();
}

class _BrickBreakerScreenState extends State<BrickBreakerScreen> {
  BrickBreakerGame game = BrickBreakerGame();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Brick Breaker Galaxy')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('Score ${game.score}  •  Lives ${game.lives}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(builder: (context, bounds) {
                      final width = bounds.maxWidth;
                      final height = bounds.maxHeight;
                      return GestureDetector(
                        onHorizontalDragUpdate: (details) => setState(() {
                          game.movePaddle(details.localPosition.dx / width);
                        }),
                        onTapDown: (details) => setState(() {
                          game.movePaddle(details.localPosition.dx / width);
                        }),
                        child: Stack(children: [
                          const Positioned.fill(child: ColoredBox(color: Color(0xFF101B35))),
                          for (var i = 0; i < game.bricks.length; i++)
                            if (game.bricks[i])
                              Positioned(
                                left: (i % game.columns) * width / game.columns + 2,
                                top: (0.05 + (i ~/ game.columns) * 0.065) * height,
                                width: width / game.columns - 4,
                                height: 0.055 * height,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.primaries[i % Colors.primaries.length],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                          Positioned(
                            left: game.ballX * width - 7,
                            top: game.ballY * height - 7,
                            child: const Icon(Icons.circle, size: 14, color: Colors.white),
                          ),
                          Positioned(
                            left: game.paddle * width - width * 0.13,
                            top: height * 0.93,
                            width: width * 0.26,
                            height: 12,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent,
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                            ),
                          ),
                        ]),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (game.gameOver)
                    Text(game.won ? 'You cleared all bricks!' : 'Game over'),
                  Slider(
                    value: game.paddle,
                    min: 0.12,
                    max: 0.88,
                    label: 'Paddle position',
                    onChanged: game.gameOver ? null : (value) => setState(() {
                      game.movePaddle(value);
                    }),
                  ),
                  Wrap(spacing: 12, children: [
                    FilledButton(
                      onPressed: game.gameOver ? null : () => setState(() {
                        game.launch();
                        game.tick();
                      }),
                      child: const Text('Launch / Step'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => game = BrickBreakerGame()),
                      child: const Text('Restart'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
