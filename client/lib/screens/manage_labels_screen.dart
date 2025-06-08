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
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1.onrender.com');
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _editLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLabels();
  }

  Future<void> _fetchLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/labels'),
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

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'label': newLabel,
          'value': true,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _labels.add(data['label'] ?? newLabel); // Sử dụng label từ response hoặc newLabel nếu không có
            _labelController.clear();
            _error = '';
          });
        } else {
          setState(() {
            _error = 'Failed to add label: ${data['error'] ?? response.body}';
          });
        }
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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
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

  Future<void> _editLabel(String oldLabel) async {
    _editLabelController.text = oldLabel;
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: _editLabelController,
          decoration: const InputDecoration(
            labelText: 'New Label Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _editLabelController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel == null || newLabel.isEmpty || newLabel == oldLabel) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'oldLabel': oldLabel,
          'newLabel': newLabel,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            final index = _labels.indexOf(oldLabel);
            _labels[index] = data['newLabel'] ?? newLabel;
            _error = '';
          });
        } else {
          setState(() {
            _error = 'Failed to edit label: ${data['error'] ?? response.body}';
          });
        }
      } else {
        setState(() {
          _error = 'Failed to edit label: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error editing label: $e';
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _editLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Labels'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editLabel(label),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteLabel(label),
                              ),
                            ],
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