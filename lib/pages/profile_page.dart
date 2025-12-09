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

  // Enhanced color theme
  final Color darkGreen = const Color(0xFF0B3D2E);
  final Color lightGreen = const Color(0xFF4FB477);
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

    try {
      await NotificationService().showNotification(
        title: "Profil Diperbarui ✓",
        body: "Perubahan profil berhasil disimpan.",
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Perubahan berhasil disimpan'),
          backgroundColor: lightGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (r) => false,
      );
    }
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? darkGreen).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor ?? darkGreen, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: darkGreen,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
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
        : const AssetImage('assets/images/default_profile.png');

    return Scaffold(
      backgroundColor: cream,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: darkGreen),
            )
          : CustomScrollView(
              slivers: [
                // Enhanced App Bar with gradient
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: darkGreen,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Profil Saya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [darkGreen, lightGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Profile Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Profile Picture
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [lightGreen, darkGreen],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: lightGreen.withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: CircleAvatar(
                                      radius: 56,
                                      backgroundImage:
                                          imgProvider as ImageProvider,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: gold,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Name field
                            Container(
                              decoration: BoxDecoration(
                                color: cream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _nameCtrl,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: darkGreen,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      Icon(Icons.person, color: darkGreen),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'Nama',
                                  filled: true,
                                  fillColor: cream,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email read-only
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _emailCtrl,
                                readOnly: true,
                                style: TextStyle(color: Colors.grey[600]),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.email,
                                      color: Colors.grey[600]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'Email',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _saveChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Menu links
                      _menuButton(
                        icon: Icons.calendar_month_rounded,
                        label: 'Riwayat Puasa',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FastingHistoryPage()),
                        ),
                        iconColor: lightGreen,
                      ),
                      _menuButton(
                        icon: Icons.rate_review_rounded,
                        label: 'Riwayat Review Puasa',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FastingReviewHistoryPage()),
                        ),
                        iconColor: gold,
                      ),
                      _menuButton(
                        icon: Icons.message_rounded,
                        label: 'Kesan & Pesan',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KesanPesanPage()),
                        ),
                        iconColor: Colors.blue,
                      ),

                      const SizedBox(height: 32),

                      // Logout button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade600,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _logout,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.logout, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
