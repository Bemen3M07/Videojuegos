import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = SpaceShooterGame();

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(                 //GameWitget Es la clase que se encarga de mostrar el juego dentro de la interfaz de Flutter
              game: game,
              overlayBuilderMap: {
                'gameOver': (context, game) => GameOverOverlay(game: game as SpaceShooterGame),
              },
            ),
            Align(
              alignment: Alignment.topRight,
              child: PauseButton(game: game),
            ),
          ],
        ),
      ),
    );
  }
}

class SpaceShooterGame extends FlameGame with PanDetector, HasCollisionDetection {
  late Player player;
  bool isPaused = false;
  bool isGameOver = false;

  @override
  Color backgroundColor() => Colors.blue;

  @override
  Future<void> onLoad() async {
    final parallax = await loadParallaxComponent(
      [ParallaxImageData('stars.png')],
      baseVelocity: Vector2(0, -5),
      repeat: ImageRepeat.repeat,
      velocityMultiplierDelta: Vector2(0, 5),
    );
    add(parallax);

    player = Player();
    add(player);

    add(
      SpawnComponent(
        factory: (index) => Enemy(),
        period: 1,
        area: Rectangle.fromLTWH(0, 0, size.x, -Enemy.enemySize),
      ),
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (!isPaused && !isGameOver) {
      player.move(info.delta.global);
    }
  }

  @override
  void onPanStart(DragStartInfo info) {
    if (!isPaused && !isGameOver) {
      player.startShooting();
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (!isPaused && !isGameOver) {
      player.stopShooting();
    }
  }

  void pauseGame() {
    isPaused = true;
    pauseEngine();
  }

  void resumeGame() {
    isPaused = false;
    resumeEngine();
  }

  void endGame() {
    isGameOver = true;
    pauseEngine();
    overlays.add('gameOver');
  }

  void restart() {
    isPaused = false;
    isGameOver = false;
    children.clear(); // Elimina todos los componentes
    overlays.remove('gameOver');
    resumeEngine();
    onLoad(); // Reinicia el juego desde cero
  }
}

class Player extends SpriteComponent with HasGameReference<SpaceShooterGame>, CollisionCallbacks {
  Player()
      : super(
          size: Vector2(100, 150),            //Size: define el ancho y la altura de un componente
          anchor: Anchor.center,
        );

  late final SpawnComponent _bulletSpawner;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('player.png');
    add(RectangleHitbox(size: Vector2(60, 90)));

    _bulletSpawner = SpawnComponent(
      period: 0.2,
      selfPositioning: true,
      factory: (index) {
        return Bullet(position: position + Vector2(0, -height / 2));
      },
      autoStart: false,
    );

    game.add(_bulletSpawner);
  }

  @override
  void onMount() {
    super.onMount();
    position = game.size / 2;           //Position: indica la posicion en coordenadas (x,y) del componente de la pantalla 
  }

  void move(Vector2 delta) {
    position.add(delta);
  }

  void startShooting() {
    _bulletSpawner.timer.start();
  }

  void stopShooting() {
    _bulletSpawner.timer.stop();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Enemy && !game.isGameOver) {
      removeFromParent();
      game.endGame();
    }
  }
}

class PauseButton extends StatefulWidget {
  final SpaceShooterGame game;

  const PauseButton({super.key, required this.game});

  @override
  State<PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<PauseButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.game.isGameOver) return const SizedBox.shrink();

    return FloatingActionButton(
      onPressed: () {
        setState(() {
          if (widget.game.isPaused) {
            widget.game.resumeGame();
          } else {
            widget.game.pauseGame();
          }
        });
      },
      child: Icon(widget.game.isPaused ? Icons.play_arrow : Icons.pause),
    );
  }
}

class Bullet extends SpriteComponent with HasGameReference<SpaceShooterGame> {
  Bullet({super.position})
      : super(
          size: Vector2(25, 50),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {                         //Game Loop  onLoad
    await super.onLoad();     
    sprite = await Sprite.load('bullet_2.png'); 
    add(RectangleHitbox(
      collisionType: CollisionType.passive,
      size: size,
    ));                                                  
  }
                                                        // Render : metodo que se encargar de dibujar el juego en la pantalla frame por frame
  @override
  void update(double dt) {                              //Game Loop update(dt)      => se llama en cada frame con el tiempo transcurrido (dt).
    super.update(dt);
    position.y += dt * -500;
    if (position.y < -height) {
      removeFromParent();
    }
  }
}

class Enemy extends SpriteComponent with HasGameReference<SpaceShooterGame>, CollisionCallbacks {
  Enemy({super.position})
      : super(
          size: Vector2.all(enemySize),
          anchor: Anchor.center,
        );

  static const enemySize = 50.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('enemy.jpg');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += dt * 250;
    if (position.y > game.size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Bullet) {
      removeFromParent();
      other.removeFromParent();
      game.add(Explosion(position: position));
    }
  }
}

class Explosion extends SpriteAnimationComponent with HasGameReference<SpaceShooterGame> {
  Explosion({super.position})
      : super(
          size: Vector2.all(150),
          anchor: Anchor.center,
          removeOnFinish: true,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    animation = await game.loadSpriteAnimation(
      'explosion.png',
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.1,
        textureSize: Vector2.all(32),
        loop: false,
      ),
    );
  }
}

// Overlay de Game Over con botón de Reiniciar
class GameOverOverlay extends StatelessWidget {
  final SpaceShooterGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Game Over',
            style: TextStyle(
              fontSize: 48,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              game.restart();
            },
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }
}
