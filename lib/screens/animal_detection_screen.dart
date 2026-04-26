// lib/screens/animal_detection_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../services/voice_assistant_service.dart';

class AnimalDetectionScreen extends StatefulWidget {
  const AnimalDetectionScreen({super.key});

  @override
  State<AnimalDetectionScreen> createState() => _AnimalDetectionScreenState();
}

class _AnimalDetectionScreenState extends State<AnimalDetectionScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;

  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(
      confidenceThreshold: 0.5,
    ),
  );

  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();

  String _lastDetectedAnimal = 'No animal detected yet.';
  bool _isProcessing = false; // لمنع المعالجة المتكررة

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _voiceAssistant.initialize();
    _voiceAssistant.startListening();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) return;

      controller = CameraController(
        cameras![0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();
      _startImageStream();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startImageStream() {
    controller?.startImageStream((CameraImage image) async {
      if (_isProcessing || !mounted) return;
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

        String detectedAnimal = '';
        double confidence = 0.0;

        for (final label in labels) {
          final name = label.label.toLowerCase();
          if (_isAnimal(name) && label.confidence > confidence) {
            detectedAnimal = name;
            confidence = label.confidence;
          }
        }

        if (detectedAnimal.isNotEmpty &&
            detectedAnimal != _lastDetectedAnimal) {
          _lastDetectedAnimal = detectedAnimal;

          final message =
              'Detected $detectedAnimal with confidence ${(confidence * 100).toStringAsFixed(1)} percent';

          _voiceAssistant.speak(message);

          if (mounted) {
            setState(() {});
          }
        }
      } catch (e) {
        debugPrint('Detection error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  bool _isAnimal(String entity) {
    const animals = [
      'dog',
      'cat',
      'bird',
      'fish',
      'horse',
      'cow',
      'sheep',
      'pig',
      'chicken',
      'duck',
      'goat',
      'rabbit',
      'elephant',
      'lion',
      'tiger',
      'bear',
      'monkey',
      'zebra',
      'giraffe',
      'deer',
      'fox',
      'wolf',
      'kangaroo',
      'panda',
      'koala',
      'camel',
      'donkey',
      'owl',
      'eagle',
      'parrot',
      'snake',
      'frog',
      'turtle',
      'butterfly',
      'bee'
    ];

    return animals.any((animal) => entity.contains(animal));
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
        title: const Text('Animal Detection'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (controller != null && controller!.value.isInitialized)
            CameraPreview(controller!)
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(12),
              child: Text(
                _lastDetectedAnimal,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
