// lib/screens/auth/otp_screen.dart
//
// الـ Flow:
// Sign Up ──► OTP Screen (التحقق من رقم التليفون) ──► Home / Guard Profile
//
// Firebase Phone Auth بيبعت SMS على رقم التليفون
// المستخدم بيدخل الكود ويضغط Verify
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpScreen extends StatefulWidget {
  /// رقم التليفون المُرسَل إليه الكود  e.g. "+201012345678"
  final String phoneNumber;

  /// الـ role عشان يروح للصفحة الصح بعد التحقق
  final String role;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.role,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ─── OTP Controllers & Focus ───
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // ─── Firebase ───
  String? _verificationId;
  int? _resendToken;

  // ─── State ───
  bool _isVerifying = false;
  bool _isSendingCode = false;
  bool _codeSent = false;

  // ─── Resend Timer ───
  Timer? _timer;
  int _secondsLeft = 60;
  bool _canResend = false;

  // ─── الـ masked phone number للعرض ───
  String get _maskedPhone {
    final p = widget.phoneNumber;
    if (p.length < 6) return p;
    // +201012345678  →  +20*****5678
    final visible = p.substring(p.length - 4);
    final hidden = '*' * (p.length - 6);
    return '${p.substring(0, 2)}$hidden$visible';
  }

  @override
  void initState() {
    super.initState();
    _sendVerificationCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ─── إرسال كود التحقق عبر Firebase Phone Auth ───
  Future<void> _sendVerificationCode() async {
    setState(() => _isSendingCode = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),

      // ✅ Auto-retrieved (Android only) — بيملي الكود تلقائيًا
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential);
      },

      // ❌ فشل الإرسال
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isSendingCode = false);
        _showError(e.message ?? 'Verification failed. Check the number.');
      },

      // 📨 تم إرسال الكود — الـ verificationId مهم للـ verify
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isSendingCode = false;
        });
        _startTimer();
      },

      // ⏱️ Timeout
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ─── Timer للـ Resend ───
  void _startTimer() {
    setState(() {
      _secondsLeft = 60;
      _canResend = false;
    });
    _timer?.cancel();
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

  // ─── التحقق من الكود ───
  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit code.');
      return;
    }
    if (_verificationId == null) {
      _showError('Please wait for the code to arrive.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Invalid code. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ─── تسجيل الدخول بعد التحقق ───
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      // ربط الـ phone credential بالحساب الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.linkWithCredential(credential);
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // تحديث Firestore — إضافة phoneVerified: true
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'phoneVerified': true});
      }

      if (!mounted) return;

      // التوجيه حسب الـ role
      _navigateAfterVerification();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Verification failed.');
    }
  }

  void _navigateAfterVerification() {
    // بعد التحقق يروح للصفحة الصح
    if (widget.role == 'guardian') {
      // Guardian بيروح user_verification_screen
      Navigator.pushNamedAndRemoveUntil(
          context, '/user_verification', (route) => false);
    } else {
      // User بيروح home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  // ─── OTP Box Widget ───
  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
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
            borderSide: const BorderSide(color: Color(0xFF2D5357), width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty) {
            // انتقل للـ box اللي بعده
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              // آخر box → إخفاء الـ keyboard
              _focusNodes[index].unfocus();
            }
          } else if (value.isEmpty && index > 0) {
            // Backspace → ارجع للـ box السابق
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // ─── Title ───
              const Text(
                'Enter your OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 10),

              // ─── Subtitle ───
              Text(
                "We've sent to $_maskedPhone",
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 52),

              // ─── OTP Boxes ───
              _isSendingCode
                  ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2D5357),
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, _buildOtpBox),
                    ),

              const Spacer(),

              // ─── Verify Button ───
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: (_isVerifying || _isSendingCode || !_codeSent)
                      ? null
                      : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5357),
                    disabledBackgroundColor:
                        const Color(0xFF2D5357).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Resend OTP ───
              GestureDetector(
                onTap: _canResend ? _sendVerificationCode : null,
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
        ),
      ),
    );
  }
}
