// lib/screens/people_detection_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/voice_assistant_service.dart';

class PeopleDetectionScreen extends StatefulWidget {
  const PeopleDetectionScreen({super.key});

  @override
  State<PeopleDetectionScreen> createState() => _PeopleDetectionScreenState();
}

class _PeopleDetectionScreenState extends State<PeopleDetectionScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;

  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();

  String _lastDetectedPerson = 'No person detected yet.';
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
      if (cameras != null && cameras!.isNotEmpty) {
        controller = CameraController(
          cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller!.initialize();
        _startImageStream();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
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

        String detectedPerson = '';
        double confidence = 0.0;

        for (final label in labels) {
          final entity = label.label.toLowerCase();
          if (_isPerson(entity) && label.confidence > confidence) {
            detectedPerson = entity;
            confidence = label.confidence;
          }
        }

        if (detectedPerson.isNotEmpty &&
            detectedPerson != _lastDetectedPerson) {
          _lastDetectedPerson = detectedPerson;

          final message =
              'Detected $detectedPerson with confidence ${(confidence * 100).toStringAsFixed(1)} percent';

          _voiceAssistant.speak(message);
          setState(() {});
        }
      } catch (e) {
        debugPrint('Image processing error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  bool _isPerson(String entity) {
    const peopleLabels = [
      'person',
      'human',
      'man',
      'woman',
      'child',
      'boy',
      'girl',
      'adult',
      'elderly',
      'baby',
      'face',
      'head',
      'body',
    ];
    return peopleLabels.any((p) => entity.contains(p));
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
        title: const Text('People Detection'),
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
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text(
                _lastDetectedPerson,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Camera is analyzing people around you',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
