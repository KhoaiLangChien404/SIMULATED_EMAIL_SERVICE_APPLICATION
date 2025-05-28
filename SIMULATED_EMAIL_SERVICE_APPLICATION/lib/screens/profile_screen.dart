import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  bool _isEditing = false;
  bool _isLoading = false;
  String _name = '';
  String _phoneNumber = '';
  String? _profileImageBase64;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'token');
    final response = await http.get(
      Uri.parse('http://localhost:3000/api/user'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _name = data['name'];
        _phoneNumber = data['phone'];
        _profileImageBase64 = data['profilePicture'];
        _twoFactorEnabled = data['twoFactorEnabled'];
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final token = await _storage.read(key: 'token');
      final response = await http.put(
        Uri.parse('http://localhost:3000/api/user'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _name,
          'twoFactorEnabled': _twoFactorEnabled,
          'profilePicture': _profileImageBase64,
        }),
      );
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin')),
        );
        setState(() => _isEditing = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thất bại')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBase64 = base64Encode(bytes);
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditing) {
        _saveProfile();
      } else {
        _isEditing = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.done_all_rounded : Icons.edit_rounded),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 32),
                    _SectionCard(
                      title: 'Thông tin cá nhân',
                      children: [
                        _ProfileInputField(
                          label: 'Họ và tên',
                          icon: Icons.person_outline_rounded,
                          initialValue: _name,
                          enabled: _isEditing,
                          validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
                          onChanged: (v) => _name = v,
                        ),
                        const Divider(height: 24),
                        _ProfileInputField(
                          label: 'Số điện thoại',
                          icon: Icons.phone_iphone_rounded,
                          initialValue: _phoneNumber,
                          enabled: false, // Phone number is not editable
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      title: 'Bảo mật',
                      children: [
                        _SecurityOption(
                          icon: Icons.lock_outline_rounded,
                          title: 'Đổi mật khẩu',
                          onTap: () => Navigator.pushNamed(context, '/password-management'),
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          title: const Text('Xác minh hai bước'),
                          secondary: Icon(Icons.verified_user_outlined, color: Theme.of(context).primaryColor),
                          value: _twoFactorEnabled,
                          onChanged: _isEditing
                              ? (value) => setState(() => _twoFactorEnabled = value)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          await _storage.delete(key: 'token');
                          Navigator.pushReplacementNamed(context, '/auth');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).toInt()),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundImage: _profileImageBase64 != null ? MemoryImage(base64Decode(_profileImageBase64!)) : null,
            backgroundColor: Colors.grey[200],
            child: _profileImageBase64 == null
                ? const Icon(Icons.person_rounded, size: 48, color: Colors.white)
                : null,
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String initialValue;
  final bool enabled;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;

  const _ProfileInputField({
    required this.label,
    required this.icon,
    required this.initialValue,
    required this.enabled,
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? Colors.black : Colors.grey[600], fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, size: 22, color: Colors.grey[500]),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

class _SecurityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SecurityOption({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}