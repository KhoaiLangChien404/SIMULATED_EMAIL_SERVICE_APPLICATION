import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'theme_provider.dart';
import 'dart:io' show File;

class ProfileScreen extends StatefulWidget {
  final String token;
  const ProfileScreen({required this.token, super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _autoAnswerController = TextEditingController();
  XFile? _image;
  String? _profilePicUrl;
  bool _twoFaEnabled = false;
  bool _autoAnswerEnabled = false;
  bool _notificationsEnabled = true;
  String _autoAnswerMessage = '';
  int _defaultFontSize = 12;
  String _defaultFontFamily = 'Arial';
  String _error = '';
  bool _isLoading = false;
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'http://localhost:3000');

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _profilePicUrl = data['profilePic'];
          _twoFaEnabled = data['twoFaEnabled'] == true || data['twoFaEnabled'] == 1;
          _autoAnswerEnabled = data['autoAnswerEnabled'] == true || data['autoAnswerEnabled'] == 1;
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _autoAnswerMessage = data['autoAnswerMessage'] ?? '';
          _autoAnswerController.text = _autoAnswerMessage;
          _defaultFontSize = data['defaultFontSize'] ?? 12;
          _defaultFontFamily = data['defaultFontFamily'] ?? 'Arial';
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
          themeProvider.setDarkMode(data['isDarkMode'] ?? false);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load profile: ${response.body}';
          _isLoading = false;
        });
        print('Fetch profile failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to connect. Check server and network.';
        _isLoading = false;
      });
      print('Fetch profile exception: ${e}');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _image = picked;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      setState(() {
        _error = 'Name is required';
      });
      return;
    }

    if (_autoAnswerEnabled && _autoAnswerMessage.trim().isEmpty) {
      setState(() {
        _error = 'Auto Answer Message is required when Auto Answer Mode is enabled';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/profile'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['name'] = _nameController.text;
      request.fields['twoFaEnabled'] = _twoFaEnabled.toString();
      request.fields['autoAnswerEnabled'] = _autoAnswerEnabled.toString();
      request.fields['notificationsEnabled'] = _notificationsEnabled.toString();
      request.fields['autoAnswerMessage'] = _autoAnswerMessage;
      request.fields['defaultFontSize'] = _defaultFontSize.toString();
      request.fields['defaultFontFamily'] = _defaultFontFamily;
      request.fields['isDarkMode'] = Provider.of<ThemeProvider>(context, listen: false).isDarkMode.toString();
      if (_passwordController.text.isNotEmpty) {
        request.fields['password'] = _passwordController.text;
      }

      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        // Ensure filename has a valid extension
        String filename = _image!.name;
        if (!filename.contains('.')) {
          // Add a default extension if none exists (common for web)
          filename = '${filename}.jpg';
        }
        request.files.add(http.MultipartFile.fromBytes(
          'profilePic',
          bytes,
          filename: filename,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        setState(() {
          _profilePicUrl = updatedData['profilePic'];
          _image = null; // Clear the selected image after successful upload
          _isLoading = false;
        });
        Navigator.pop(context, {
          'name': _nameController.text,
          'profilePic': updatedData['profilePic'],
          'autoAnswerEnabled': updatedData['autoAnswerEnabled'] == true || updatedData['autoAnswerEnabled'] == 1,
          'notificationsEnabled': updatedData['notificationsEnabled'] ?? true,
          'autoAnswerMessage': updatedData['autoAnswerMessage'] ?? '',
          'defaultFontSize': updatedData['defaultFontSize'] ?? 12,
          'defaultFontFamily': updatedData['defaultFontFamily'] ?? 'Arial',
          'isDarkMode': updatedData['isDarkMode'] ?? false,
        });
      } else {
        setState(() {
          _error = 'Update failed: ${response.body}';
          _isLoading = false;
        });
        print('Update profile failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: Failed to upload profile. ${e.toString()}';
        _isLoading = false;
      });
      print('Update profile exception: ${e}');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _autoAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeProvider.isDarkMode
                      ? [Colors.grey.shade800, Colors.grey.shade900]
                      : [Colors.blue.shade100, Colors.blue.shade300],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Profile Settings',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<Widget>(
                            future: _buildAvatar(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return snapshot.data!;
                              } else if (snapshot.hasError) {
                                return const Icon(Icons.person, size: 50, color: Colors.grey);
                              } else {
                                return const CircularProgressIndicator();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _pickImage,
                            child: Text(
                              'Change Profile Picture',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                          if (_image != null)
                            Text(
                              'New image: ${_image!.name}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person, color: Colors.blue.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'New Password (optional)',
                              prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Two-Step Verification'),
                            value: _twoFaEnabled,
                            onChanged: (value) => setState(() => _twoFaEnabled = value),
                            activeColor: Colors.blue.shade700,
                          ),
                          SwitchListTile(
                            title: const Text('Enable Notifications'),
                            value: _notificationsEnabled,
                            onChanged: (value) => setState(() => _notificationsEnabled = value),
                            activeColor: Colors.blue.shade700,
                          ),
                          SwitchListTile(
                            title: const Text('Enable Auto Answer Mode'),
                            value: _autoAnswerEnabled,
                            onChanged: (value) => {
                              setState(() {
                                _autoAnswerEnabled = value;
                                if (!_autoAnswerEnabled) {
                                  _autoAnswerMessage = '';
                                  _autoAnswerController.clear();
                                }
                              }),
                            },
                            activeColor: Colors.blue.shade700,
                          ),
                          if (_autoAnswerEnabled)
                            TextField(
                              controller: _autoAnswerController,
                              onChanged: (value) => _autoAnswerMessage = value,
                              decoration: InputDecoration(
                                labelText: 'Auto Answer Message',
                                hintText: 'Enter your auto reply message here...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              maxLines: 3,
                            ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _defaultFontSize,
                            decoration: InputDecoration(
                              labelText: 'Font Size',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                            items: List.generate(29, (index) {
                              final size = index + 8;
                              return DropdownMenuItem<int>(
                                value: size,
                                child: Text('$size pt'),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _defaultFontSize = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _defaultFontFamily,
                            decoration: InputDecoration(
                              labelText: 'Font Family',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Arial', child: Text('Arial')),
                              DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
                              DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
                              DropdownMenuItem(value: 'Helvetica', child: Text('Helvetica')),
                              DropdownMenuItem(value: 'Verdana', child: Text('Verdana')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _defaultFontFamily = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            value: themeProvider.isDarkMode,
                            onChanged: (value) => themeProvider.toggleTheme(),
                            activeColor: Colors.blue.shade700,
                          ),
                          const SizedBox(height: 24),
                          if (_error.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _error,
                                style: TextStyle(color: Colors.red.shade900),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_error.isNotEmpty) const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade700, Colors.blue.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(fontSize: 18, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: _logout,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Logout',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<Widget> _buildAvatar() async {
    if (_image != null) {
      if (kIsWeb) {
        final bytes = await _image!.readAsBytes();
        return CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: MemoryImage(bytes),
        );
      } else {
        return CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: FileImage(File(_image!.path)),
        );
      }
    } else if (_profilePicUrl != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage('$_baseUrl$_profilePicUrl'),
      );
    } else {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, size: 50, color: Colors.white),
      );
    }
  }
}