import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String token;
  ProfileScreen({required this.token});

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
  String _autoAnswerMessage = '';
  int _defaultFontSize = 12;
  String _defaultFontFamily = 'Arial';
  String _error = '';
  bool _isLoading = false;
  final String _baseUrl = 'http://localhost:3000';

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
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _profilePicUrl = data['profilePic'];
          _twoFaEnabled = (data['twoFaEnabled'] == 1 || data['twoFaEnabled'] == true);
          _autoAnswerEnabled = (data['autoAnswerEnabled'] == 1 || data['autoAnswerEnabled'] == true);
          _autoAnswerMessage = data['autoAnswerMessage'] ?? '';
          _autoAnswerController.text = _autoAnswerMessage;
          _defaultFontSize = data['defaultFontSize'] ?? 12;
          _defaultFontFamily = data['defaultFontFamily'] ?? 'Arial';
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
          themeProvider.setDarkMode(data['isDarkMode'] ?? false); // Use setDarkMode instead
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
      print('Fetch profile exception: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = picked;
    });
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
      request.fields['autoAnswerMessage'] = _autoAnswerMessage;
      request.fields['defaultFontSize'] = _defaultFontSize.toString();
      request.fields['defaultFontFamily'] = _defaultFontFamily;
      request.fields['isDarkMode'] = Provider.of<ThemeProvider>(context, listen: false).isDarkMode.toString(); // Save theme preference
      if (_passwordController.text.isNotEmpty) {
        request.fields['password'] = _passwordController.text;
      }

      if (_image != null) {
        if (kIsWeb) {
          final bytes = await _image!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'profilePic',
            bytes,
            filename: _image!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'profilePic',
            _image!.path,
          ));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        setState(() {
          _profilePicUrl = updatedData['profilePic'];
          _isLoading = false;
        });
        Navigator.pop(context, {
          'name': _nameController.text,
          'profilePic': updatedData['profilePic'],
          'autoAnswerEnabled': updatedData['autoAnswerEnabled'] == 1 || updatedData['autoAnswerEnabled'] == true,
          'autoAnswerMessage': updatedData['autoAnswerMessage'] ?? '',
          'defaultFontSize': updatedData['defaultFontSize'] ?? 12,
          'defaultFontFamily': updatedData['defaultFontFamily'] ?? 'Arial',
          'isDarkMode': updatedData['isDarkMode'] ?? false, // Return updated theme preference
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
      print('Update profile exception: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
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
      appBar: AppBar(title: Text('Profile')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_profilePicUrl != null)
                      Image.network(
                        '$_baseUrl$_profilePicUrl',
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image load error: $error');
                          return CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 50,
                            child: Icon(Icons.person, size: 50, color: Colors.grey),
                          );
                        },
                      )
                    else
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 50,
                        child: Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                    ElevatedButton(onPressed: _pickImage, child: Text('Change Profile Picture')),
                    if (_image != null) Text('New image: ${_image!.name}'),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'New Password (optional)'),
                      obscureText: true,
                    ),
                    SwitchListTile(
                      title: Text('Enable Two-Step Verification'),
                      value: _twoFaEnabled,
                      onChanged: (value) => setState(() => _twoFaEnabled = value),
                    ),
                    SwitchListTile(
                      title: Text('Enable Auto Answer Mode'),
                      value: _autoAnswerEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoAnswerEnabled = value ?? false;
                          if (!_autoAnswerEnabled) {
                            _autoAnswerMessage = '';
                            _autoAnswerController.clear();
                          }
                        });
                      },
                    ),
                    if (_autoAnswerEnabled)
                      TextField(
                        controller: _autoAnswerController,
                        onChanged: (value) => _autoAnswerMessage = value,
                        decoration: InputDecoration(
                          labelText: 'Auto Answer Message',
                          hintText: 'Enter your auto reply message here...',
                        ),
                        maxLines: 3,
                      ),
                    DropdownButton<int>(
                      value: _defaultFontSize,
                      hint: Text('Select Font Size'),
                      items: List.generate(29, (index) => 8 + index)
                          .map((size) => DropdownMenuItem<int>(
                                value: size,
                                child: Text('$size pt'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _defaultFontSize = value;
                          });
                        }
                      },
                    ),
                    DropdownButton<String>(
                      value: _defaultFontFamily,
                      hint: Text('Select Font Family'),
                      items: ['Arial', 'Times New Roman', 'Courier New', 'Helvetica', 'Verdana']
                          .map((font) => DropdownMenuItem<String>(
                                value: font,
                                child: Text(font),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _defaultFontFamily = value;
                          });
                        }
                      },
                    ),
                    SwitchListTile(
                      title: Text('Dark Mode'),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                        setState(() {}); // Trigger rebuild to reflect theme change
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(onPressed: _updateProfile, child: Text('Save Changes')),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Logout'),
                    ),
                    if (_error.isNotEmpty) Text(_error, style: TextStyle(color: themeProvider.isDarkMode ? Colors.red[200] : Colors.red)),
                  ],
                ),
              ),
            ),
    );
  }
}