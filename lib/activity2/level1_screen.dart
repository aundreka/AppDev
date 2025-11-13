import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'maps/level1_map.dart';

class Level1Screen extends StatelessWidget {
  const Level1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Level1Map();
    return Scaffold(
      body: GameWidget(game: game),
    );
  }
}

