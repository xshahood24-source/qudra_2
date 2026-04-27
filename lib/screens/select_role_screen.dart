// lib/screens/select_role_screen.dart
import 'package:flutter/material.dart';
import 'package:qudra_2/screens/guardian_login.dart';
import 'package:qudra_2/screens/login_screen.dart';
import '../services/language_service.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  String? selectedRole;
  final LanguageService _langService = LanguageService(); // استدعاء خدمة اللغة

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: ListenableBuilder(
                  listenable: _langService,
                  builder: (context, _) => TextButton.icon(
                    onPressed: () {
                      String newLang =
                          _langService.languageCode == 'ar' ? 'en' : 'ar';
                      _langService.updateLanguage(newLang);
                    },
                    icon: const Icon(Icons.language, color: Color(0xFF2D5357)),
                    label: Text(
                      _langService.currentLanguageName,
                      style: const TextStyle(color: Color(0xFF2D5357)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Select Your\nApp Path",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 60),
              _roleOption(
                title: "User",
                roleValue: "user",
                imagePath: 'assets/userr.jpeg',
                icon: Icons.person,
              ),
              const SizedBox(height: 20),
              _roleOption(
                title: "Guardian",
                roleValue: "guardian",
                imagePath: 'assets/guardiann.jpeg',
                icon: Icons.shield,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: selectedRole == null
                      ? null
                      : () {
                          if (selectedRole == "user") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoginScreen(role: selectedRole!),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GuardianLogin(role: selectedRole!),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5357),
                    disabledBackgroundColor:
                        const Color(0xFF2D5357).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
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

  Widget _roleOption(
      {required String title,
      required String roleValue,
      required String imagePath,
      required IconData icon}) {
    bool isSelected = selectedRole == roleValue;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = roleValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D5357) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Image.asset(
                imagePath,
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, size: 40, color: const Color(0xFF2D5357)),
              ),
              const Spacer(),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2D5357)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isSelected
                          ? const Color(0xFF2D5357)
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
