// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ────────────────────────────────
  // مراقبة حالة المستخدم (stream)
  // ────────────────────────────────
  Stream<User?> get userStream => _auth.authStateChanges();

  // المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // ────────────────────────────────
  // تسجيل حساب جديد
  // ────────────────────────────────
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role, // 'user' أو 'guardian'
  }) async {
    try {
      // 1. إنشاء الحساب في Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. تخزين بيانات المستخدم في Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        // Guardian fields (فاضيين في البداية)
        'connectedUserId': null,
        'connectedUserEmail': null,
        'status': 'pending',
      });

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ────────────────────────────────
  // تسجيل دخول
  // ────────────────────────────────
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ────────────────────────────────
  // تسجيل دخول بـ Google
  // ────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // المستخدم ضغط cancel

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // لو مستخدم جديد، احفظ بياناته في Firestore
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': userCredential.user!.displayName ?? '',
          'email': userCredential.user!.email ?? '',
          'phone': '',
          'role': 'user', // default role للـ Google Sign In
          'createdAt': FieldValue.serverTimestamp(),
          'connectedUserId': null,
          'connectedUserEmail': null,
          'status': 'pending',
        });
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // ────────────────────────────────
  // إعادة تعيين كلمة المرور
  // ────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ────────────────────────────────
  // تسجيل خروج
  // ────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ────────────────────────────────
  // جلب بيانات المستخدم من Firestore
  // ────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────
  // ترجمة أخطاء Firebase لرسائل واضحة
  // ────────────────────────────────
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
