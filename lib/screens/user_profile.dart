// lib/screens/user_profile.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  // ─── Controllers ───
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // ─── State ───
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─── جيب البيانات من Firestore ───
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _errorMessage = 'No user logged in');
        return;
      }

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        setState(() => _errorMessage = 'User data not found');
        return;
      }

      final data = doc.data()!;
      setState(() {
        _userData = data;
        // حشو الـ controllers بالبيانات الحالية
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── حفظ التعديلات في Firestore ───
  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Name cannot be empty', isError: true);
      return;
    }
    if (phone.isEmpty) {
      _showSnackBar('Phone cannot be empty', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // حدّث الـ local state
      setState(() {
        _userData?['name'] = name;
        _userData?['phone'] = phone;
        _isEditing = false;
      });

      _showSnackBar('Profile updated successfully! ✅');
    } catch (e) {
      _showSnackBar('Error saving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── إلغاء التعديل ───
  void _cancelEdit() {
    _nameController.text = _userData?['name'] ?? '';
    _phoneController.text = _userData?['phone'] ?? '';
    setState(() => _isEditing = false);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF2D5357),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2D5357)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserData,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5357)),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final name = _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? '';
    final phone = _userData?['phone'] ?? '';
    final role = _userData?['role'] ?? 'user';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header ───
            _buildHeader(name, role),

            const SizedBox(height: 24),

            // ─── Info Card ───
            _buildInfoCard(email: email, phone: phone, name: name),

            const SizedBox(height: 16),

            // ─── Edit / Save Buttons ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:
                  _isEditing ? _buildSaveCancelButtons() : _buildEditButton(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'My Profile',
        style: TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(10.0),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26, width: 1.2),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
          ),
        ),
      ),
    );
  }

  // ─── Header Section ───
  Widget _buildHeader(String name, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF2D5357),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          // Avatar دائري باللون والحرف الأول
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role[0].toUpperCase() + role.substring(1), // "User"
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Info Card ───
  Widget _buildInfoCard({
    required String email,
    required String phone,
    required String name,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── Title ───
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      color: Color(0xFF2D5357), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // Email — دايمًا read-only مش ممكن تغييره
            _buildReadOnlyField(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
              note: 'Cannot be changed',
            ),
            const Divider(
                height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),

            // Name — editable
            _isEditing
                ? _buildEditableField(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    controller: _nameController,
                  )
                : _buildReadOnlyField(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    value: name,
                  ),
            const Divider(
                height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),

            // Phone — editable
            _isEditing
                ? _buildEditableField(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  )
                : _buildReadOnlyField(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: phone,
                  ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Read-only Field ───
  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
    String? note,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2D5357)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Editable Field ───
  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2D5357)),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2D5357), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Button ───
  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
              fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D5357),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Save / Cancel Buttons ───
  Widget _buildSaveCancelButtons() {
    return Row(
      children: [
        // Cancel
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEdit,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5357),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
