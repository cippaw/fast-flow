import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionHandler {
  static final PermissionHandler _instance = PermissionHandler._internal();
  factory PermissionHandler() => _instance;
  PermissionHandler._internal();

  Future<bool> requestNotificationPermission(BuildContext context) async {
    final status = await ph.Permission.notification.request();
    return _handleStatus(
      context,
      status,
      title: "Izin Notifikasi Diperlukan",
      message:
          "Aplikasi memerlukan izin notifikasi untuk pengingat waktu ibadah.",
    );
  }

  Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await ph.Permission.location.request();
    return _handleStatus(
      context,
      status,
      title: "Izin Lokasi Diperlukan",
      message:
          "Aplikasi memerlukan lokasi untuk menampilkan jadwal sholat yang akurat.",
    );
  }

  Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await ph.Permission.storage.request();
    return _handleStatus(
      context,
      status,
      title: "Izin Penyimpanan Diperlukan",
      message:
          "Aplikasi memerlukan akses penyimpanan untuk upload dan download file.",
    );
  }

  Future<bool> _handleStatus(
    BuildContext context,
    ph.PermissionStatus status, {
    required String title,
    required String message,
  }) async {
    if (status.isGranted) return true;

    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          title: title,
          message: message,
          onSettings: () => ph.openAppSettings(),
        );
      }
      return false;
    }
    return false;
  }

  void _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onSettings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSettings?.call();
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }
}
