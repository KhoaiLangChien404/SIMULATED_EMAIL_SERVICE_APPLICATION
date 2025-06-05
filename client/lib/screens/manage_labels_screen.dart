import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageLabelsScreen extends StatefulWidget {
  final String token;
  const ManageLabelsScreen({required this.token, super.key});

  @override
  State<ManageLabelsScreen> createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends State<ManageLabelsScreen> {
  List<String> _labels = [];
  String _error = '';
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:3000';
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLabels();
  }

  Future<void> _fetchLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/manage-labels'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _labels = data.cast<String>();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to fetch labels: ${response.body}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error fetching labels: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addLabel() async {
    final newLabel = _labelController.text.trim();
    if (newLabel.isEmpty) {
      setState(() {
        _error = 'Label cannot be empty';
      });
      return;
    }

    // Thêm nhãn bằng cách gán vào một email giả định (hoặc có thể tạo API mới để thêm trực tiếp vào bảng labels)
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/email-labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emailId': -1, // Email giả định để tạo nhãn
          'label': newLabel,
          'value': true,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _labels.add(newLabel);
          _labelController.clear();
          _error = '';
        });
      } else {
        setState(() {
          _error = 'Failed to add label: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error adding label: $e';
      });
    }
  }

  Future<void> _deleteLabel(String label) async {
    try {
      // Xóa nhãn khỏi email-labels trước
      final response = await http.post(
        Uri.parse('$_baseUrl/api/email-labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emailId': -1, // Email giả định
          'label': label,
          'value': false,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _labels.remove(label);
          _error = '';
        });
      } else {
        setState(() {
          _error = 'Failed to delete label: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error deleting label: $e';
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Labels'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _labelController,
                          decoration: const InputDecoration(
                            labelText: 'New Label',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addLabel,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _labels.length,
                      itemBuilder: (context, index) {
                        final label = _labels[index];
                        return ListTile(
                          title: Text(label),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteLabel(label),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}