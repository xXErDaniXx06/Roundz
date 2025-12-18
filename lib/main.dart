import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'features/auth/login_page.dart';
import 'features/layout/main_layout.dart';

import 'package:provider/provider.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Roundz',
          themeMode: themeService.themeMode,
          theme: ThemeData(
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Colors.black,
              onPrimary: Colors.white,
              secondary: Colors.grey,
              onSecondary: Colors.black,
              error: Colors.red,
              onError: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
              surfaceContainerHighest:
                  Color(0xFFF5F5F5), // Light grey for containers
            ),
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(themeService.textScaleFactor),
              ),
              child: child!,
            );
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasData) {
                return const MainLayout();
              } else {
                return const LoginPage();
              }
            },
          ),
        );
      },
    );
  }
}
