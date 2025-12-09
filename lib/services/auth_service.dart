import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fast_flow/models/user_model.dart';
import 'package:hive/hive.dart';

class AuthService {
  AuthService._private();
  static final AuthService _instance = AuthService._private();
  factory AuthService() => _instance;

  // Boxes
  Box get _authBox => Hive.box('auth');
  Box<UserModel> get _usersBox => Hive.box<UserModel>('users');
  Box get _sessionBox => Hive.box('session');

  // ---------- Hashing ----------
  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String salt, String password) {
    final bytes = utf8.encode('$salt|$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ---------- Helpers ----------
  String _keyFromEmail(String email) => email.toLowerCase().trim();

  // ---------- Public API ----------
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    Uint8List? profileImage,
  }) async {
    final key = _keyFromEmail(email);
    if (_authBox.containsKey(key)) return false;

    final salt = _generateSalt();
    final hash = _hash(salt, password);

    await _authBox.put(key, {'salt': salt, 'hash': hash});

    final user = UserModel(
      username: username,
      email: key,
      password: '',
      profileImage: profileImage,
    );

    await _usersBox.put(key, user);
    await _sessionBox.put('last_email', key);

    return true;
  }

  Future<bool> login({required String email, required String password}) async {
    final key = _keyFromEmail(email);
    if (!_authBox.containsKey(key)) return false;

    final raw = _authBox.get(key);
    if (raw is! Map) return false;

    final salt = raw['salt'] as String?;
    final expected = raw['hash'] as String?;
    if (salt == null || expected == null) return false;

    final inputHash = _hash(salt, password);
    if (inputHash == expected) {
      await _sessionBox.put('current_user', key);
      await _sessionBox.put('last_email', key);
      await _sessionBox.put('is_logged_in', true);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _sessionBox.delete('current_user');
    await _sessionBox.delete('is_logged_in');
    // Hapus data sesi yang berhubungan dengan user
    await _clearUserSessionData();
  }

  /// Membersihkan data sesi yang tidak perlu disimpan antar login
  Future<void> _clearUserSessionData() async {
    final keysToKeep = ['last_email', 'selected_timezone'];
    final allKeys = _sessionBox.keys.toList();

    for (final key in allKeys) {
      if (!keysToKeep.contains(key)) {
        await _sessionBox.delete(key);
      }
    }
  }

  String? get currentEmail => _sessionBox.get('current_user') as String?;

  Map<String, dynamic>? getUser(String email) {
    final key = _keyFromEmail(email);
    final user = _usersBox.get(key);
    if (user == null) return null;

    return {
      'username': user.username,
      'email': user.email,
      'profile':
          user.profileImage != null ? base64Encode(user.profileImage!) : null,
    };
  }

  Future<void> updateProfile(
    String email, {
    String? username,
    Uint8List? profileImage,
  }) async {
    final key = _keyFromEmail(email);
    final user = _usersBox.get(key);
    if (user == null) return;

    final newUser = user.copyWith(
      username: username ?? user.username,
      profileImage: profileImage ?? user.profileImage,
    );

    await _usersBox.put(key, newUser);
  }

  bool exists(String email) {
    final key = _keyFromEmail(email);
    return _authBox.containsKey(key);
  }
}
