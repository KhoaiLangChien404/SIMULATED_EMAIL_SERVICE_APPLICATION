import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // file sinh ra từ flutterfire configure
import 'screens/inbox_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dành cho mọi nền tảng (Web cần FirebaseOptions)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EmailApp());
}

class EmailApp extends StatelessWidget {
  const EmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gmail Clone',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const InboxScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
