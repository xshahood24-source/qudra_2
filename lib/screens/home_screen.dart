// lib/screens/home_screen.dart
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/language_service.dart';
import '../services/voice_assistant_service.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ─── Camera ───
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;

  // ─── TTS ───
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  // ─── ML Kit ───
  ObjectDetector? _objectDetector;
  ImageLabeler? _imageLabeler;

  // ─── State ───
  bool _isAnalyzing = false;
  String _lastDescription = '';

  // ─── Services ───
  final LanguageService _langService = LanguageService();
  final VoiceAssistantService _voiceAssistant =
      VoiceAssistantService(); // تعريف المساعد الصوتي

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _langService.addListener(_onLanguageChanged);
    _initAll();
  }

  Future<void> _initAll() async {
    await _langService.loadLanguage();
    await _initTts();
    _initMLKit();
    await _initCamera();

    // تفعيل المساعد الصوتي فور فتح الشاشة
    await _voiceAssistant.init();
    await _voiceAssistant.speak(_getWelcomeMessage());
    _voiceAssistant.startListening();
  }

  // ─── TTS Setup ───
  Future<void> _initTts() async {
    await _tts.setLanguage(_langService.languageCode);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setErrorHandler((_) => setState(() => _isSpeaking = false));
  }

  void _onLanguageChanged() {
    _tts.setLanguage(_langService.languageCode);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    setState(() {
      _isSpeaking = true;
      _lastDescription = text;
    });
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  // ─── ML Kit Setup ───
  void _initMLKit() {
    final objectOptions = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: objectOptions);

    final labelerOptions = ImageLabelerOptions(confidenceThreshold: 0.6);
    _imageLabeler = ImageLabeler(options: labelerOptions);
  }

  // ─── Camera Setup ───
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      log('Camera init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─── الوظيفة الرئيسية: التقاط + تحليل ───
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    await _speak(_getAnalyzingMessage());

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final results = await Future.wait([
        _detectObjects(inputImage),
        _labelImage(inputImage),
        _detectLight(imageFile.path),
        _detectColors(imageFile.path),
      ]);

      final String objects = results[0];
      final String labels = results[1];
      final String light = results[2];
      final String colors = results[3];

      final description = _buildDescription(
        objects: objects,
        labels: labels,
        light: light,
        colors: colors,
      );

      await _speak(description);

      if (mounted) _showResultSheet(description, light, colors, objects);
    } catch (e) {
      log('Analysis error: $e');
      await _speak(_getErrorMessage());
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // (دوال ML Kit و Light و Color Detection تبقى كما هي دون تغيير)
  Future<String> _detectObjects(InputImage image) async {
    try {
      final objects = await _objectDetector!.processImage(image);
      if (objects.isEmpty) return '';
      final names = objects
          .where((o) => o.labels.isNotEmpty)
          .map((o) {
            final topLabel =
                o.labels.reduce((a, b) => a.confidence > b.confidence ? a : b);
            return topLabel.text;
          })
          .toSet()
          .take(5)
          .join(', ');
      return names;
    } catch (e) {
      return '';
    }
  }

  Future<String> _labelImage(InputImage image) async {
    try {
      final labels = await _imageLabeler!.processImage(image);
      if (labels.isEmpty) return '';
      final topLabels = labels
          .where((l) => l.confidence > 0.65)
          .take(5)
          .map((l) => l.label)
          .join(', ');
      return topLabels;
    } catch (e) {
      return '';
    }
  }

  Future<String> _detectLight(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      int totalBrightness = 0;
      int sampleCount = 0;
      for (int i = 0; i < bytes.length - 3; i += 100) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        totalBrightness += ((0.299 * r) + (0.587 * g) + (0.114 * b)).round();
        sampleCount++;
      }
      if (sampleCount == 0) return 'Unknown light';
      final avgBrightness = totalBrightness / sampleCount;
      if (avgBrightness < 50) return 'Very dark';
      if (avgBrightness < 100) return 'Dark';
      if (avgBrightness < 150) return 'Dim light';
      if (avgBrightness < 200) return 'Normal light';
      if (avgBrightness < 230) return 'Bright';
      return 'Very bright';
    } catch (e) {
      return 'Unknown light';
    }
  }

  Future<String> _detectColors(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final Map<String, int> colorCount = {};
      int sampleCount = 0;
      for (int i = 0; i < bytes.length - 3; i += 200) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        final colorName = _rgbToColorName(r, g, b);
        colorCount[colorName] = (colorCount[colorName] ?? 0) + 1;
        sampleCount++;
      }
      if (sampleCount == 0) return '';
      final sorted = colorCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(3).map((e) => e.key).join(', ');
    } catch (e) {
      return '';
    }
  }

  String _rgbToColorName(int r, int g, int b) {
    if (r > 200 && g > 200 && b > 200) return 'white';
    if (r < 50 && g < 50 && b < 50) return 'black';
    if (r > 150 && g < 80 && b < 80) return 'red';
    if (r < 80 && g > 150 && b < 80) return 'green';
    if (r < 80 && g < 80 && b > 150) return 'blue';
    if (r > 150 && g > 150 && b < 80) return 'yellow';
    if (r > 150 && g < 80 && b > 150) return 'purple';
    if (r > 180 && g > 100 && b < 80) return 'orange';
    if (r > 120 && g > 80 && b < 50) return 'brown';
    if (r > 150 && g > 150 && b > 150) return 'gray';
    if (r > 100 && g > 150 && b > 150) return 'teal';
    return 'mixed';
  }

  String _buildDescription(
      {required String objects,
      required String labels,
      required String light,
      required String colors}) {
    final lang = _langService.languageCode;
    final isArabic = lang.startsWith('ar');
    final List<String> parts = [];
    if (light.isNotEmpty)
      parts.add(isArabic ? 'الإضاءة: $light' : 'Lighting: $light.');
    if (objects.isNotEmpty)
      parts.add(
          isArabic ? 'الأجسام المكتشفة: $objects' : 'I can see: $objects.');
    if (labels.isNotEmpty && labels != objects)
      parts.add(isArabic
          ? 'يحتوي المشهد على: $labels'
          : 'The scene contains: $labels.');
    if (colors.isNotEmpty)
      parts.add(
          isArabic ? 'الألوان السائدة: $colors' : 'Dominant colors: $colors.');
    if (parts.isEmpty)
      return isArabic
          ? 'لم أتمكن من تحديد محتوى الصورة بوضوح.'
          : 'I could not clearly identify the scene.';
    return parts.join(' ');
  }

  String _getWelcomeMessage() {
    final lang = _langService.languageCode;
    if (lang.startsWith('ar')) return 'مرحباً. اضغط زر الكاميرا لتحليل المشهد.';
    return 'Welcome. Press the camera button to analyze the scene.';
  }

  String _getAnalyzingMessage() {
    final lang = _langService.languageCode;
    if (lang.startsWith('ar')) return 'جارٍ التحليل، الرجاء الانتظار.';
    return 'Analyzing the scene, please wait.';
  }

  String _getErrorMessage() {
    final lang = _langService.languageCode;
    if (lang.startsWith('ar')) return 'حدث خطأ أثناء التحليل. حاول مرة أخرى.';
    return 'An error occurred. Please try again.';
  }

  void _showResultSheet(
      String description, String light, String colors, String objects) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.visibility, color: Color(0xFF2D5357), size: 22),
              const SizedBox(width: 10),
              const Text('Scene Analysis',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5357))),
              const Spacer(),
              IconButton(
                  onPressed: () => _speak(description),
                  icon: const Icon(Icons.volume_up,
                      color: Color(0xFF2D5357), size: 22)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 22)),
            ]),
            const Divider(),
            const SizedBox(height: 8),
            if (light.isNotEmpty) _resultRow(Icons.light_mode, 'Light', light),
            if (colors.isNotEmpty) _resultRow(Icons.palette, 'Colors', colors),
            if (objects.isNotEmpty)
              _resultRow(Icons.category, 'Objects', objects),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F7),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(description,
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2D5357)),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _langService.removeListener(_onLanguageChanged);
    _cameraController?.dispose();
    _objectDetector?.close();
    _imageLabeler?.close();
    _tts.stop();
    _voiceAssistant.dispose(); // إغلاق المساعد الصوتي
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera Preview ───
          Positioned.fill(
            child: _cameraReady && _cameraController != null
                ? CameraPreview(_cameraController!)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('Initializing camera...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
          ),

          // ─── Top Bar (بدون زر اللغة) ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isAnalyzing || _isSpeaking
                          ? Container(
                              key: const ValueKey('active'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isAnalyzing
                                    ? Colors.orange.withOpacity(0.85)
                                    : const Color(0xFF2D5357).withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(children: [
                                const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)),
                                const SizedBox(width: 6),
                                Text(
                                    _isAnalyzing
                                        ? 'Analyzing...'
                                        : 'Speaking...',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ]),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_isSpeaking)
                      GestureDetector(
                        onTap: _stopSpeaking,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.volume_off,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Last Description Overlay ───
          if (_lastDescription.isNotEmpty)
            Positioned(
              bottom: 160,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12)),
                child: Text(_lastDescription,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.5),
                    maxLines: 3,
                    textAlign: TextAlign.center),
              ),
            ),

          // ─── Bottom Buttons ───
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSideButton(
                      icon: Icons.sos_rounded,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SOSScreen())),
                      tooltip: 'SOS'),
                  GestureDetector(
                    onTap: (_isAnalyzing || !_cameraReady)
                        ? null
                        : _captureAndAnalyze,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isAnalyzing ? 90 : 85,
                      height: _isAnalyzing ? 90 : 85,
                      decoration: BoxDecoration(
                        color: _isAnalyzing
                            ? Colors.orange.shade100
                            : const Color(0xFFE0F7F7),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _isAnalyzing ? Colors.orange : Colors.white,
                            width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: (_isAnalyzing
                                      ? Colors.orange
                                      : const Color(0xFF2D5357))
                                  .withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 3)
                        ],
                      ),
                      child: _isAnalyzing
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.orange, strokeWidth: 3))
                          : const Icon(Icons.camera_alt,
                              size: 42, color: Color(0xFF2D5357)),
                    ),
                  ),
                  _buildSideButton(
                      icon: Icons.settings,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                      tooltip: 'Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideButton(
      {required IconData icon,
      required VoidCallback onTap,
      required String tooltip}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]),
        child: Icon(icon, size: 30, color: const Color(0xFF2D5357)),
      ),
    );
  }
}
