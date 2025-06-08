import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _error = '';
  bool _isLoading = false;
  // Replace with your machine's IP if testing on a device/emulator
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1.onrender.com');

  Future<void> _register() async {
    // Input validation
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/register'));
      request.fields['phone'] = _phoneController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['name'] = _nameController.text;

      // Send request with timeout
      final response = await request.send().timeout(Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
      } else {
        setState(() {
          _error = 'Registration failed: $responseBody';
          _isLoading = false;
        });
        print('Registration failed with status: ${response.statusCode}, body: $responseBody');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to connect. Check server and network.';
        _isLoading = false;
      });
      print('Registration exception: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
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
                : ElevatedButton(onPressed: _register, child: Text('Register')),
            if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}