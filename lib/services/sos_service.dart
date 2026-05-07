// lib/services/sos_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ────────────────────────────────
  // إرسال SOS
  // ────────────────────────────────
  Future<String?> sendSos({double? latitude, double? longitude}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // جلب بيانات المستخدم من Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      // إضافة document في sos_alerts
      final docRef = await _firestore.collection('sos_alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userData?['name'] ?? 'Unknown',
        'userPhone': userData?['phone'] ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active', // active / resolved
        'timestamp': FieldValue.serverTimestamp(),
      });

      return docRef.id; // نرجع الـ ID عشان نقدر نقفله بعدين
    } catch (e) {
      rethrow;
    }
  }

  // ────────────────────────────────
  // إلغاء / إغلاق SOS
  // ────────────────────────────────
  Future<void> resolveSos(String sosDocId) async {
    await _firestore.collection('sos_alerts').doc(sosDocId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ────────────────────────────────
  // الـ Guardian يستمع لـ SOS الخاص بـ User مرتبط بيه
  // ────────────────────────────────
  Stream<QuerySnapshot> listenToUserSos(String userId) {
    return _firestore
        .collection('sos_alerts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ────────────────────────────────
  // جلب بيانات الـ Guardian المرتبط بالـ User الحالي
  // ────────────────────────────────
  Future<Map<String, dynamic>?> getLinkedGuardian() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // البحث عن guardian مرتبط بالـ user ده
      final query = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'guardian')
          .where('connectedUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'linked')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return query.docs.first.data();
    } catch (e) {
      return null;
    }
  }
}
