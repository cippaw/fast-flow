// lib/pages/countdown_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:fast_flow/services/timezone_service.dart';

const Color darkGreen = Color(0xFF0F3D2E);
const Color softGreen = Color(0xFF1F6F54);
const Color cream = Color(0xFFF6F1EB);
const Color beige = Color(0xFFEADFD5);

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  Timer? _timer;

  Duration _remainingTime = Duration.zero;
  String formattedTime = "--:--:--";
  String maghribTime = "17:55"; // default maghrib Jakarta
  bool _running = false;

  double progress = 0.0;

  DateTime? _targetInstantUtc;
  Duration? _initialDurationAtStart;

  String selectedZone = "WIB (Asia/Jakarta)";
  final TimezoneService _tzService = TimezoneService();

  late Box _fastingBox;
  late Box _sessionBox;

  @override
  void initState() {
    super.initState();
    _fastingBox = Hive.box('fastingBox');
    _sessionBox = Hive.box('session');

    // Load selected zone from service
    selectedZone = _tzService.getSelectedZone();

    // Load maghrib time from session if available
    final savedMaghrib = _sessionBox.get('maghrib') as String?;
    if (savedMaghrib != null && savedMaghrib.isNotEmpty) {
      maghribTime = savedMaghrib;
    }

    _setFormattedFromDuration(Duration.zero);
    progress = 0.0;
  }

  void _setFormattedFromDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    formattedTime = '${h}h ${m}m ${s}s';
  }

  DateTime? _computeTargetInstantUtc() {
    return _tzService.convertMaghribToTargetZone(maghribTime, DateTime.now());
  }

  String _maghribForZoneLabel(DateTime targetUtc) {
    return _tzService.formatMaghribForSelectedZone(targetUtc);
  }

  void _onStartPressed() {
    if (_running) return;
    final targetUtc = _computeTargetInstantUtc();
    if (targetUtc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format maghrib tidak valid')));
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final remaining = targetUtc.difference(nowUtc);

    if (remaining <= Duration.zero) {
      setState(() {
        _running = false;
        _remainingTime = Duration.zero;
        _setFormattedFromDuration(_remainingTime);
        progress = 1.0;
        _targetInstantUtc = targetUtc;
        _initialDurationAtStart = Duration.zero;
      });
      _autoMarkFastingDay();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Waktu maghrib sudah lewat untuk hari ini')));
      return;
    }

    setState(() {
      _running = true;
      _targetInstantUtc = targetUtc;
      _initialDurationAtStart = remaining;
      _remainingTime = remaining;
      _setFormattedFromDuration(_remainingTime);
      progress = 0.0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().toUtc();
      final rem = _targetInstantUtc!.difference(now);

      if (rem <= Duration.zero) {
        _timer?.cancel();
        setState(() {
          _running = false;
          _remainingTime = Duration.zero;
          _setFormattedFromDuration(_remainingTime);
          progress = 1.0;
        });

        // Auto mark fasting day
        _autoMarkFastingDay();

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sudah maghrib — waktu berbuka! 🎉')));
        return;
      }

      final init = _initialDurationAtStart ?? rem;

      setState(() {
        _remainingTime = rem;
        _setFormattedFromDuration(_remainingTime);
        if (init.inSeconds > 0) {
          progress = (1.0 - (rem.inSeconds / init.inSeconds)).clamp(0.0, 1.0);
        } else {
          progress = 0.0;
        }
      });
    });
  }

  Future<void> _autoMarkFastingDay() async {
    try {
      final today = DateTime.now();
      final key = DateFormat('yyyy-MM-dd').format(today);

      // Mark as fasting day
      await _fastingBox.put(key, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hari puasa berhasil ditandai di kalender! ✓'),
            backgroundColor: softGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error auto-marking fasting day: $e');
    }
  }

  void _onStopPressed() {
    _timer?.cancel();
    setState(() {
      _running = false;
    });
  }

  void _onResetPressed() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remainingTime = Duration.zero;
      _setFormattedFromDuration(_remainingTime);
      progress = 0.0;
      _targetInstantUtc = null;
      _initialDurationAtStart = null;
    });
  }

  void _onZoneChanged(String? val) async {
    if (val == null) return;
    if (!TimezoneService.zoneMap.containsKey(val)) return;

    await _tzService.setSelectedZone(val);
    setState(() {
      selectedZone = val;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _running ? null : _onStartPressed,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: darkGreen,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _running ? _onStopPressed : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _onResetPressed,
          child: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: darkGreen.withOpacity(0.2)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maybeTargetUtc = _targetInstantUtc ?? _computeTargetInstantUtc();
    final maghribDisplay = maybeTargetUtc != null
        ? _maghribForZoneLabel(maybeTargetUtc)
        : maghribTime;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Countdown Menuju Berbuka'),
        centerTitle: true,
        backgroundColor: darkGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: darkGreen.withOpacity(0.06), blurRadius: 14)
                ],
              ),
              child: Column(
                children: [
                  Text('Menuju Berbuka',
                      style: TextStyle(
                          color: softGreen, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  // circular progress + time
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 18,
                            color: beige,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 18,
                            color: softGreen,
                            backgroundColor: beige,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formattedTime,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: darkGreen)),
                            const SizedBox(height: 6),
                            Text('Maghrib $maghribDisplay',
                                style: TextStyle(
                                    color: darkGreen.withOpacity(0.75))),
                            const SizedBox(height: 6),
                            Text(selectedZone,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // timezone dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Zona: ',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: beige,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedZone,
                            items: TimezoneService.zoneMap.keys
                                .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => _onZoneChanged(v),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildControlButtons(),

                  const SizedBox(height: 12),

                  if (maybeTargetUtc != null)
                    Text(
                      'Target (UTC): ${DateFormat('yyyy-MM-dd HH:mm').format(maybeTargetUtc.toUtc())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: beige,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: darkGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Countdown akan otomatis menandai hari puasa di kalender saat selesai',
                            style: TextStyle(
                                fontSize: 12,
                                color: darkGreen.withOpacity(0.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
