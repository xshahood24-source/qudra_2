// lib/screens/lighting_status_screen.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/voice_assistant_service.dart';

class LightingStatusScreen extends StatefulWidget {
  const LightingStatusScreen({super.key});

  @override
  State<LightingStatusScreen> createState() => _LightingStatusScreenState();
}

class _LightingStatusScreenState extends State<LightingStatusScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;

  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(
      confidenceThreshold: 0.5,
    ),
  );

  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();

  String _lastDetectedLighting = 'No lighting status detected yet.';
  bool _isProcessing = false;

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
        controller = CameraController(
          cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await controller!.initialize();
        _startImageStream();

        if (mounted) setState(() {});
      }
    } catch (e) {
      log("Camera initialization error: $e");
    }
  }

  void _startImageStream() {
    if (controller == null) return;

    controller!.startImageStream((CameraImage image) async {
      if (!mounted || _isProcessing) return;

      _isProcessing = true;

      try {
        final rotation =
            controller!.description.lensDirection == CameraLensDirection.front
                ? InputImageRotation.rotation90deg
                : InputImageRotation.rotation270deg;

        final inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            rotation: rotation,
            format: InputImageFormat.yuv420,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final List<ImageLabel> labels =
            await _imageLabeler.processImage(inputImage);

        String detectedLighting = '';
        double confidence = 0.0;

        for (final label in labels) {
          final entity = label.label.toLowerCase();
          final currentConfidence = label.confidence;

          if (currentConfidence > confidence && _isLighting(entity)) {
            detectedLighting = entity;
            confidence = currentConfidence;
          }
        }

        if (detectedLighting.isNotEmpty &&
            detectedLighting != _lastDetectedLighting) {
          _lastDetectedLighting = detectedLighting;

          final message =
              'Detected lighting status: $detectedLighting with confidence ${(confidence * 100).toStringAsFixed(1)} percent';

          log(message);
          _voiceAssistant.speak(message);

          if (mounted) setState(() {});
        }
      } catch (e) {
        log("Image processing error: $e");
      }

      _isProcessing = false;
    });
  }

  bool _isLighting(String entity) {
    const lightingLabels = [
      'bright',
      'dark',
      'dim',
      'well-lit',
      'poorly lit',
      'overexposed',
      'underexposed',
      'shadow',
      'lighting',
      'illumination',
      'glare',
      'reflection'
    ];

    return lightingLabels.any((lighting) => entity.contains(lighting));
  }

  @override
  void dispose() {
    controller?.dispose();
    _imageLabeler.close();
    _voiceAssistant.stopListening();
    _voiceAssistant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lighting Status'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (controller != null && controller!.value.isInitialized)
            CameraPreview(controller!)
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text(
                _lastDetectedLighting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Speak: "animal", "person", "light", "color", or "help"',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
