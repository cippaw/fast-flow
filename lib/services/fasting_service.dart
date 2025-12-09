import 'package:hive/hive.dart';
import 'package:hijri/hijri_calendar.dart';

class FastingService {
  static const _boxName = 'fastingBox';
  static const _notesBox = 'fastingNotes';

  // Helper: Pastikan Key selalu unik per user (case insensitive)
  static String _getUserKey(String email) => email.toLowerCase().trim();

  static List<DateTime> getFastingDates(String email) {
    final box = Hive.box(_boxName);
    final key = _getUserKey(email);
    final raw = box.get(key) as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((s) => DateTime.parse(s as String)).toList();
  }

  static Future<void> addFastingDate(String email, DateTime date) async {
    final box = Hive.box(_boxName);
    final key = _getUserKey(email);
    final existing = box.get(key) as List<dynamic>? ?? [];
    final iso = date.toIso8601String();
    if (!existing.contains(iso)) {
      final updated = List<String>.from(existing.map((e) => e as String))
        ..add(iso);
      await box.put(key, updated);
    }
  }

  static Future<void> removeFastingDate(String email, DateTime date) async {
    final box = Hive.box(_boxName);
    final key = _getUserKey(email);
    final existing = box.get(key) as List<dynamic>? ?? [];
    final iso = date.toIso8601String();
    if (existing.contains(iso)) {
      final updated = List<String>.from(existing.map((e) => e as String))
        ..remove(iso);
      await box.put(key, updated);
    }
  }

  static bool isFasting(String email, DateTime date) {
    final list = getFastingDates(email);
    return list.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  // --- Logic Catatan (Notes) ---
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<Map<String, dynamic>> getNotes(String email, DateTime date) {
    final box = Hive.box(_notesBox);
    final key = '${_getUserKey(email)}|${_dateKey(date)}';
    final raw = box.get(key) as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> addNote(String email, DateTime date, String note) async {
    final box = Hive.box(_notesBox);
    final key = '${_getUserKey(email)}|${_dateKey(date)}';
    final existing = box.get(key) as List<dynamic>? ?? [];
    final entry = {'note': note, 'createdAt': DateTime.now().toIso8601String()};
    final updated = List<Map<String, dynamic>>.from(
      existing.map((e) => Map<String, dynamic>.from(e as Map)),
    )..add(entry);
    await box.put(key, updated);
  }

  // --- LOGIKA REKOMENDASI PUASA (BARU) ---
  static String getRecommendation(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    final hDay = hijri.hDay;
    final hMonth = hijri.hMonth; // 1=Muharram, 9=Ramadan, 12=Dzulhijjah
    final weekday = date.weekday; // 1=Senin, 4=Kamis

    List<String> recs = [];

    // 1. Puasa Ramadhan
    if (hMonth == 9) {
      return "Puasa Wajib Ramadhan (Hari ke-$hDay)";
    }

    // 2. Puasa Arafah (9 Dzulhijjah)
    if (hMonth == 12 && hDay == 9) recs.add("Puasa Arafah (Sangat Dianjurkan)");

    // 3. Puasa Tarwiyah (8 Dzulhijjah)
    if (hMonth == 12 && hDay == 8) recs.add("Puasa Tarwiyah");

    // 4. Puasa Tasu'a (9 Muharram)
    if (hMonth == 1 && hDay == 9) recs.add("Puasa Tasu'a");

    // 5. Puasa Asyura (10 Muharram)
    if (hMonth == 1 && hDay == 10)
      recs.add("Puasa Asyura (Menghapus dosa setahun lalu)");

    // 6. Puasa Ayyamul Bidh (13, 14, 15)
    // Kecuali hari tasyrik (13 Dzulhijjah haram puasa)
    if ((hDay >= 13 && hDay <= 15) && !(hMonth == 12 && hDay == 13)) {
      recs.add("Puasa Ayyamul Bidh");
    }

    // 7. Puasa Senin - Kamis
    if (weekday == 1) recs.add("Puasa Sunnah Senin");
    if (weekday == 4) recs.add("Puasa Sunnah Kamis");

    // 8. Puasa Syawal (Hanya cek bulannya, user tracking sendiri 6 harinya)
    if (hMonth == 10 && hDay > 1) recs.add("Bulan Syawal (Dianjurkan 6 hari)");

    // 9. Nisfu Sya'ban
    if (hMonth == 8 && hDay == 15) recs.add("Puasa Nisfu Sya'ban");

    // 10. Bulan Sya'ban (1-15)
    if (hMonth == 8 && hDay < 15) recs.add("Perbanyak puasa di bulan Sya'ban");

    // 11. Awal Dzulhijjah (1-7)
    if (hMonth == 12 && hDay <= 7) recs.add("Puasa awal Dzulhijjah");

    if (recs.isEmpty) {
      // Cek hari haram
      if (hMonth == 10 && hDay == 1)
        return "Hari Raya Idul Fitri (Haram Puasa)";
      if (hMonth == 12 && hDay == 10)
        return "Hari Raya Idul Adha (Haram Puasa)";
      if (hMonth == 12 && (hDay >= 11 && hDay <= 13))
        return "Hari Tasyrik (Haram Puasa)";

      return "Tidak ada puasa khusus hari ini, tapi boleh puasa Daud/Mutlaq.";
    }

    return recs.join(" + ");
  }
}
