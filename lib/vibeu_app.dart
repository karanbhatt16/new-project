import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'auth/local_auth_controller.dart';

class VibeUApp extends StatefulWidget {
  const VibeUApp({super.key});

  @override
  State<VibeUApp> createState() => _VibeUAppState();
}

class _VibeUAppState extends State<VibeUApp> {
  final _auth = LocalAuthController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED));

    return MaterialApp(
      title: 'vibeU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
      ),
      home: AuthGate(controller: _auth),
    );
  }
}
