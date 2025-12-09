// lib/pages/countdown_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:fast_flow/services/timezone_service.dart';
import 'package:fast_flow/services/auth_service.dart';

const Color darkGreen = Color(0xFF0F3D2E);
const Color softGreen = Color(0xFF1F6F54);
const Color lightGreen = Color(0xFF4FB477);
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
  String maghribTime = "17:55";
  bool _running = false;

  double progress = 0.0;

  DateTime? _targetInstantUtc;
  Duration? _initialDurationAtStart;

  String selectedZone = "WIB (Asia/Jakarta)";
  final TimezoneService _tzService = TimezoneService();

  late Box _fastingBox;
  late Box _sessionBox;

  String? get _currentUserEmail => AuthService().currentEmail;

  @override
  void initState() {
    super.initState();
    _fastingBox = Hive.box('fastingBox');
    _sessionBox = Hive.box('session');

    selectedZone = _tzService.getSelectedZone();

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
    if (_currentUserEmail == null) return;

    try {
      final today = DateTime.now();
      final key =
          '${_currentUserEmail}_${DateFormat('yyyy-MM-dd').format(today)}';

      await _fastingBox.put(key, {
        'types': ['Umum']
      });

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
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text('Start', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: darkGreen,
            disabledBackgroundColor: darkGreen.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _running ? _onStopPressed : null,
          icon: const Icon(Icons.stop, color: Colors.white),
          label: const Text('Stop', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            disabledBackgroundColor: Colors.redAccent.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _onResetPressed,
          icon: Icon(Icons.refresh, color: darkGreen),
          label: Text('Reset', style: TextStyle(color: darkGreen)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: darkGreen.withOpacity(0.5), width: 1.5),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: darkGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Countdown Berbuka',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkGreen, lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(18),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Main Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: darkGreen.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('Menuju Berbuka',
                          style: TextStyle(
                              color: softGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      const SizedBox(height: 24),

                      // Circular Progress
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 20,
                                color: beige,
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 20,
                                color: lightGreen,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formattedTime,
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: darkGreen,
                                        letterSpacing: 1)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: lightGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.nights_stay,
                                          color: darkGreen, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Maghrib $maghribDisplay',
                                          style: TextStyle(
                                              color: darkGreen,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(selectedZone,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Timezone Selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: darkGreen.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.public, color: darkGreen, size: 20),
                            const SizedBox(width: 12),
                            const Text('Zona: ',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedZone,
                                items: TimezoneService.zoneMap.keys
                                    .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k,
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => _onZoneChanged(v),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildControlButtons(),

                      const SizedBox(height: 20),

                      if (maybeTargetUtc != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Target: ${DateFormat('HH:mm').format(maybeTargetUtc.toLocal())}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: darkGreen),
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

                const SizedBox(height: 20),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        darkGreen.withOpacity(0.1),
                        lightGreen.withOpacity(0.05)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lightbulb,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tips Menunggu Berbuka',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTipItem('Perbanyak dzikir dan doa'),
                      _buildTipItem('Baca Al-Qur\'an'),
                      _buildTipItem('Siapkan makanan berbuka'),
                      _buildTipItem('Istirahat yang cukup'),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: darkGreen.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
