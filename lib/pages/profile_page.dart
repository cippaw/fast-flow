// lib/pages/profile_page.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'kesan_pesan_page.dart';
import 'fasting_history_page.dart';
import 'fasting_review_history_page.dart';
import '../services/auth_service.dart';
import '../pages/login_page.dart';
import '../utils/notification.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  Uint8List? _profileBytes;
  bool _loading = true;

  final picker = ImagePicker();

  // color theme (sesuai yang kamu pakai)
  final Color darkGreen = const Color(0xFF0B3D2E);
  final Color gold = const Color(0xFFD4A548);
  final Color cream = const Color(0xFFF6F0E8);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final auth = AuthService();
    final email = auth.currentEmail;
    if (email != null) {
      final userMap = auth.getUser(email);
      _nameCtrl.text = userMap?['username'] ?? '';
      _emailCtrl.text = userMap?['email'] ?? email;
      final imgBase64 = userMap?['profile'] as String?;
      if (imgBase64 != null && imgBase64.isNotEmpty) {
        try {
          _profileBytes = base64Decode(imgBase64);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _profileBytes = bytes);
  }

  Future<void> _saveChanges() async {
    final auth = AuthService();
    final email = auth.currentEmail;
    if (email == null) return;

    final newName = _nameCtrl.text.trim();
    await auth.updateProfile(
      email,
      username: newName.isEmpty ? null : newName,
      profileImage: _profileBytes,
    );

    // Optional: show notification
    try {
      await NotificationService().showNotification(
        title: "Profil Diperbarui",
        body: "Perubahan profil berhasil disimpan.",
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan disimpan')),
      );
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: darkGreen),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgProvider = _profileBytes != null
        ? MemoryImage(_profileBytes!)
        : const AssetImage('assets/images/foto_biru_pas.jpg');

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        iconTheme: IconThemeData(color: darkGreen),
        title: Text('Profil',
            style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: imgProvider as ImageProvider,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: gold,
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Name field
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        border: InputBorder.none,
                        hintText: 'Nama',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Email read-only
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _emailCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        border: InputBorder.none,
                        hintText: 'Email',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('Simpan Perubahan',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // menu links
                  _menuButton(
                    icon: Icons.menu_book_rounded,
                    label: 'Kesan & Pesan',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const KesanPesanPage())),
                  ),
                  _menuButton(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Puasa',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FastingHistoryPage())),
                  ),
                  _menuButton(
                    icon: Icons.notes_rounded,
                    label: 'Riwayat Review Puasa',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FastingReviewHistoryPage())),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
