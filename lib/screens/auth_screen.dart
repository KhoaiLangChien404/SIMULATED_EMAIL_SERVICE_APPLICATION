import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Logo and app name with minimal design
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
            // Modern minimal tab bar
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
                  Tab(
                    text: 'Đăng nhập',
                    height: 40,
                  ),
                  Tab(
                    text: 'Đăng ký',
                    height: 40,
                  ),
                ],
              ),
            ),
            // Tab content
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone number field
          _buildTextField(
            label: 'Số điện thoại',
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 16),
          // Password field
          _buildTextField(
            label: 'Mật khẩu',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 8),
          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/password-recovery');
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Login button
          _buildAuthButton(
            text: 'Đăng nhập',
            onPressed: () {
              if (!_isLoading) {
                setState(() {
                  _isLoading = true;
                });
                // Simulate login
                Future.delayed(const Duration(seconds: 1), () {
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                  });
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/inbox');
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full name field
          _buildTextField(
            label: 'Họ và tên',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          // Phone number field
          _buildTextField(
            label: 'Số điện thoại',
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 16),
          // Email field
          _buildTextField(
            label: 'Email',
            icon: Icons.email,
          ),
          const SizedBox(height: 16),
          // Password field
          _buildTextField(
            label: 'Mật khẩu',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 16),
          // Confirm password field
          _buildTextField(
            label: 'Xác nhận mật khẩu',
            icon: Icons.lock_outline,
            isPassword: true,
            isConfirmPassword: true,
          ),
          const SizedBox(height: 20),
          // Terms and conditions
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _agreeToTerms = !_agreeToTerms;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _agreeToTerms
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                    ),
                    color: _agreeToTerms
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                  ),
                  child: _agreeToTerms
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Register button
          _buildAuthButton(
            text: 'Đăng ký',
            onPressed: _agreeToTerms
                ? () {
                    if (!_isLoading) {
                      setState(() {
                        _isLoading = true;
                      });
                      // Simulate registration
                      Future.delayed(const Duration(seconds: 1), () {
                        setState(() {
                          _isLoading = false;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đăng ký thành công!'),
                            backgroundColor: Colors.black87,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      });
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
  }) {
    return TextField(
      obscureText: isPassword && (isConfirmPassword ? _obscureConfirmPassword : _obscurePassword),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.grey[500],
          size: 20,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (isConfirmPassword ? _obscureConfirmPassword : _obscurePassword)
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    if (isConfirmPassword) {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    } else {
                      _obscurePassword = !_obscurePassword;
                    }
                  });
                },
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
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
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).primaryColor,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}