import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManageLabelsScreen extends StatefulWidget {
  final String token;
  const ManageLabelsScreen({required this.token, super.key});

  @override
  _ManageLabelsScreenState createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends State<ManageLabelsScreen> {
  List<String> _labels = [];
  String _newLabel = '';
  String _error = '';
  bool _isLoading = true;

  final String _baseUrl = 'http://localhost:3000';
  late TextEditingController _newLabelController; // Khai báo controller

  @override
  void initState() {
    super.initState();
    _newLabelController = TextEditingController(); // Khởi tạo controller
    _fetchLabels();
  }

  @override
  void dispose() {
    _newLabelController.dispose(); // Dispose controller
    super.dispose();
  }

  Future<void> _fetchLabels() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      print('Labels response: ${response.statusCode}, ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _labels = data.cast<String>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Không thể tải danh sách nhãn: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi khi tải nhãn: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addLabel() async {
    if (_newLabel.isEmpty) {
      setState(() => _error = 'Tên nhãn không được để trống');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/labels/add'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'label': _newLabel}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) {
        setState(() {
          _labels.add(_newLabel);
          _newLabel = '';
          _newLabelController.clear(); // Xóa nội dung TextField
          _error = '';
        });
      } else {
        setState(() => _error = 'Không thể thêm nhãn: ${response.body}');
      }
    } catch (e) {
      setState(() => _error = 'Lỗi khi thêm nhãn: $e');
    }
  }

  Future<void> _removeLabel(String label) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/labels/remove'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'label': label}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _labels.remove(label);
          _error = '';
        });
      } else {
        setState(() => _error = 'Không thể xóa nhãn: ${response.body}');
      }
    } catch (e) {
      setState(() => _error = 'Lỗi khi xóa nhãn: $e');
    }
  }

  Future<void> _renameLabel(String oldLabel, String newLabel) async {
    if (newLabel.isEmpty) {
      setState(() => _error = 'Tên nhãn mới không được để trống');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/labels/rename'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'oldLabel': oldLabel, 'newLabel': newLabel}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          final index = _labels.indexOf(oldLabel);
          if (index != -1) {
            _labels[index] = newLabel;
          }
          _error = '';
        });
      } else {
        setState(() => _error = 'Không thể đổi tên nhãn: ${response.body}');
      }
    } catch (e) {
      setState(() => _error = 'Lỗi khi đổi tên nhãn: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Đặt hướng văn bản mặc định cho toàn màn hình
      child: Scaffold(
        appBar: AppBar(title: const Text('Quản lý nhãn')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newLabelController, // Sử dụng controller
                            onChanged: (value) => setState(() => _newLabel = value),
                            decoration: const InputDecoration(labelText: 'Nhãn mới'),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addLabel,
                        ),
                      ],
                    ),
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
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeLabel(label),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final newLabel = await showDialog<String>(
                                      context: context,
                                      builder: (context) {
                                        final controller = TextEditingController();
                                        return Directionality(
                                          textDirection: TextDirection.ltr, // Đặt LTR cho dialog
                                          child: AlertDialog(
                                            title: const Text('Đổi tên nhãn'),
                                            content: TextField(
                                              controller: controller,
                                              decoration: const InputDecoration(labelText: 'Tên mới'),
                                              textDirection: TextDirection.ltr,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Hủy'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, controller.text),
                                                child: const Text('Lưu'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                    if (newLabel != null && newLabel.isNotEmpty) {
                                      _renameLabel(label, newLabel);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
      ),
    );
  }
}