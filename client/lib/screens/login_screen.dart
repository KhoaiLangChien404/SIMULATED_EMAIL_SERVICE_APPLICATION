import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'two_fa_screen.dart';
import 'home_screen.dart';
import 'password_recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _twoFaEnabled = false;
  String _error = '';
  bool _isLoading = false;
  final String _baseUrl = 'http://localhost:3000';

  Future<void> _login() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Please enter phone number and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'password': _passwordController.text,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        setState(() {
          _twoFaEnabled = (data['twoFaEnabled'] == 1 || data['twoFaEnabled'] == true) ? true : false;
          _isLoading = false;
        });
        if (_twoFaEnabled) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TwoFaScreen(token: data['token'])),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(token: data['token'])),
          );
        }
      } else {
        setState(() {
          _error = 'Login failed: ${response.body}';
          _isLoading = false;
        });
        print('Login failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to connect. Check server and network.';
        _isLoading = false;
      });
      print('Login exception: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Ngăn người dùng quay lại
      child: Scaffold(
        appBar: AppBar(
          title: Text('Login'),
          automaticallyImplyLeading: false, // Ẩn nút quay lại
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 16),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(onPressed: _login, child: Text('Login')),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen())),
                child: Text('Register'),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PasswordRecoveryScreen())),
                child: Text('Forgot Password?'),
              ),
              if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}