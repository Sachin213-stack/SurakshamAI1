import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/sentinel_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // GenZ-style status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFFFFDF2), // Cream
    statusBarIconBrightness: Brightness.dark,
  ));
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => SentinelService(),
      child: const SentinelApp(),
    ),
  );
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFDF2), // Cream
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000), // Black
          secondary: Color(0xFFFF6B6B), // Accent Red
          surface: Color(0xFFE8E6DD), // Light Gray
          background: Color(0xFFFFFDF2), // Cream
        ),
        cardColor: const Color(0xFFFFFDF2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFDF2),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFDF2),
          selectedItemColor: Color(0xFF000000),
          unselectedItemColor: Color(0xFF666666),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        useMaterial3: true,
        fontFamily: 'DM Sans',
      ),
      home: const HomeScreen(),
    );
  }
}
