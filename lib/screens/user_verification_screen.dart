// lib/screens/auth/user_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qudra_2/screens/guard_profile.dart';
// import "guard_profile.dart";

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  final TextEditingController _userEmailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  Timer? _timer;
  int _start = 30;
  bool _isButtonDisabled = false;

  String? _generatedOtp;

  @override
  void dispose() {
    _timer?.cancel();
    _userEmailController.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isButtonDisabled = true;
      _start = 30;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _isButtonDisabled = false;
          timer.cancel();
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  Future<void> _sendOtp() async {
    String email = _userEmailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter the user email first");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // التأكد أن المستخدم موجود في قاعدة البيانات كـ user
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'user')
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnackBar("This email is not registered as a user");
      } else {
        // توليد كود مؤقت 4 أرقام
        _generatedOtp =
            (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

        // ⚠️ مؤقت: بيعرض الكود في snackbar
        // في الـ Production استبدل ده بـ Cloud Function أو EmailJS
        _showSnackBar(
            "Verification code sent to $email (Temp: $_generatedOtp)");

        _startTimer();
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndJoin() async {
    String otp = _otpControllers.map((e) => e.text).join();
    String email = _userEmailController.text.trim();

    if (otp.length < 4 || email.isEmpty) {
      _showSnackBar("Please enter the email and the 4-digit code");
      return;
    }

    if (_generatedOtp == null || otp != _generatedOtp) {
      _showSnackBar("Incorrect verification code. Please try again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'user')
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnackBar("User not found!");
        return;
      }

      String userUid = userQuery.docs.first.id;
      String? guardianUid = FirebaseAuth.instance.currentUser?.uid;

      if (guardianUid == null) {
        _showSnackBar("You must be logged in as a Guardian");
        return;
      }

      // ربط الـ Guardian بالـ User في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianUid)
          .update({
        'connectedUserEmail': email,
        'connectedUserId': userUid,
        'status': 'linked',
        'lastVerification': FieldValue.serverTimestamp(),
      });

      // كمان احفظ في الـ User إن فيه Guardian مربوط بيه
      await FirebaseFirestore.instance.collection('users').doc(userUid).update({
        'guardianId': guardianUid,
        'status': 'linked',
      });

      if (!mounted) return;

      _showSnackBar("Successfully linked! ✅");

      // بعد الربط الـ Guardian بيروح على الـ GuardProfile
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GuardProfile()),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar("Verification failed: $e");
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'User Verification',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "User verification",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter the email of the person you want to follow",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              const Text(
                "User email",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "example@mail.com",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  enabledBorder: OutlineInputBorder(
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      (_isLoading || _isButtonDisabled) ? null : _sendOtp,
                  child: Text(
                    _isButtonDisabled ? "Resend in $_start s" : "Send code",
                    style: TextStyle(
                      color: _isButtonDisabled
                          ? Colors.grey
                          : const Color(0xFF234F52),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (i) => _buildOtpBox(i)),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF234F52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Verify & Join",
                          style: TextStyle(fontSize: 18, color: Colors.white),
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

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.grey.shade100,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
}
