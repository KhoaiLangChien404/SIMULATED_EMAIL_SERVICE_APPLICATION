import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const EmailApp(),
    ),
  );
}

class EmailApp extends StatelessWidget {
  const EmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Email Service',
          theme: themeProvider.themeData,
          home: CheckLogin(),
        );
      },
    );
  }
}

class CheckLogin extends StatefulWidget {
  const CheckLogin({super.key});

  @override
  State<CheckLogin> createState() => _CheckLoginState();
}

class _CheckLoginState extends State<CheckLogin> {
  bool _isLoggedIn = false;
  String? _token;
  bool _isLoading = true;
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1.onrender.com');

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    debugPrint('Checking login status...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      debugPrint('Token: $token');

      if (token != null) {
        try {
          debugPrint('Sending request to $_baseUrl/api/profile');
          final response = await http.get(
            Uri.parse('$_baseUrl/api/profile'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 10));

          debugPrint('Response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
            themeProvider.setDarkMode(data['isDarkMode'] ?? false);

            setState(() {
              _isLoggedIn = true;
              _token = token;
              _isLoading = false;
            });
          } else {
            await prefs.remove('token');
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
          }
        } catch (e) {
          debugPrint('Network error: $e');
          await prefs.remove('token');
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('No token found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isLoggedIn ? HomeScreen(token: _token!) : LoginScreen();
  }
}