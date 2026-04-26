// lib/screens/auth/enter_code_screen.dart
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';

class EnterCodeScreen extends StatefulWidget {
  final String email;

  const EnterCodeScreen({
    super.key,
    required this.email,
  });

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // إخفاء الإيميل جزئيًا  example@mail.com -> ex****@mail.com
  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    final masked = name.substring(0, 2) + '*' * (name.length - 2);
    return '$masked@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Enter Your Code',
                style: AppStyles.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  fillColor: AppColors.grayInput,
                  filled: true,
                  hintText: '6-digit code',
                  hintStyle: AppStyles.hintTextStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppStyles.labelStyle,
                maxLength: 6,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Get a New Code',
                    style: AppStyles.smallTextStyle,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Firebase بيبعت reset link على الإيميل، مفيش verify للكود من جانبنا
                  // ده بس UI للتوضيح — الـ link بيوصل على الإيميل مباشرة
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please check your email for the reset link.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 40),
                ),
                child: const Text(
                  'Next',
                  style: AppStyles.buttonTextStyle,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'We sent a reset link to ${_maskEmail(widget.email)}.',
                style: AppStyles.smallTextStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
