// lib/screens/sos_screen.dart
import 'package:flutter/material.dart';
import 'package:qudra_2/services/sos_service.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final SosService _sosService = SosService();

  bool _isSending = false;
  bool _sosSent = false;
  String? _activeSosId;
  Map<String, dynamic>? _guardianData;

  @override
  void initState() {
    super.initState();
    _loadGuardianData();
  }

  Future<void> _loadGuardianData() async {
    final guardian = await _sosService.getLinkedGuardian();
    if (mounted) setState(() => _guardianData = guardian);
  }

  Future<void> _handleSos() async {
    if (_sosSent && _activeSosId != null) {
      await _cancelSos();
      return;
    }

    setState(() => _isSending = true);

    try {
      final sosId = await _sosService.sendSos();

      if (mounted) {
        setState(() {
          _sosSent = true;
          _activeSosId = sosId;
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('🚨 SOS sent! Your guardian has been notified.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _cancelSos() async {
    if (_activeSosId == null) return;

    try {
      await _sosService.resolveSos(_activeSosId!);
      if (mounted) {
        setState(() {
          _sosSent = false;
          _activeSosId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS cancelled.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling SOS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Emergency SOS",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              _sosSent ? "SOS Alert Active!" : "Are you in an emergency?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _sosSent ? Colors.red : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _sosSent
                  ? "Your guardian has been notified. Tap to cancel."
                  : "Press the button below to alert your guardian.",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Spacer(),

            // SOS Button
            GestureDetector(
              onTap: _isSending ? null : _handleSos,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: _sosSent
                      ? Colors.red.shade100
                      : Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _sosSent
                        ? Colors.red.shade300
                        : Colors.red.shade100,
                    width: 10,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: _sosSent
                          ? Colors.red.shade700
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent
                              .withOpacity(_sosSent ? 0.6 : 0.3),
                          blurRadius: _sosSent ? 30 : 20,
                          spreadRadius: _sosSent ? 5 : 2,
                        )
                      ],
                    ),
                    child: Center(
                      child: _isSending
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              _sosSent ? "CANCEL" : "SOS",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Guardian Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2D5357),
                    child: Icon(Icons.shield, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Guardian",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _guardianData != null
                              ? "${_guardianData!['name'] ?? 'Guardian'} • ${_guardianData!['phone'] ?? ''}"
                              : "No guardian linked yet",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
