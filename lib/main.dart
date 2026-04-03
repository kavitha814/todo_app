import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/todo_database.dart';
import 'services/notification_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await TodoDatabase.initialize();
  await NotificationService().initialize();
  await TodoDatabase().rescheduleAllAlarms();

  runApp(const UpTodoApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> globalTabNotifier = ValueNotifier<int>(0);

class UpTodoApp extends StatelessWidget {
  const UpTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'UpTodo',

      debugShowCheckedModeBanner: false,

      // Localizations needed for Cupertino widgets
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), // English
      ],

      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
        fontFamily: 'Lato',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8875FF),
          secondary: Color(0xFF8875FF),
          surface: Color(0xFFF5F5F5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
        ),
      ),
      home: SplashScreen(),
    );
  }
}
