import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

// import via package path and only expose what you need
import 'package:itonatalaga/pages/home_page.dart' show HomePage;

import 'package:itonatalaga/pages/activity1_page.dart' as a1;
import 'package:itonatalaga/pages/activity2_page.dart' as a2;
import 'package:itonatalaga/pages/activity3_page.dart' as a3;
import 'package:itonatalaga/pages/activity4_page.dart' as a4;

void main() async {
  // 👇 This must be first
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder =
      (FlutterErrorDetails details) => const SizedBox.shrink();

  // Now it's safe to use FlameAudio
  await FlameAudio.bgm.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOME',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFF2A2A),
      ),
      home: const HomePage(),
      routes: {
        '/a1': (_) => const a1.Activity1Page(),
        '/a2': (_) => const a2.Activity2Page(),
        '/a3': (_) => const a3.Activity3Page(),
        '/a4': (_) => const a4.Activity4Page(),
      },
    );
  }
}
