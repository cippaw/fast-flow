import 'dart:typed_data';
import 'package:fast_flow/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  Uint8List? _profileImage;
  final picker = ImagePicker();

  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final Color _darkGreen = const Color(0xFF0B3D2E);
  final Color _lightGreen = const Color(0xFF4FB477);
  final Color _cream = const Color(0xFFF6F0E8);

  @override
  void initState() {
    super.initState();
    final session = Hive.box('session');
    _emailController = TextEditingController(
      text: session.get('last_email') ?? '',
    );
    _passwordController = TextEditingController();
    _usernameController = TextEditingController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _profileImage = bytes);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = AuthService();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    if (_isLogin) {
      final ok = await auth.login(email: email, password: password);
      if (ok) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
      } else {
        _showError('Email atau password salah!');
      }
    } else {
      final success = await auth.register(
        username: username.isEmpty ? email.split('@').first : username,
        email: email,
        password: password,
        profileImage: _profileImage,
      );

      if (!success) {
        _showError('Email sudah terdaftar!');
        return;
      }

      await auth.login(email: email, password: password);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_lightGreen, _darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _lightGreen.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mosque,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Fast Flow',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _darkGreen,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tracker Puasa Islami',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form Card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Text(
                              _isLogin ? 'Masuk Akun' : 'Daftar Akun Baru',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _darkGreen,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Profile Picture (Register only)
                            if (!_isLogin) ...[
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            _lightGreen.withOpacity(0.3),
                                            _darkGreen.withOpacity(0.1)
                                          ],
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundImage: _profileImage != null
                                            ? MemoryImage(_profileImage!)
                                            : null,
                                        backgroundColor: _cream,
                                        child: _profileImage == null
                                            ? Icon(Icons.camera_alt,
                                                size: 32,
                                                color:
                                                    _darkGreen.withOpacity(0.6))
                                            : null,
                                      ),
                                    ),
                                    if (_profileImage == null)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _lightGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.add,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ketuk untuk upload foto',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Username (Register only)
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon:
                                      Icon(Icons.person, color: _darkGreen),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: _lightGreen, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: _cream,
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon:
                                    Icon(Icons.email, color: _darkGreen),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: _lightGreen, width: 2),
                                ),
                                filled: true,
                                fillColor: _cream,
                              ),
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Email tidak valid'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock, color: _darkGreen),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: _lightGreen, width: 2),
                                ),
                                filled: true,
                                fillColor: _cream,
                              ),
                              validator: (v) => v == null || v.length < 4
                                  ? 'Minimal 4 karakter'
                                  : null,
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _darkGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                  shadowColor: _lightGreen.withOpacity(0.5),
                                ),
                                child: Text(
                                  _isLogin ? 'Masuk' : 'Daftar',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle Button
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _profileImage = null;
                                });
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                  children: [
                                    TextSpan(
                                      text: _isLogin
                                          ? 'Belum punya akun? '
                                          : 'Sudah punya akun? ',
                                    ),
                                    TextSpan(
                                      text: _isLogin ? 'Daftar' : 'Masuk',
                                      style: TextStyle(
                                        color: _lightGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
