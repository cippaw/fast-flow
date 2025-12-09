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
  final Color lightGreen = const Color(0xFF4FB477);
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
  final List<String> _quotes = [
    'Setiap hari adalah kesempatan untuk memperbaiki diri.',
    'Puasa adalah perisai dari api neraka.',
    'Barangsiapa berpuasa Ramadhan dengan iman dan mengharap pahala, diampuni dosa-dosanya yang telah lalu.',
    'Sebaik-baik manusia adalah yang paling bermanfaat bagi orang lain.',
  ];
  String _currentQuote = '';

  @override
  void initState() {
    super.initState();

    _fastingBox = Hive.box('fastingBox');
    _notesBox = Hive.box('fastingNotes');
    _sessionBox = Hive.box('session');

    _selectedZoneLabel = _tzService.getSelectedZone();
    _currentQuote = _quotes[DateTime.now().day % _quotes.length];

    final auth = AuthService();
    _email = auth.currentEmail;
    if (_email != null) {
      final u = auth.getUser(_email!);
      if (u != null && u['username'] != null) _username = u['username'];
    }

    _loadPrayerTimesFromSession();
    _fetchTodayPrayerTimes();
  }

  void _loadPrayerTimesFromSession() {
    try {
      _imsak = _sessionBox.get('imsak', defaultValue: '--:--');
      _subuh = _sessionBox.get('subuh', defaultValue: '--:--');
      _maghrib = _sessionBox.get('maghrib', defaultValue: '--:--');
      setState(() {});
    } catch (_) {}
  }

  String _ymd(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  // Get multiple fasting types for a date
  Map<String, dynamic> getFastingData(DateTime day) {
    final k = _ymd(day);
    final data = _fastingBox.get(k);

    if (data == null) return {'hasFasting': false, 'types': []};

    if (data is bool) {
      return {
        'hasFasting': data,
        'types': data ? ['Umum'] : []
      };
    }

    if (data is Map) {
      final types = (data['types'] as List?)?.cast<String>() ?? [];
      return {'hasFasting': types.isNotEmpty, 'types': types};
    }

    return {'hasFasting': false, 'types': []};
  }

  bool isFastingDay(DateTime day) {
    return getFastingData(day)['hasFasting'] as bool;
  }

  Future<void> _toggleFasting(DateTime day) async {
    final k = _ymd(day);
    final currentData = getFastingData(day);
    final currentTypes = currentData['types'] as List<String>;

    // Show dialog to select fasting types
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _FastingTypesDialog(
        date: day,
        currentTypes: currentTypes,
      ),
    );

    if (result == null) return;

    final types = result['types'] as List<String>;
    final note = result['note'] as String?;

    if (types.isEmpty) {
      await _fastingBox.delete(k);
      await _notesBox.delete(k);
    } else {
      await _fastingBox.put(k, {'types': types});
      if (note != null && note.trim().isNotEmpty) {
        await _notesBox.put(k, note.trim());
      }
    }
    setState(() {});
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

          _sessionBox.put('imsak', _imsak);
          _sessionBox.put('subuh', _subuh);
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
        _recommendation = 'Tidak ada puasa sunnah khusus hari ini';
      } else {
        _recommendation = buf.join(' • ');
      }
    });
  }

  void _showDateDetail(DateTime day) {
    final k = _ymd(day);
    final note = _notesBox.get(k) as String?;
    final fastingData = getFastingData(day);
    final fasting = fastingData['hasFasting'] as bool;
    final types = fastingData['types'] as List<String>;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_today, color: primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE', 'id_ID').format(day),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('d MMMM yyyy', 'id_ID').format(day),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (fasting && types.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lightGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: lightGreen, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Jenis Puasa:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: types
                            .map((type) => Chip(
                                  label: Text(type,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: lightGreen.withOpacity(0.2),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (note != null && note.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          const Text('Catatan:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(note, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toggleFasting(day);
                      },
                      icon: Icon(fasting ? Icons.edit : Icons.flag),
                      label: Text(fasting ? 'Edit Puasa' : 'Tandai Puasa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (fasting) ...[
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await _fastingBox.delete(k);
                        await _notesBox.delete(k);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.delete),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _markerBuilder(BuildContext ctx, DateTime date, List events) {
    final data = getFastingData(date);
    final types = data['types'] as List<String>;

    if (types.isEmpty) return null;

    return Positioned(
      bottom: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: types.take(3).map((type) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay);
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
              // Modern Greeting Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assalamu\'alaikum,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mosque, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentQuote,
                              style: const TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Recommendation Card (Separated)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.lightbulb, color: accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rekomendasi Puasa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _recommendation,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Calendar Card
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _fetchTodayPrayerTimes(),
                            icon: Icon(Icons.refresh, color: primaryGreen),
                            style: IconButton.styleFrom(
                              backgroundColor: primaryGreen.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                          defaultBuilder: (ctx, day, focusedDay) =>
                              _dayCell(day),
                          todayBuilder: (ctx, day, focusedDay) =>
                              _dayCell(day, isToday: true),
                          selectedBuilder: (ctx, day, focusedDay) =>
                              _dayCell(day, isSelected: true),
                          markerBuilder: _markerBuilder,
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: lightGreen.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Prayer Times Card
              Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Zona waktu:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _modernTimeCard('Imsak', displayImsak, Icons.dark_mode),
                        _modernTimeCard(
                            'Subuh', displaySubuh, Icons.wb_twilight),
                        _modernTimeCard(
                            'Maghrib', displayMaghrib, Icons.nights_stay),
                      ],
                    ),
                  ],
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
    final bg = isSelected
        ? primaryGreen
        : (isToday ? lightGreen.withOpacity(0.3) : Colors.transparent);
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
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: txtColor,
          ),
        ),
      ),
    );
  }

  Widget _modernTimeCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen.withOpacity(0.1), lightGreen.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryGreen, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog for selecting fasting types
class _FastingTypesDialog extends StatefulWidget {
  final DateTime date;
  final List<String> currentTypes;

  const _FastingTypesDialog({
    required this.date,
    required this.currentTypes,
  });

  @override
  State<_FastingTypesDialog> createState() => _FastingTypesDialogState();
}

class _FastingTypesDialogState extends State<_FastingTypesDialog> {
  late Set<String> _selectedTypes;
  final _noteController = TextEditingController();

  final List<String> _availableTypes = [
    'Wajib (Ramadan)',
    'Senin',
    'Kamis',
    'Ayyamul Bidh',
    'Syawal',
    'Dzulhijjah',
    'Muharram',
    'Sya\'ban',
    'Daud',
    'Nazar',
    'Kafarat',
    'Qadha',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set.from(widget.currentTypes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Pilih Jenis Puasa',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(widget.date),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Jenis Puasa:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTypes.map((type) {
                final isSelected = _selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF4FB477).withOpacity(0.3),
                  checkmarkColor: const Color(0xFF0b5a3a),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
                hintText: 'Tambahkan catatan...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'types': _selectedTypes.toList(),
              'note': _noteController.text,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0b5a3a),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
