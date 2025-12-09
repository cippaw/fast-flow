import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String email;

  @HiveField(2)
  String password;

  @HiveField(3)
  Uint8List? profileImage;

  UserModel({
    required this.username,
    required this.email,
    required this.password,
    this.profileImage,
  });

  UserModel copyWith({
    String? username,
    String? email,
    String? password,
    Uint8List? profileImage,
  }) {
    return UserModel(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}
