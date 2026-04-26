// lib/screens/voice_description_screen.dart
import 'package:flutter/material.dart';

class VoiceDescriptionScreen extends StatelessWidget {
  // التعديل هنا: أضفنا required لضمان تمرير الوصف عند الاستدعاء
  final String description;

  const VoiceDescriptionScreen({
    super.key,
    required this.description, // هذا هو السطر الذي كان ينقصك
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D5357),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.graphic_eq, size: 100, color: Color(0xFFE0F7F7)),
          const SizedBox(height: 40),
          const Text(
            "Scene Description",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.replay_rounded,
                label: "Repeat",
                onTap: () {
                  // هنا يمكنك استدعاء خدمة الصوت مرة أخرى
                },
              ),
              const SizedBox(width: 40),
              _buildActionButton(
                icon: Icons.copy_rounded,
                label: "Copy",
                onTap: () {
                  // منطق نسخ النص
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
