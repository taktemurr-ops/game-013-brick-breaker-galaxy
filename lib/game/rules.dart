import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'brick_engine.dart';

class BrickRules extends ArcadeRules<BrickLevel> {
  @override
  String get gameId => 'game-013-brick-breaker-galaxy';

  @override
  List<String> get optionalMechanics => const ['armor', 'steel', 'bombs', 'fast', 'shrink'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('bricks_broken', 'Kırılan tuğla', 'Bricks broken', scale: 200),
        GameStat('powerups_caught', 'Güçlendirme', 'Power-ups', scale: 10),
        GameStat('bombs', 'Patlayan bomba', 'Bombs blown', scale: 10),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('bricks_broken', 'bricks_broken', [66, 133, 200]),
        MissionTemplate('powerups_caught', 'powerups_caught', [3, 6, 10]),
      ];

  @override
  BrickLevel generate(LevelSpec spec) => generateBrickLevel(spec);

  @override
  ArcadeMeta metaOf(BrickLevel l) => l.meta;

  @override
  ArcadeSim createSim(BrickLevel l) => BrickSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => brickBot(sim);
}

ArcadeRules createRules() => BrickRules();
