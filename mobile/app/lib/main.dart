import 'package:flutter/material.dart';
import 'package:marcia_mobile/screens/barcode_screen.dart';
import 'package:marcia_mobile/screens/home_screen.dart';
import 'package:marcia_mobile/screens/ocr_screen.dart';
import 'package:marcia_mobile/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MarciaMobileApp());
}

class MarciaMobileApp extends StatelessWidget {
  const MarciaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF005B96),
        primary: const Color(0xFF005B96),
        secondary: const Color(0xFFF4A259),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F6FA),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Marcia tra i ciliegi',
      theme: theme,
      routes: {
        HomeScreen.routeName: (context) => const HomeScreen(),
        BarcodeScreen.routeName: (context) => const BarcodeScreen(),
        OcrScreen.routeName: (context) => const OcrScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
      },
      initialRoute: HomeScreen.routeName,
    );
  }
}
