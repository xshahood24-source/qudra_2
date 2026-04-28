// lib/screens/auth/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:qudra_2/services/auth_service.dart';
import '../../constants/app_colors.dart';
import 'otp_screen.dart'; // ← الجديد

class SignUpScreen extends StatefulWidget {
  final String role;
  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isLoading = false;

  static const TextStyle labelStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: Colors.black,
  );

  InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      _showSnackBar('All fields are required');
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. إنشاء الحساب في Firebase
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: widget.role,
      );

      if (result != null && mounted) {
        // 2. بعد إنشاء الحساب روح للـ OTP للتحقق من رقم التليفون
        final fullPhone = phone.startsWith('+') ? phone : '+2$phone';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              phoneNumber: fullPhone,
              role: widget.role,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Sign Up',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your ${widget.role} account',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const Text('Name', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                  controller: _nameController,
                  decoration: inputDecoration('Enter your name')),
              const SizedBox(height: 20),
              const Text('Email', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: inputDecoration('Enter your email')),
              const SizedBox(height: 20),
              const Text('Phone Number', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '01012345678',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixText: '+20  ',
                  prefixStyle: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryDark, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Password', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: inputDecoration(
                  'Create a password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Confirm Password', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmText,
                decoration: inputDecoration(
                  'Re-enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmText
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscureConfirmText = !_obscureConfirmText),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
