import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'providers/system_provider.dart';
import 'screens/welcome_screen.dart';

void main() {
  tz.initializeTimeZones();
  runApp(const SwitchBoardApp());
}

class SwitchBoardApp extends StatelessWidget {
  const SwitchBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SystemProvider()..init(),
      child: Consumer<SystemProvider>(
        builder: (context, provider, _) => MaterialApp(
          title: 'SwitchBoard',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF64748B),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: const Color(0xFF64748B),
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: provider.flutterThemeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(provider.textScale)),
              child: child!,
            );
          },
          home: const WelcomeScreen(),
        ),
      ),
    );
  }
}