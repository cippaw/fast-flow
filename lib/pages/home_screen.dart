// lib/pages/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

import 'package:fast_flow/services/auth_service.dart';
import 'package:fast_flow/services/timezone_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryGreen = const Color(0xFF0b5a3a);
  final Color accentGold = const Color(0xFFD0A84D);
  final Color bgBeige = const Color(0xFFF5F5F0);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  late Box _fastingBox;
  late Box _notesBox;
  late Box _sessionBox;

  String _imsak = '--:--';
  String _subuh = '--:--';
  String _maghrib = '--:--';

  int? _hijriDay;
  String? _hijriMonthEn;
  String? _hijriYear;

  String _username = 'User';
  String? _email;

  String _selectedZoneLabel = 'WIB (Asia/Jakarta)';
  final TimezoneService _tzService = TimezoneService();

  String _recommendation = 'Perbanyak amal sholeh';

  @override
  void initState() {
    super.initState();

    _fastingBox = Hive.box('fastingBox');
    _notesBox = Hive.box('fastingNotes');
    _sessionBox = Hive.box('session');

    // Load selected zone
    _selectedZoneLabel = _tzService.getSelectedZone();

    final auth = AuthService();
    _email = auth.currentEmail;
    if (_email != null) {
      final u = auth.getUser(_email!);
      if (u != null && u['username'] != null) _username = u['username'];
    }

    _fetchTodayPrayerTimes();
  }

  String _ymd(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  bool isFastingDay(DateTime day) {
    final k = _ymd(day);
    return _fastingBox.get(k, defaultValue: false) as bool? ?? false;
  }

  Future<void> _toggleFasting(DateTime day) async {
    final k = _ymd(day);
    final cur = isFastingDay(day);
    if (cur) {
      await _fastingBox.delete(k);
      await _notesBox.delete(k);
    } else {
      final note = await _openReviewDialog(day);
      await _fastingBox.put(k, true);
      if (note != null && note.trim().isNotEmpty) {
        await _notesBox.put(k, note.trim());
      }
    }
    setState(() {});
  }

  Future<String?> _openReviewDialog(DateTime day) async {
    final k = _ymd(day);
    final existing = _notesBox.get(k) as String? ?? '';
    final ctrl = TextEditingController(text: existing);

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
              'Catatan Puasa — ${DateFormat('d MMM yyyy', 'id_ID').format(day)}'),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
                hintText: 'Tulis kesan / catatan (opsional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                child: const Text('Simpan')),
          ],
        );
      },
    );
  }

  Future<void> _fetchTodayPrayerTimes() async {
    const double lat = -6.200000;
    const double lon = 106.816666;

    try {
      final url = Uri.parse(
          'https://api.aladhan.com/v1/timings/${DateTime.now().millisecondsSinceEpoch ~/ 1000}?latitude=$lat&longitude=$lon&method=5&timezonestring=Asia/Jakarta');

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] as Map<String, dynamic>;
        final timings = (data['timings'] ?? {}) as Map<String, dynamic>;
        final date = (data['date'] ?? {}) as Map<String, dynamic>;
        final hijri = (date['hijri'] ?? {}) as Map<String, dynamic>;

        setState(() {
          _imsak = (timings['Imsak'] ?? '--:--').toString();
          _subuh = (timings['Fajr'] ?? '--:--').toString();
          _maghrib = (timings['Maghrib'] ?? '--:--').toString();

          // Save to session for countdown
          _sessionBox.put('maghrib', _maghrib);

          try {
            _hijriDay = int.tryParse((hijri['day'] ?? '').toString());
            _hijriMonthEn = (hijri['month']?['en'] ?? '').toString();
            _hijriYear = (hijri['year'] ?? '').toString();
          } catch (_) {
            _hijriDay = null;
            _hijriMonthEn = null;
            _hijriYear = '';
          }
          _computeRecommendation();
        });
      }
    } catch (e) {
      debugPrint('Error fetching prayer times: $e');
    }
  }

  void _computeRecommendation() {
    final today = DateTime.now();
    final wd = today.weekday;

    final hijriDay = _hijriDay;
    final hijriMonth = _hijriMonthEn?.toLowerCase() ?? '';

    final buf = <String>[];

    if (wd == DateTime.monday) buf.add('Puasa Sunnah: Senin');
    if (wd == DateTime.thursday) buf.add('Puasa Sunnah: Kamis');

    if (hijriDay != null) {
      if (hijriDay == 13 || hijriDay == 14 || hijriDay == 15) {
        buf.add('Puasa Sunnah: Ayyamul Bidh ($hijriDay)');
      }

      if (hijriDay == 10 && hijriMonth.contains('muharram')) {
        buf.add('Puasa Sunnah: Ashura (10 Muharram)');
      }

      if (hijriDay == 9 &&
          (hijriMonth.contains('dhul') || hijriMonth.contains('dhu'))) {
        buf.add('Puasa Sunnah: Arafah (9 Dhu al-Hijjah)');
      }

      if (hijriDay == 15 && hijriMonth.contains('sha')) {
        buf.add('Puasa Sunnah: Nisfu Sya\'ban (15 Sha\'ban)');
      }
    }

    setState(() {
      if (buf.isEmpty) {
        _recommendation = 'Perbanyak amal sholeh';
      } else {
        _recommendation = buf.join(' • ');
      }
    });
  }

  void _showDateDetail(DateTime day) {
    final k = _ymd(day);
    final note = _notesBox.get(k) as String?;
    final fasting = isFastingDay(day);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(14.0),
          child: Wrap(
            children: [
              ListTile(
                title: Text(
                    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(day),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    fasting ? 'Tandai sebagai hari puasa' : 'Belum ditandai'),
              ),
              if (note != null && note.isNotEmpty) ...[
                const Divider(),
                const Text('Catatan:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(note),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleFasting(day);
                    },
                    icon: Icon(fasting ? Icons.delete : Icons.flag,
                        color: Colors.white),
                    label: Text(fasting ? 'Hapus tanda puasa' : 'Tandai puasa'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final note = await _openReviewDialog(day);
                      if (note != null) {
                        await _notesBox.put(k, note);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit catatan'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _markerBuilder(BuildContext ctx, DateTime date, List events) {
    if (isFastingDay(date)) {
      return const Positioned(
        bottom: 6,
        child: CircleAvatar(radius: 4, backgroundColor: Color(0xFF0b5a3a)),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay);

    // Convert times to selected zone
    final today = DateTime.now();
    final displayImsak = _tzService.convertTimeFromJakarta(_imsak, today);
    final displaySubuh = _tzService.convertTimeFromJakarta(_subuh, today);
    final displayMaghrib = _tzService.convertTimeFromJakarta(_maghrib, today);

    return Scaffold(
      backgroundColor: bgBeige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assalamu\'alaikum,',
                            style: TextStyle(
                                color: primaryGreen.withOpacity(0.9))),
                        const SizedBox(height: 6),
                        Text(_username,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen)),
                      ]),
                  const SizedBox(width: 44),
                ],
              ),

              const SizedBox(height: 12),

              // Quote / Recommendation card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  child: Row(children: [
                    Icon(Icons.format_quote,
                        color: primaryGreen.withOpacity(0.9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Setiap hari adalah kesempatan untuk memperbaiki diri.',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Text('Rekomendasi: $_recommendation',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: primaryGreen)),
                          ]),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // Calendar card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr,
                            style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w600)),
                        IconButton(
                            onPressed: () => _fetchTodayPrayerTimes(),
                            icon: Icon(Icons.refresh, color: primaryGreen)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _format,
                      onFormatChanged: (f) => setState(() => _format = f),
                      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                        _showDateDetail(selected);
                      },
                      onPageChanged: (focused) {
                        _focusedDay = focused;
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (ctx, day, focusedDay) => _dayCell(day),
                        todayBuilder: (ctx, day, focusedDay) =>
                            _dayCell(day, isToday: true),
                        selectedBuilder: (ctx, day, focusedDay) =>
                            _dayCell(day, isSelected: true),
                        markerBuilder: _markerBuilder,
                      ),
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false, titleCentered: true),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // Quick prayer times with timezone dropdown
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: primaryGreen),
                        const SizedBox(width: 8),
                        const Text('Zona waktu:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: bgBeige,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedZoneLabel,
                                isExpanded: true,
                                items: TimezoneService.zoneMap.keys
                                    .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k,
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) async {
                                  if (v == null) return;
                                  await _tzService.setSelectedZone(v);
                                  setState(() {
                                    _selectedZoneLabel = v;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _timeCard('Imsak', displayImsak),
                          _timeCard('Subuh', displaySubuh),
                          _timeCard('Maghrib', displayMaghrib),
                        ]),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day,
      {bool isToday = false, bool isSelected = false}) {
    final hijriDay = '';
    final bg = isSelected
        ? primaryGreen
        : (isToday ? const Color(0xFFcfeadf) : Colors.transparent);
    final txtColor = isSelected ? Colors.white : null;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
        _showDateDetail(day);
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${day.day}',
              style: TextStyle(fontWeight: FontWeight.w700, color: txtColor)),
          if (hijriDay.isNotEmpty)
            Text(hijriDay,
                style: TextStyle(
                    fontSize: 11, color: txtColor ?? Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _timeCard(String label, String value) {
    return Column(children: [
      Text(label, style: TextStyle(color: primaryGreen)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
          ],
        ),
        child: Column(children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Container(
              height: 6,
              width: 28,
              decoration: BoxDecoration(
                  color: accentGold, borderRadius: BorderRadius.circular(6))),
        ]),
      ),
    ]);
  }
}
