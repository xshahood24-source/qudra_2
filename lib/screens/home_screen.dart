// lib/screens/home_screen.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/voice_assistant_service.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _voiceAssistant.initialize();
    _voiceAssistant.startListening();
  }

  Future<void> _initializeCamera() async {
    try {
      log("Initializing camera...");
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        controller = CameraController(cameras![0], ResolutionPreset.high);
        await controller?.initialize();
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      log("Error initializing camera: $e");
    }
  }

  Future<void> _takePictureAndDescribe() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        _isTakingPicture) return;

    try {
      setState(() => _isTakingPicture = true);

      // التقاط الصورة
      await controller!.takePicture();

      // هنا بتبعت الصورة لـ AI model الخاص بك
      // مثال محاكاة:
      String imageDescription =
          "I see a person standing in front of a wooden door.";

      await _voiceAssistant.speak(imageDescription);

      if (!mounted) return;

      // عرض الوصف في bottom sheet
      _showDescriptionSheet(imageDescription);
    } catch (e) {
      log("Error taking picture: $e");
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  void _showDescriptionSheet(String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility,
                    color: Color(0xFF2D5357), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Scene Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5357),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    _voiceAssistant.stopListening();
    _voiceAssistant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // خلفية الكاميرا
          Positioned.fill(
            child: controller != null && controller!.value.isInitialized
                ? CameraPreview(controller!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
          ),

          // شريط الأيقونات السفلي
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // زر SOS (يسار)
                  _buildBottomButton(
                    icon: Icons.sos,
                    color: Colors.white,
                    iconColor: const Color(0xFF2D5357),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SOSScreen()),
                    ),
                  ),

                  // زر الكاميرا الرئيسي (منتصف)
                  GestureDetector(
                    onTap: _isTakingPicture ? null : _takePictureAndDescribe,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7F7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: _isTakingPicture
                          ? const CircularProgressIndicator(
                              color: Color(0xFF2D5357))
                          : const Icon(Icons.camera_alt,
                              size: 45, color: Color(0xFF2D5357)),
                    ),
                  ),

                  // زر الإعدادات (يمين)
                  _buildBottomButton(
                    icon: Icons.settings,
                    color: Colors.white,
                    iconColor: const Color(0xFF2D5357),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, size: 35, color: iconColor),
      ),
    );
  }
}
