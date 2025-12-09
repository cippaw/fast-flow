import 'package:fast_flow/utils/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionRequestDialog extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionRequestDialog({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionRequestDialog> createState() =>
      _PermissionRequestDialogState();
}

class _PermissionRequestDialogState extends State<PermissionRequestDialog> {
  bool _requestingPermissions = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final permissionHandler = PermissionHandler();

    final notif =
        await permissionHandler.requestNotificationPermission(context);
    final loc = await permissionHandler.requestLocationPermission(context);
    final storage = await permissionHandler.requestStoragePermission(context);

    if (!mounted) return;

    setState(() => _requestingPermissions = false);

    if (notif || loc || storage) {
      widget.onPermissionsGranted();
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _requestingPermissions
          ? const CircularProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
