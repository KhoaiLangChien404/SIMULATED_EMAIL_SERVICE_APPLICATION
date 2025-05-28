import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _twoFactorEnabled = false;

  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeyRegister = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKeyLogin.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('http://192.168.30.11:3000/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': _phoneController.text,
            'password': _passwordController.text,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _storage.write(key: 'token', value: data['token']);
          final userResponse = await http.get(
            Uri.parse('http://192.168.30.11:3000/api/user'),
            headers: {'Authorization': 'Bearer ${data['token']}'},
          );
          if (userResponse.statusCode == 200) {
            final userData = jsonDecode(userResponse.body);
            // Convert int to bool: 1 -> true, 0 -> false
            bool isTwoFactorEnabled = userData['twoFactorEnabled'] == 1;
            if (isTwoFactorEnabled) {
              await FirebaseAuth.instance.signInWithPhoneNumber(_phoneController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OTP sent to phone')),
              );
            } else {
              Navigator.pushReplacementNamed(context, '/inbox');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to fetch user data: ${jsonDecode(userResponse.body)['message']}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${jsonDecode(response.body)['message']}')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kiểm tra thông tin')),
      );
    }
  }

  Future<void> _register() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đồng ý với Điều khoản dịch vụ')),
      );
      return;
    }

    if (_formKeyRegister.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        print('Registering with: ${_phoneController.text}, ${_passwordController.text}, ${_nameController.text}');
        final response = await http.post(
          Uri.parse('http://192.168.30.11:3000/api/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': _phoneController.text,
            'password': _passwordController.text,
            'name': _nameController.text,
            'twoFactorEnabled': _twoFactorEnabled,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công')),
          );
          _tabController.animateTo(0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${jsonDecode(response.body)['message']}')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kiểm tra thông tin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha((0.08 * 255).toInt()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.email_rounded,
                      size: 36,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Email Service',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[400],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Đăng nhập', height: 40),
                  Tab(text: 'Đăng ký', height: 40),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Form(
        key: _formKeyLogin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              label: 'Số điện thoại',
              icon: Icons.phone_android,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại';
                if (!value.startsWith('+') || value.length < 10) return 'Số điện thoại không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Mật khẩu',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                if (value.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/password-management'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  minimumSize: const Size(0, 36),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Quên mật khẩu?', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 32),
            _buildAuthButton(
              text: 'Đăng nhập',
              onPressed: _isLoading ? null : _login,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Form(
        key: _formKeyRegister,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              label: 'Họ và tên',
              icon: Icons.person_outline,
              controller: _nameController,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập họ và tên';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Số điện thoại',
              icon: Icons.phone_android,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại';
                if (!value.startsWith('+') || value.length < 10) return 'Số điện thoại không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Mật khẩu',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                if (value.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                  activeColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _twoFactorEnabled,
                  onChanged: (value) => setState(() => _twoFactorEnabled = value ?? false),
                  activeColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bật xác thực hai yếu tố (2FA)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildAuthButton(
              text: 'Đăng ký',
              onPressed: _isLoading ? null : _register,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && (controller == _passwordController ? _obscurePassword : _obscureConfirmPassword),
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black, fontSize: 15),
        floatingLabelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  controller == _passwordController ? (_obscurePassword ? Icons.visibility_off : Icons.visibility)
                      : (_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() {
                  if (controller == _passwordController) {
                    _obscurePassword = !_obscurePassword;
                  } else {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  }
                }),
              )
            : null,
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8, top: 16),
      ),
    );
  }

  Widget _buildAuthButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    final bool isDisabled = onPressed == null;
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isDisabled ? Colors.grey[300] : Theme.of(context).primaryColor,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}