import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PasswordRecoveryScreen extends StatefulWidget {
  @override
  _PasswordRecoveryScreenState createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String _error = '';
  String _message = '';
  bool _isLoading = false;
  // Replace with your machine's IP if testing on a device/emulator
  final String _baseUrl = 'http://localhost:3000';

  Future<void> _recoverPassword() async {
    if (_phoneController.text.isEmpty || _newPasswordController.text.isEmpty) {
      setState(() {
        _error = 'Please enter phone number and new password';
        _message = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _message = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/recover-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'newPassword': _newPasswordController.text,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _message = 'Password reset successful! Please login.';
          _error = '';
          _isLoading = false;
        });
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      } else {
        setState(() {
          _error = 'Recovery failed: ${jsonDecode(response.body)['error'] ?? response.body}';
          _message = '';
          _isLoading = false;
        });
        print('Password recovery failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to connect. Check server and network.';
        _message = '';
        _isLoading = false;
      });
      print('Password recovery exception: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Password Recovery')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Enter your phone number and new password'),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _recoverPassword, child: Text('Reset Password')),
            if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
            if (_message.isNotEmpty) Text(_message, style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}