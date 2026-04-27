import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/sentinel_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Instagram-style status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF77737), // Instagram orange gradient
          secondary: Color(0xFFE1306C), // Instagram pink
          surface: Color(0xFF121212),
          background: Colors.black,
        ),
        cardColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFF8E8E8E),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
