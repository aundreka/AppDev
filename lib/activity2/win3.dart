// lib/activity2/win.dart
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart'; // this has kHighScoreKey

class WinScreen extends StatefulWidget {
  final int highScore;

  const WinScreen({super.key, required this.highScore});

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> {
  @override
  void initState() {
    super.initState();
    _startWinBgm();
    _persistHighScore();
  }

  Future<void> _startWinBgm() async {
    await FlameAudio.bgm.stop();
    await FlameAudio.bgm.play('win.mp3');
  }

  Future<void> _persistHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final currentBest = prefs.getInt(kHighScoreKey) ?? 0;

    if (widget.highScore > currentBest) {
      await prefs.setInt(kHighScoreKey, widget.highScore);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'YOU WIN!',
                style: TextStyle(
                  color: Color(0xFFFACC15),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'High Score: ${widget.highScore}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You have defeated the giant that was terrorizing your town!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 32),

             

              // BACK HOME
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                  );
                },
                child: const Text(
                  'BACK TO HOME',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
