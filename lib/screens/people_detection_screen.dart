import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'qudra_api_service';
class PeopleDetectionScreen extends StatefulWidget {
  const PeopleDetectionScreen({super.key});

  @override
  State<PeopleDetectionScreen> createState() => _PeopleDetectionScreenState();
}

class _PeopleDetectionScreenState extends State<PeopleDetectionScreen> {
  CameraController? _controller;
  final _apiService = QudraApiService();
  String _resultMessage = 'اضغط على الزر لتحليل المشهد';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _analyzeScene() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _resultMessage = 'جارِ التحليل، الرجاء الانتظار...';
    });

    try {
      // 1. التقاط الصورة
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      // 2. إرسال الصورة للـ API (الدوكر)
      final String description = await _apiService.analyzeImage(imageFile);

      setState(() {
        _resultMessage = description;
      });
      
    } catch (e) {
      setState(() {
        _resultMessage = 'حدث خطأ أثناء التحليل: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشروع قدرة - كشف الأشياء'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: Colors.black87,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _resultMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _analyzeScene,
                    icon: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.remove_red_eye),
                    label: Text(_isProcessing ? 'جاري التحليل...' : 'حلل المشهد الآن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
