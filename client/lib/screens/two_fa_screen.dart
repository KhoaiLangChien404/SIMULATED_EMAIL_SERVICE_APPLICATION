import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';

class TwoFaScreen extends StatefulWidget {
  final String token;
  TwoFaScreen({required this.token});

  @override
  _TwoFaScreenState createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends State<TwoFaScreen> {
  final _codeController = TextEditingController();
  String _error = '';

  Future<void> _verify2Fa() async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/api/verify-2fa'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
      body: jsonEncode({'code': _codeController.text}),
    );
    if (response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(token: widget.token)),
      );
    } else {
      setState(() {
        _error = 'Invalid 2FA code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Two-Step Verification')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Enter the code sent to your phone'),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(labelText: '2FA Code'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _verify2Fa, child: Text('Verify')),
            if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}