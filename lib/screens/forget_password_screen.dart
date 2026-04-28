// lib/screens/auth/forget_password_screen.dart
//
// الـ Flow الجديد:
// 1. المستخدم بيدخل رقم التليفون
// 2. Firebase بيبعت SMS بكود OTP
// 3. المستخدم بيدخل الكود
// 4. بعد التحقق بيدخل كلمة المرور الجديدة
// 5. Firebase بيحدث الـ password
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  // ─── Pages ───
  // 0 = إدخال رقم التليفون
  // 1 = إدخال OTP
  // 2 = إدخال كلمة المرور الجديدة
  int _currentStep = 0;

  // ─── Controllers ───
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // ─── Firebase ───
  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _verifiedCredential;

  // ─── State ───
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // ─── Timer ───
  Timer? _timer;
  int _secondsLeft = 60;
  bool _canResend = false;

  String get _maskedPhone {
    final p = _phoneController.text.trim();
    if (p.length < 6) return p;
    final visible = p.substring(p.length - 4);
    final hidden = '*' * (p.length - 6);
    return '${p.substring(0, 2)}$hidden$visible';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  // ─── Step 1: إرسال OTP ───
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter a valid phone number.');
      return;
    }

    // إضافة كود الدولة لو مش موجود
    final fullPhone = phone.startsWith('+') ? phone : '+2$phone';

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        _verifiedCredential = credential;
        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showError(e.message ?? 'Failed to send code. Check the number.');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _currentStep = 1;
          _isLoading = false;
        });
        _startTimer();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ─── Step 2: التحقق من OTP ───
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit code.');
      return;
    }
    if (_verificationId == null) {
      _showError('Please request a new code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _verifiedCredential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // نتحقق إن الكود صح بمحاولة signIn مؤقتة
      await FirebaseAuth.instance.signInWithCredential(_verifiedCredential!);

      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showError(e.message ?? 'Invalid code. Please try again.');
    }
  }

  // ─── Step 3: تحديث كلمة المرور ───
  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Session expired. Please start over.');
        setState(() {
          _currentStep = 0;
          _isLoading = false;
        });
        return;
      }

      await user.updatePassword(password);

      if (!mounted) return;

      // نجح! ارجع للـ login
      _showSuccess('Password updated successfully!');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to update password.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2D5357),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 1.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.black87),
          ),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
          child: _currentStep == 0
              ? _buildPhoneStep()
              : _currentStep == 1
                  ? _buildOtpStep()
                  : _buildNewPasswordStep(),
        ),
      ),
    );
  }

  // ─── Step 0: إدخال رقم التليفون ───
  Widget _buildPhoneStep() {
    return Padding(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Enter your phone number and we'll send you a verification code.",
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF9E9E9E),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: '01012345678',
              hintStyle:
                  const TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
              prefixText: '+20  ',
              prefixStyle: const TextStyle(
                  color: Color(0xFF2D5357),
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF2D5357), width: 1.5),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5357),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                      'Send Code',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Step 1: إدخال OTP ───
  Widget _buildOtpStep() {
    return Padding(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enter your OTP',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "We've sent to $_maskedPhone",
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),

          const SizedBox(height: 52),

          // OTP Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 48,
                height: 56,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFF2D5357), width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const Spacer(),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5357),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                      'Verify',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Resend
          GestureDetector(
            onTap: _canResend ? _sendOtp : null,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _canResend
                    ? const Color(0xFF2D5357)
                    : const Color(0xFF9E9E9E),
              ),
              child: Text(
                _canResend ? 'Resend OTP' : 'Resend OTP in $_secondsLeft s',
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Step 2: كلمة المرور الجديدة ───
  Widget _buildNewPasswordStep() {
    return Padding(
      key: const ValueKey('password'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          const Text(
            'New Password',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Enter your new password below.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF9E9E9E),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 48),

          // New Password
          const Text(
            'New Password',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePass,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Min. 6 characters',
              hintStyle:
                  const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF2D5357), width: 1.5),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Confirm Password
          const Text(
            'Confirm Password',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Re-enter password',
              hintStyle:
                  const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF2D5357), width: 1.5),
              ),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5357),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
