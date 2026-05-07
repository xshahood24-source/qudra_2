// lib/screens/guard_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'feedback_screen.dart';
import 'select_role_screen.dart';

class GuardProfile extends StatefulWidget {
  const GuardProfile({super.key});

  @override
  State<GuardProfile> createState() => _GuardProfileState();
}

class _GuardProfileState extends State<GuardProfile> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _guardianData;
  Map<String, dynamic>? _linkedUserData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  File? _pickedImageFile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

      final guardianDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!guardianDoc.exists) {
        setState(() => _errorMessage = 'Guardian data not found');
        return;
      }

      final data = guardianDoc.data()!;
      setState(() {
        _guardianData = data;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      });

      final connectedUserId = data['connectedUserId'];
      if (connectedUserId != null && connectedUserId.toString().isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(connectedUserId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() => _linkedUserData = userDoc.data());
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── اختيار صورة ───
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (picked == null) return;
      setState(() => _pickedImageFile = File(picked.path));
      await _uploadImage();
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedImageFile == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');

      await ref.putFile(_pickedImageFile!);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': downloadUrl});

      setState(() => _guardianData?['photoUrl'] = downloadUrl);
      _showSnackBar('Profile photo updated! ✅');
    } catch (e) {
      _showSnackBar('Error uploading: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _removePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isUploadingImage = true);
    try {
      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_images/$uid.jpg')
            .delete();
      } catch (_) {}
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': FieldValue.delete()});
      setState(() {
        _guardianData?.remove('photoUrl');
        _pickedImageFile = null;
      });
      _showSnackBar('Photo removed');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Change Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_guardianData?['photoUrl'] != null) ...[
                const SizedBox(height: 10),
                _sheetOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? const Color(0xFF2D5357);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }

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
      setState(() {
        _guardianData?['name'] = name;
        _guardianData?['phone'] = phone;
        _isEditing = false;
      });
      _showSnackBar('Profile updated! ✅');
    } catch (e) {
      _showSnackBar('Error saving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEdit() {
    _nameController.text = _guardianData?['name'] ?? '';
    _phoneController.text = _guardianData?['phone'] ?? '';
    setState(() => _isEditing = false);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SelectRoleScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF2D5357),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF2D5357))),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5357)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    final name = _guardianData?['name'] ?? 'Guardian';
    final email = _guardianData?['email'] ?? '';
    final phone = _guardianData?['phone'] ?? '';
    final photoUrl = _guardianData?['photoUrl'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(name: name, photoUrl: photoUrl),
              const SizedBox(height: 24),
              _buildGuardianCard(email: email, name: name, phone: phone),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child:
                    _isEditing ? _buildSaveCancelButtons() : _buildEditButton(),
              ),
              const SizedBox(height: 16),
              _buildLinkedUserCard(),
              const SizedBox(height: 16),
              _buildActions(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required String name, String? photoUrl}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF2D5357),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white60, width: 3),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: ClipOval(
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : _pickedImageFile != null
                          ? Image.file(_pickedImageFile!,
                              fit: BoxFit.cover, width: 100, height: 100)
                          : photoUrl != null
                              ? Image.network(photoUrl,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (_, __, ___) =>
                                      _fallbackAvatar(name))
                              : _fallbackAvatar(name),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _showImageSourceSheet,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF2D5357), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Color(0xFF2D5357)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(name,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Guardian',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String name) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'G',
          style: const TextStyle(
              fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );

  Widget _buildGuardianCard({
    required String email,
    required String name,
    required String phone,
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
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(children: [
                Icon(Icons.person_outline, color: Color(0xFF2D5357), size: 22),
                SizedBox(width: 10),
                Text('My Information',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _buildReadOnlyField(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
                note: 'Cannot be changed'),
            const Divider(
                height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
            _isEditing
                ? _buildEditableField(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    controller: _nameController)
                : _buildReadOnlyField(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    value: name),
            const Divider(
                height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
            _isEditing
                ? _buildEditableField(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone)
                : _buildReadOnlyField(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: phone),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedUserCard() {
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
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(children: [
                Icon(Icons.link, color: Color(0xFF2D5357), size: 22),
                SizedBox(width: 10),
                Text('Linked User',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            if (_linkedUserData != null) ...[
              _buildReadOnlyField(
                  icon: Icons.person,
                  label: 'Name',
                  value: _linkedUserData!['name'] ?? '—'),
              const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFF0F0F0)),
              _buildReadOnlyField(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: _linkedUserData!['phone'] ?? '—'),
              const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFF0F0F0)),
              _buildReadOnlyField(
                  icon: Icons.circle,
                  label: 'Status',
                  value: 'Connected ✅',
                  valueColor: Colors.green),
            ] else
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade400, size: 22),
                  const SizedBox(width: 12),
                  const Text('No user linked yet',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ]),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              ),
              icon:
                  const Icon(Icons.star_outline, color: Colors.white, size: 20),
              label: const Text('Give Feedback',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5357),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red, size: 20),
              label: const Text('Logout',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
    String? note,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: const Color(0xFF2D5357)),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value.isEmpty ? '—' : value,
                style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600)),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
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
      ]),
    );
  }

  Widget _buildEditButton() => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
          label: const Text('Edit Profile',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5357),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
        ),
      );

  Widget _buildSaveCancelButtons() => Row(children: [
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
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]);
}
