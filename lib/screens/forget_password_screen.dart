// lib/screens/auth/forget_password_screen.dart
import 'package:flutter/material.dart';
import 'package:qudra_2/constants/app_colors.dart';
import 'package:qudra_2/constants/app_styles.dart';
import 'package:qudra_2/services/auth_service.dart';
import 'enter_code_screen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Please enter your email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        _showSnackBar('Reset link sent! Check your email.');
        // بعد إرسال الـ email، بيروح لصفحة إدخال الكود
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnterCodeScreen(email: email),
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
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Forget Your Password?',
                style: AppStyles.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter your email address and we will send you a password reset link.',
                style: AppStyles.smallTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Email address:', style: AppStyles.labelStyle),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  fillColor: AppColors.grayInput,
                  filled: true,
                  hintText: 'Enter your email',
                  hintStyle: AppStyles.hintTextStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: AppStyles.labelStyle,
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 40),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Send Reset Link',
                          style: AppStyles.buttonTextStyle,
                        ),
                ),
              ),
              const SizedBox(height: 30),
              const Text('OR', style: AppStyles.smallTextStyle),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back',
                  style: AppStyles.labelStyle
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
