// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_role_screen.dart';
import 'user_profile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget buildItem(
    BuildContext context,
    Widget icon,
    String title,
    VoidCallback onTap, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: icon,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          trailing:
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Color(0xFFEEEEEE),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 16),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Setting',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Account -> UserProfile
                  buildItem(
                    context,
                    Stack(
                      alignment: Alignment.topRight,
                      children: const [
                        Icon(Icons.person_outline,
                            size: 30, color: Colors.black),
                        Positioned(
                          right: 0,
                          top: 2,
                          child: Icon(Icons.settings,
                              size: 12, color: Colors.black),
                        ),
                      ],
                    ),
                    'Account',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserProfile()),
                      );
                    },
                  ),
                  buildItem(
                    context,
                    const Icon(Icons.accessibility_new_rounded,
                        size: 30, color: Colors.black),
                    'Accessibility',
                    () {},
                  ),
                  // buildItem(
                  //   context,
                  //   const Icon(Icons.group_outlined,
                  //       size: 30, color: Colors.black),
                  //   'Guardian Numbers',
                  //   () {},
                  // ),
                  buildItem(
                    context,
                    const Icon(Icons.info_outline,
                        size: 30, color: Colors.black),
                    'About & Privacy',
                    () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Logout
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                leading: const Icon(Icons.logout, color: Colors.red, size: 28),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SelectRoleScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
