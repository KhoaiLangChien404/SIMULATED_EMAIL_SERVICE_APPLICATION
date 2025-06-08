import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';

class TwoFaScreen extends StatefulWidget {
  final String token;
  TwoFaScreen({required this.token, super.key});

  @override
  _TwoFaScreenState createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends State<TwoFaScreen> {
  final _codeController = TextEditingController();
  String _error = '';
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1.onrender.com');

  Future<void> _verify2Fa() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-2fa'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: jsonEncode({'code': _codeController.text}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(token: widget.token)),
        );
      } else {
        setState(() {
          _error = 'Invalid 2FA code: ${jsonDecode(response.body)['error'] ?? response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to connect. Check server and network. Details: $e';
      });
      print('2FA verification exception: $e');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Step Verification')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Enter the code sent to your phone'),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: '2FA Code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _verify2Fa, child: const Text('Verify')),
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}