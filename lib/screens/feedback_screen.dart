// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  double _userRating = 0;
  final TextEditingController _feedbackController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a rating first")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      String uid = user?.uid ?? "anonymous";
      String email = user?.email ?? "anonymous";

      // بنحفظ الـ feedback في collection خاصة بـ admin يقدر يشوفها
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'guardian_id': uid,
        'guardian_email': email,
        'rating': _userRating,
        'message': _feedbackController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new', // admin يقدر يفلتر الجديدة
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thank you for your feedback! ⭐"),
            backgroundColor: Color(0xFF2D5357),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Feedback',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "How did we do?",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your feedback helps us improve the experience",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding:
                  const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Color(0xFFFFB800),
              ),
              unratedColor: Colors.grey.shade300,
              onRatingUpdate: (rating) {
                setState(() => _userRating = rating);
              },
            ),
            const SizedBox(height: 10),
            if (_userRating > 0)
              Text(
                _getRatingLabel(_userRating),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2D5357),
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 40),
            const Divider(thickness: 1),
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: const TextSpan(
                  text: 'Tell us more...',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                  children: [
                    TextSpan(
                      text: ' (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _feedbackController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Share your experience with us...',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF2F2F2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF234F52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        "Submit Feedback",
                        style: TextStyle(
                            fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(double rating) {
    if (rating <= 1) return '😞 Poor';
    if (rating <= 2) return '😐 Fair';
    if (rating <= 3) return '🙂 Good';
    if (rating <= 4) return '😊 Very Good';
    return '🤩 Excellent!';
  }
}
