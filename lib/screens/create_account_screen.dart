// lib/screens/auth/create_account_screen.dart
import 'package:flutter/material.dart';
import 'package:qudra_2/services/auth_service.dart';
// import 'package:qudra_2/screens/home_screen.dart';
import 'user_verification_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  final String role;

  const CreateAccountScreen({
    super.key,
    required this.role,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ────────────────────────────────
  // Continue بـ Email/Password
  // ────────────────────────────────
  Future<void> _handleContinue() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter your email and password.');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: '', // الـ Guardian مش بيدخل اسمه هنا — بيكمله في UserVerification
        phone: '',
        role: widget.role,
      );

      if (result != null && mounted) {
        // بعد ما اتعمل الحساب، ننقله لصفحة التحقق عشان يربط الـ User
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserVerificationScreen(),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────
  // Continue بـ Google
  // ────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle();

      if (result != null && mounted) {
        // لو Guardian سجّل بـ Google، ننقله لصفحة التحقق برضو
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserVerificationScreen(),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Google Sign In failed. Please try again.');
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              const Text(
                "Create account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create your ${widget.role} account to continue",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // ─── Email ───
              const Text(
                "Your email",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: Color(0xFF2D5357), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ─── Password ───
              const Text(
                "Password",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _isPasswordObscured,
                decoration: InputDecoration(
                  hintText: "password",
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black54,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordObscured = !_isPasswordObscured),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: Color(0xFF2D5357), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 100),

              // ─── زرار Continue ───
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5357),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Continue",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // ─── Or ───
              Row(
                children: [
                  Expanded(
                      child:
                          Divider(color: Colors.grey.shade300, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Or",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                  Expanded(
                      child:
                          Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),

              const SizedBox(height: 25),

              // ─── زرار Google ───
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail, color: Colors.red, size: 22),
                      SizedBox(width: 12),
                      Text(
                        "Continue with Gmail",
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
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
