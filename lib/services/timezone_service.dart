// lib/services/timezone_service.dart
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

/// Service untuk mengelola timezone secara global di aplikasi
class TimezoneService {
  static final TimezoneService _instance = TimezoneService._internal();
  factory TimezoneService() => _instance;
  TimezoneService._internal();

  // Map zona waktu yang tersedia
  static const Map<String, String> zoneMap = {
    'WIB (Asia/Jakarta)': 'Asia/Jakarta',
    'WITA (Asia/Makassar)': 'Asia/Makassar',
    'WIT (Asia/Jayapura)': 'Asia/Jayapura',
    'London (Europe/London)': 'Europe/London',
  };

  /// Mendapatkan zona waktu yang dipilih saat ini
  String getSelectedZone() {
    try {
      final box = Hive.box('session');
      final saved = box.get('selected_timezone') as String?;
      if (saved != null && zoneMap.containsKey(saved)) {
        return saved;
      }
    } catch (_) {}
    return 'WIB (Asia/Jakarta)'; // default
  }

  /// Menyimpan zona waktu yang dipilih
  Future<void> setSelectedZone(String zoneLabel) async {
    try {
      if (!zoneMap.containsKey(zoneLabel)) return;
      final box = Hive.box('session');
      await box.put('selected_timezone', zoneLabel);
    } catch (_) {}
  }

  /// Mendapatkan timezone name (e.g., 'Asia/Jakarta')
  String getSelectedTimezoneName() {
    final label = getSelectedZone();
    return zoneMap[label] ?? 'Asia/Jakarta';
  }

  /// Convert waktu dari Jakarta (sumber default Aladhan) ke zona terpilih
  /// timeStr format: "04:26" atau "04:26 ( +07 )"
  String convertTimeFromJakarta(String timeStr, DateTime referenceDate) {
    try {
      // Extract HH:mm dari string
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
      if (match == null) return timeStr;

      final hhmm = match.group(1)! + ':' + match.group(2)!;
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);

      // Buat TZDateTime di Jakarta
      final srcLoc = tz.getLocation('Asia/Jakarta');
      final srcTzDt = tz.TZDateTime(
        srcLoc,
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        h,
        m,
      );

      // Convert ke zona terpilih
      final targetTzName = getSelectedTimezoneName();
      final destLoc = tz.getLocation(targetTzName);
      final destTzDt = tz.TZDateTime.from(srcTzDt.toUtc(), destLoc);

      return DateFormat('HH:mm').format(destTzDt);
    } catch (e) {
      return timeStr;
    }
  }

  /// Convert waktu maghrib dari Jakarta ke zona terpilih dan return DateTime UTC
  DateTime? convertMaghribToTargetZone(String maghribTime, DateTime today) {
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(maghribTime);
      if (match == null) return null;

      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);

      // Maghrib di Jakarta
      final srcLoc = tz.getLocation('Asia/Jakarta');
      final maghribJakarta = tz.TZDateTime(
        srcLoc,
        today.year,
        today.month,
        today.day,
        h,
        m,
      );

      // Return UTC instant
      return maghribJakarta.toUtc();
    } catch (e) {
      return null;
    }
  }

  /// Format waktu maghrib untuk zona terpilih
  String formatMaghribForSelectedZone(DateTime targetUtc) {
    try {
      final destLoc = tz.getLocation(getSelectedTimezoneName());
      final destDt = tz.TZDateTime.from(targetUtc, destLoc);
      return DateFormat('HH:mm').format(destDt);
    } catch (_) {
      return '--:--';
    }
  }
}
