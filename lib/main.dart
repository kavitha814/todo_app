import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/todo_database.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await TodoDatabase.initialize();
  await NotificationService().initialize();
  await TodoDatabase().rescheduleAllAlarms();

  runApp(const UpTodoApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class UpTodoApp extends StatelessWidget {
  const UpTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'UpTodo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
        fontFamily: 'Lato',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8875FF),
          secondary: Color(0xFF8875FF),
          surface: Color(0xFF1D1D1D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
      ),
      home: SplashScreen(),
    );
  }
}
