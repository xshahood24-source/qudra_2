// lib/screens/auth/user_verification_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qudra_2/screens/guard_profile.dart';
// import

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  bool _codeSent = false; // هل تم إرسال الكود؟
  bool _isButtonDisabled = false; // Resend cooldown
  int _countdown = 60;
  Timer? _timer;

  String? _generatedOtp;
  String? _foundUserId; // UID بتاع الـ User اللي اتلاقى

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ─── Timer للـ Resend ───
  void _startCountdown() {
    setState(() {
      _isButtonDisabled = true;
      _countdown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        setState(() => _isButtonDisabled = false);
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  // ─── إرسال الـ OTP ───
  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('Please enter the user\'s phone number', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ─── ابحث عن الـ User في Firestore بالرقم ───
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .where('role', isEqualTo: 'user')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnackBar('No user found with this phone number', isError: true);
        return;
      }

      final userDoc = query.docs.first;
      _foundUserId = userDoc.id;

      // ─── ولّد OTP عشوائي 4 أرقام ───
      _generatedOtp = (1000 + Random().nextInt(9000)).toString();

      // ─── احفظ الـ OTP في document الـ User في Firestore ───
      // الـ User يقدر يشوفه في التطبيق بتاعه من document الخاص بيه
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_foundUserId)
          .update({
        'pendingOtp': _generatedOtp,
        'otpCreatedAt': FieldValue.serverTimestamp(),
        'otpRequestedByGuardian': FirebaseAuth.instance.currentUser?.uid,
      });

      setState(() => _codeSent = true);
      _startCountdown();

      // ⚠️ مؤقت: في الـ Production هتبعت notification للـ User عبر FCM
      // أو تستخدم Twilio / Firebase SMS
      // دلوقتي بيعرض الكود في snackbar للتجربة
      _showSnackBar('Code sent to user\'s phone. (Temp code: $_generatedOtp)');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── التحقق والربط ───
  Future<void> _verifyAndJoin() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length < 4) {
      _showSnackBar('Please enter the 4-digit code', isError: true);
      return;
    }

    if (_generatedOtp == null || otp != _generatedOtp) {
      _showSnackBar('Incorrect code. Please try again.', isError: true);
      return;
    }

    if (_foundUserId == null) {
      _showSnackBar('User not found. Please resend the code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final guardianUid = FirebaseAuth.instance.currentUser?.uid;
      if (guardianUid == null) {
        _showSnackBar('You must be logged in as a Guardian', isError: true);
        return;
      }

      // ─── ربط الـ Guardian بالـ User ───
      final batch = FirebaseFirestore.instance.batch();

      // في document الـ Guardian
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(guardianUid),
        {
          'connectedUserId': _foundUserId,
          'connectedUserPhone': _phoneController.text.trim(),
          'status': 'linked',
          'linkedAt': FieldValue.serverTimestamp(),
        },
      );

      // في document الـ User
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(_foundUserId),
        {
          'guardianId': guardianUid,
          'status': 'linked',
          'linkedAt': FieldValue.serverTimestamp(),
          // امسح الـ OTP بعد الاستخدام
          'pendingOtp': FieldValue.delete(),
          'otpCreatedAt': FieldValue.delete(),
          'otpRequestedByGuardian': FieldValue.delete(),
        },
      );

      await batch.commit();

      if (!mounted) return;
      _showSnackBar('Successfully linked! ✅');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GuardProfile()),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Verification failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF234F52),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'User Verification',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ─── Step Indicator ───
              _buildStepIndicator(),

              const SizedBox(height: 30),

              // ─── Step 1: Phone Input ───
              _buildPhoneSection(),

              const SizedBox(height: 30),

              // ─── Step 2: OTP Input (يظهر بعد إرسال الكود) ───
              if (_codeSent) ...[
                _buildOtpSection(),
                const SizedBox(height: 40),
                _buildVerifyButton(),
              ] else ...[
                const SizedBox(height: 40),
                _buildSendCodeButton(),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step Indicator ───
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(active: true, done: _codeSent, label: '1'),
        Expanded(
          child: Container(
            height: 2,
            color: _codeSent ? const Color(0xFF234F52) : Colors.grey.shade200,
          ),
        ),
        _stepDot(active: _codeSent, done: false, label: '2'),
      ],
    );
  }

  Widget _stepDot({
    required bool active,
    required bool done,
    required String label,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF234F52) : Colors.grey.shade200,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  // ─── Phone Section ───
  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter User\'s Phone',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the phone number of the person you want to follow. A verification code will be sent to their account.',
          style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_codeSent, // بعد الإرسال الحقل بيتقفل
          decoration: InputDecoration(
            hintText: 'e.g. 01012345678',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon:
                const Icon(Icons.phone_outlined, color: Color(0xFF234F52)),
            filled: true,
            fillColor: _codeSent ? Colors.grey.shade50 : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: Color(0xFF234F52), width: 1.5),
            ),
          ),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 10),
          // زرار تغيير الرقم
          GestureDetector(
            onTap: () {
              setState(() {
                _codeSent = false;
                _generatedOtp = null;
                _foundUserId = null;
                for (var c in _otpControllers) c.clear();
              });
              _timer?.cancel();
            },
            child: const Text(
              'Change phone number',
              style: TextStyle(
                color: Color(0xFF234F52),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── OTP Section ───
  Widget _buildOtpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Ask the user for the 4-digit code sent to their device.',
          style:
              TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 24),

        // OTP Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => _buildOtpBox(i)),
        ),

        const SizedBox(height: 20),

        // Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Didn't receive code? ",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            GestureDetector(
              onTap: _isButtonDisabled ? null : _sendCode,
              child: Text(
                _isButtonDisabled ? 'Resend in $_countdown s' : 'Resend Code',
                style: TextStyle(
                  color:
                      _isButtonDisabled ? Colors.grey : const Color(0xFF234F52),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 65,
      height: 65,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF234F52), width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  // ─── Send Code Button ───
  Widget _buildSendCodeButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF234F52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Send Verification Code',
                style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // ─── Verify Button ───
  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyAndJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF234F52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Verify & Connect',
                style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
