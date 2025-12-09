// lib/pages/countdown_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

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

  /// state waktu/countdown
  Duration _remainingTime = Duration.zero;
  String formattedTime = "--:--:--";
  String maghribTime = "17:55"; // sumber (diasumsikan jam maghrib di Jakarta)
  bool _running = false;

  double progress = 0.0; // 0..1 (0 = belum mulai, 1 = selesai)

  /// waktu target dalam bentuk instan (UTC) — dihitung pada saat Start
  DateTime? _targetInstantUtc;
  Duration? _initialDurationAtStart;

  /// zona
  String selectedZone = "WIB (Asia/Jakarta)";
  final Map<String, String> zoneMap = {
    'WIB (Asia/Jakarta)': 'Asia/Jakarta',
    'WITA (Asia/Makassar)': 'Asia/Makassar',
    'WIT (Asia/Jayapura)': 'Asia/Jayapura',
    'London (Europe/London)': 'Europe/London',
  };

  // Hive session box (untuk menyimpan pilihan zone)
  late Box _sessionBox;

  @override
  void initState() {
    super.initState();
    // session box harus sudah di-open di main.dart
    _sessionBox = Hive.box('session');

    final saved = _sessionBox.get('countdown_selected_zone') as String?;
    if (saved != null && zoneMap.containsKey(saved)) {
      selectedZone = saved;
    }

    // initial display
    _setFormattedFromDuration(Duration.zero);
    progress = 0.0;
  }

  void _setFormattedFromDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    formattedTime = '${h}h ${m}m ${s}s';
  }

  /// parse maghribTime (format "HH:mm") as Asia/Jakarta time for today,
  /// then compute the target instant (UTC) for that maghrib.
  DateTime? _computeTargetInstantUtc() {
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(maghribTime);
      if (match == null) return null;
      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);

      final srcLoc = tz.getLocation('Asia/Jakarta');
      final nowSrc = tz.TZDateTime.now(srcLoc);

      // build TZDateTime in Asia/Jakarta for today's maghrib
      // if maghrib already passed in Jakarta for today, keep it as today's time
      // (so countdown will be zero/negative and immediately finish)
      final maghribSrc =
          tz.TZDateTime(srcLoc, nowSrc.year, nowSrc.month, nowSrc.day, h, m);

      // return UTC instant of that maghrib
      return maghribSrc.toUtc();
    } catch (e) {
      return null;
    }
  }

  /// convert the maghrib instant (UTC) to a wall-clock string in chosen zone
  String _maghribForZoneLabel(DateTime targetUtc, String zoneTzName) {
    try {
      final destLoc = tz.getLocation(zoneTzName);
      final destDt = tz.TZDateTime.from(targetUtc, destLoc);
      return DateFormat('HH:mm').format(destDt);
    } catch (_) {
      return maghribTime;
    }
  }

  /// Start countdown: compute target instant (once), then start periodic Timer.
  void _onStartPressed() {
    if (_running) return;
    final targetUtc = _computeTargetInstantUtc();
    if (targetUtc == null) {
      // parsing failed
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format maghrib tidak valid')));
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final remaining = targetUtc.difference(nowUtc);

    if (remaining <= Duration.zero) {
      // already passed -> finish immediately
      setState(() {
        _running = false;
        _remainingTime = Duration.zero;
        _setFormattedFromDuration(_remainingTime);
        progress = 1.0;
        _targetInstantUtc = targetUtc;
        _initialDurationAtStart = Duration.zero;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Waktu maghrib sudah lewat untuk hari ini')));
      return;
    }

    // set initial values and start timer
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
        // reached maghrib
        _timer?.cancel();
        setState(() {
          _running = false;
          _remainingTime = Duration.zero;
          _setFormattedFromDuration(_remainingTime);
          progress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sudah maghrib — waktu berbuka!')));
        return;
      }

      final init = _initialDurationAtStart ?? rem;

      setState(() {
        _remainingTime = rem;
        _setFormattedFromDuration(_remainingTime);
        // progress: 1 - (remaining / initial)
        if (init.inSeconds > 0) {
          progress = (1.0 - (rem.inSeconds / init.inSeconds)).clamp(0.0, 1.0);
        } else {
          progress = 0.0;
        }
      });
    });
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

  void _onZoneChanged(String? val) {
    if (val == null) return;
    if (!zoneMap.containsKey(val)) return;
    setState(() {
      selectedZone = val;
    });
    // save to hive session
    _sessionBox.put('countdown_selected_zone', val);
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
    // compute maghrib display for selected zone (if target instant is known compute from that,
    // otherwise convert today's maghribTime instant for clarity)
    final tzName = zoneMap[selectedZone] ?? 'Asia/Jakarta';
    final maybeTargetUtc = _targetInstantUtc ?? _computeTargetInstantUtc();
    final maghribDisplay = maybeTargetUtc != null
        ? _maghribForZoneLabel(maybeTargetUtc, tzName)
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
            // card
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
                        // background circle
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 18,
                            color: beige,
                          ),
                        ),

                        // progress
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

                        // center texts
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
                            items: zoneMap.keys
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

                  // controls
                  _buildControlButtons(),

                  const SizedBox(height: 12),

                  // small helper row: show target UTC and local for debugging/clarity
                  if (maybeTargetUtc != null)
                    Text(
                      'Target (UTC): ${DateFormat('yyyy-MM-dd HH:mm').format(maybeTargetUtc.toUtc())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
