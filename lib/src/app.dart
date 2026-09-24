import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

class LumiFxApp extends StatelessWidget {
  const LumiFxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumiFX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7CFF6B),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
