import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/password_management_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/email_detail_screen.dart';
import 'theme/app_theme.dart';
import 'models/email.dart'; // Added import for Email class

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EmailApp());
}

class EmailApp extends StatelessWidget {
  const EmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Simulator',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/inbox': (context) => const InboxScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/password-management': (context) => const PasswordManagementScreen(),
        '/compose': (context) => const ComposeScreen(),
        '/email-detail': (context) => EmailDetailScreen(
              email: ModalRoute.of(context)!.settings.arguments as Email,
            ),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}