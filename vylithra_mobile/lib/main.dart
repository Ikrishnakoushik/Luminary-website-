import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vylithra',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Automatically matches device theme
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Light slate
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF3B82F6), // Vibrant blue
          secondary: Color(0xFF8B5CF6), // Purple
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A), // Dark text
        ),
        fontFamily: 'Roboto', // Modern system font fallback
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep slate/navy
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6), // Vibrant blue
          secondary: Color(0xFF8B5CF6), // Purple
          surface: Color(0xFF1E293B), // Card background
          onSurface: Color(0xFFF8FAFC), // Light text
        ),
        fontFamily: 'Roboto',
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
