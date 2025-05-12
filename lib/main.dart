import 'package:flutter/material.dart';
import 'screens/inbox_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(EmailApp());
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
      home: InboxScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}