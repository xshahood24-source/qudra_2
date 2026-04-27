// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_role_screen.dart';
import 'home_screen.dart';
import 'guard_profile.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // مفيش يوزر مسجل دخول
      _goTo(const SelectRoleScreen());
      return;
    }

    try {
      // جيب بيانات اليوزر من Firestore عشان تعرف الـ role
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'user';
        if (role == 'guardian') {
          _goTo(const GuardProfile());
        } else {
          _goTo(const HomeScreen());
        }
      } else {
        _goTo(const SelectRoleScreen());
      }
    } catch (e) {
      _goTo(const SelectRoleScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A5258),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.jpg',
              width: MediaQuery.of(context).size.width * 0.8,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.visibility,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
