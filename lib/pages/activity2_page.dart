
import 'package:flutter/material.dart';
import '../activity2/home_screen.dart';

class Activity2Page extends StatefulWidget {
  const Activity2Page({super.key});

  @override
  State<Activity2Page> createState() => _Activity2PageState();
}

class _Activity2PageState extends State<Activity2Page> {
  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
