// lib/screens/currency_detection_screen.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/voice_assistant_service.dart';

class CurrencyDetectionScreen extends StatefulWidget {
  const CurrencyDetectionScreen({super.key});

  @override
  State<CurrencyDetectionScreen> createState() =>
      _CurrencyDetectionScreenState();
}

class _CurrencyDetectionScreenState extends State<CurrencyDetectionScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;

  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  String _lastDetectedCurrency = 'No currency detected yet.';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _voiceAssistant.init();
    _voiceAssistant.startListening();
  }

  Future<void> _initializeCamera() async {
    try {
      log("Initializing camera for Currency Detection...");
      cameras = await availableCameras();

      if (cameras != null && cameras!.isNotEmpty) {
        controller = CameraController(cameras![0], ResolutionPreset.medium);
        await controller!.initialize();
        _startImageStream();
        if (mounted) setState(() {});
      }
    } catch (e) {
      log("Error initializing camera: $e");
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
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.yuv420,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final List<ImageLabel> labels =
            await _imageLabeler.processImage(inputImage);

        String detectedCurrency = '';
        double confidence = 0.0;

        for (final label in labels) {
          final entity = label.label.toLowerCase();
          final currentConfidence = label.confidence;

          if (currentConfidence > confidence && _isCurrency(entity)) {
            detectedCurrency = entity;
            confidence = currentConfidence;
          }
        }

        if (detectedCurrency.isNotEmpty &&
            detectedCurrency != _lastDetectedCurrency) {
          _lastDetectedCurrency = detectedCurrency;
          final message =
              'Detected $detectedCurrency with confidence ${(confidence * 100).toStringAsFixed(1)}%';
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

  bool _isCurrency(String entity) {
    const currencyLabels = [
      'money',
      'paper money',
      'coin',
      'dollar bill',
      'euro',
      'pound',
      'rial',
      'yen',
      'rupee',
      'franc',
      'peso',
      'koruna',
      'baht',
      'dong',
      'won',
      'yuan',
      'lira',
      'shekel',
      'dirham',
      'riyal',
      'krona',
      'rand',
      'cedi',
      'shilling',
      'nakfa',
      'birr',
      'kyat',
      'riel',
      'kip',
      'tugrik',
      'som',
      'somoni',
      'manat',
      'tenge',
      'rubel',
      'hryvnia',
      'forint',
      'zloty',
      'lev',
      'denar',
      'lek',
      'dram',
      'tetri',
      'lari',
      'afghani',
      'taka'
    ];
    return currencyLabels.any((currency) => entity.contains(currency));
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
        title: const Text('Currency Detection'),
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
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _lastDetectedCurrency,
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                'Speak: "animal", "person", "money", or "help"',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
