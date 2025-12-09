// lib/pages/location_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:fast_flow/utils/permission_handler.dart';
import 'package:fast_flow/services/timezone_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive/hive.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  LatLng? _currentPosition;
  StreamSubscription<Position>? _locationStreamSubscription;
  final MapController _mapController = MapController();

  bool _isLoading = true;
  List<Marker> _mosqueMarkers = [];

  String _address = "Memuat...";
  String _hijri = "Memuat...";
  String _imsak = "--:--";
  String _subuh = "--:--";
  String _maghrib = "--:--";

  String _doaJudul = "Memuat...";
  String _doaArab = "";
  String _doaLatin = "";
  String _doaTerjemah = "";

  final Color _darkGreen = const Color(0xFF0B3D2E);
  final Color _lightGreen = const Color(0xFF4FB477);
  final Color _cream = const Color(0xFFF6F0E8);
  final Color _card = Colors.white;
  final Color _accent = const Color(0xFFD0A84D);

  String _selectedZoneLabel = 'WIB (Asia/Jakarta)';
  final TimezoneService _tzService = TimezoneService();

  @override
  void initState() {
    super.initState();
    _selectedZoneLabel = _tzService.getSelectedZone();
    initializeDateFormatting('id_ID', null).then((_) => _init());
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final perm = await PermissionHandler().requestLocationPermission(context);
    if (!perm) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    _loadFromHive();

    _locationStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      _updateLocation(pos.latitude, pos.longitude);
    });

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _updateLocation(last.latitude, last.longitude);
      } else {
        final curr = await Geolocator.getCurrentPosition();
        _updateLocation(curr.latitude, curr.longitude);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocation(double lat, double lon) async {
    if (!mounted) return;

    setState(() => _currentPosition = LatLng(lat, lon));
    try {
      _mapController.move(_currentPosition!, 15);
    } catch (_) {}

    await _fetchAddress(lat, lon);
    await _fetchPrayerTimes(lat, lon);
    await _fetchNearbyMosques(lat, lon);
    await _fetchDoa();
    _saveToHive();
  }

  void _saveToHive() {
    try {
      final box = Hive.box('session');
      box.put('lat', _currentPosition?.latitude);
      box.put('lon', _currentPosition?.longitude);
      box.put('address', _address);
      box.put('imsak', _imsak);
      box.put('subuh', _subuh);
      box.put('maghrib', _maghrib);
      box.put('hijri', _hijri);
      box.put('doa_judul', _doaJudul);
      box.put('doa_arab', _doaArab);
      box.put('doa_latin', _doaLatin);
      box.put('doa_terjemah', _doaTerjemah);
      box.put('updated', DateTime.now().toString());
    } catch (e) {
      // ignore
    }
  }

  void _loadFromHive() {
    try {
      final box = Hive.box('session');
      final savedDoaJudul = box.get('doa_judul');
      final savedDoaArab = box.get('doa_arab');
      final savedDoaLatin = box.get('doa_latin');
      final savedDoaTerjemah = box.get('doa_terjemah');

      if (savedDoaJudul != null) _doaJudul = savedDoaJudul;
      if (savedDoaArab != null) _doaArab = savedDoaArab;
      if (savedDoaLatin != null) _doaLatin = savedDoaLatin;
      if (savedDoaTerjemah != null) _doaTerjemah = savedDoaTerjemah;
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchDoa() async {
    try {
      final uri = Uri.parse('https://open-api.my.id/api/doa');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final idx = DateTime.now().day % list.length;
          final item = Map<String, dynamic>.from(list[idx]);

          if (!mounted) return;

          setState(() {
            _doaJudul = item['judul'] ?? "Doa Hari Ini";
            _doaArab = item['arab'] ?? "";
            _doaLatin = item['latin'] ?? "";
            _doaTerjemah = item['terjemah'] ?? "";
          });
          return;
        }
      }
      _setDoaFallback();
    } catch (e) {
      _setDoaFallback();
    }
  }

  void _setDoaFallback() {
    if (!mounted) return;

    setState(() {
      if (_doaArab.isEmpty && _doaTerjemah.isEmpty && _doaLatin.isEmpty) {
        _doaJudul = "Doa Hari Ini";
        _doaArab =
            "ٱللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ مَا سَأَلَكَ مِنْهُ عَبْدُكَ";
        _doaLatin = "Allahumma inni as'aluka khaira ma sa'alaka minhu 'abduka";
        _doaTerjemah =
            "Ya Allah, aku memohon kebaikan yang pernah dimohon hamba-Mu.";
      }
    });
  }

  Future<void> _fetchPrayerTimes(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lon&method=5&timezonestring=Asia/Jakarta');

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        final t = data['timings'];
        final h = data['date']['hijri'];

        if (!mounted) return;

        setState(() {
          _imsak = t['Imsak'];
          _subuh = t['Fajr'];
          _maghrib = t['Maghrib'];
          _hijri = "${h['day']} ${h['month']['en']} ${h['year']} H";
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAddress(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
      final res = await http.get(url, headers: {"User-Agent": "fastflow-app"});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final addr = data['display_name'] ?? "Tidak ditemukan";

        if (!mounted) return;

        setState(() => _address = addr);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = "Tidak ditemukan");
    }
  }

  Future<void> _fetchNearbyMosques(double lat, double lon) async {
    try {
      final query = """
        [out:json];
        node["amenity"="place_of_worship"]["religion"="muslim"](around:2000,$lat,$lon);
        out center;
      """;

      final url = Uri.parse(
          'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

      final res = await http.get(url);
      final data = json.decode(res.body);

      final markers = <Marker>[];

      for (final e in data['elements']) {
        if (e['lat'] != null && e['lon'] != null) {
          markers.add(
            Marker(
              point: LatLng(e['lat'], e['lon']),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Color(0xFF4FB477)),
            ),
          );
        } else if (e['center'] != null && e['center']['lat'] != null) {
          markers.add(
            Marker(
              point: LatLng(e['center']['lat'], e['center']['lon']),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Color(0xFF4FB477)),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() => _mosqueMarkers = markers);
    } catch (_) {}
  }

  Widget _modernCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
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
        padding: padding ?? const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final displayImsak = _tzService.convertTimeFromJakarta(_imsak, today);
    final displaySubuh = _tzService.convertTimeFromJakarta(_subuh, today);
    final displayMaghrib = _tzService.convertTimeFromJakarta(_maghrib, today);

    return Scaffold(
      backgroundColor: _cream,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _darkGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Mengambil lokasi...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _currentPosition == null
              ? const Center(child: Text("Mengambil lokasi..."))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      floating: false,
                      pinned: true,
                      backgroundColor: _darkGreen,
                      flexibleSpace: FlexibleSpaceBar(
                        title: const Text(
                          "Live Location & Jadwal",
                          style: TextStyle(fontSize: 16),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_darkGreen, _lightGreen],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Location Card
                          _modernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _lightGreen.withOpacity(0.2),
                                            _darkGreen.withOpacity(0.1)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.location_on,
                                          color: _darkGreen, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Lokasi Saat Ini',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _lightGreen,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.circle,
                                              size: 8, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            'Live',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _cream,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _address,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.public,
                                              size: 14,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Lon: ${_currentPosition!.longitude.toStringAsFixed(5)}",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Timezone Selector
                          _modernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.schedule,
                                          color: _accent, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Zona Waktu',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _cream,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _darkGreen.withOpacity(0.1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedZoneLabel,
                                      isExpanded: true,
                                      icon: Icon(Icons.arrow_drop_down,
                                          color: _darkGreen),
                                      items: TimezoneService.zoneMap.keys
                                          .map((k) => DropdownMenuItem(
                                              value: k,
                                              child: Text(k,
                                                  style: const TextStyle(
                                                      fontSize: 14))))
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
                              ],
                            ),
                          ),

                          // Prayer Times
                          _modernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _lightGreen.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.access_time,
                                          color: _darkGreen, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Jadwal Sholat',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _modernPrayerTime(
                                        'Imsak', displayImsak, Icons.dark_mode),
                                    Container(
                                      width: 1,
                                      height: 50,
                                      color: Colors.grey[200],
                                    ),
                                    _modernPrayerTime('Subuh', displaySubuh,
                                        Icons.wb_twilight),
                                    Container(
                                      width: 1,
                                      height: 50,
                                      color: Colors.grey[200],
                                    ),
                                    _modernPrayerTime('Maghrib', displayMaghrib,
                                        Icons.nights_stay),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Doa Card
                          _modernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _accent.withOpacity(0.3),
                                            _accent.withOpacity(0.1)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child:
                                          Icon(Icons.menu_book, color: _accent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Doa Hari Ini',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (_doaJudul.isNotEmpty)
                                            Text(
                                              _doaJudul,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_doaArab.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _cream,
                                          _cream.withOpacity(0.5)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _accent.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      _doaArab,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.8,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                if (_doaLatin.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _lightGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _doaLatin,
                                      style: TextStyle(
                                        color: _darkGreen,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_doaTerjemah.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.translate,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _doaTerjemah,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Map Card
                          _modernCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _lightGreen.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.map,
                                            color: _darkGreen, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Peta Masjid Terdekat',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 280,
                                    child: FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: _currentPosition!,
                                        initialZoom: 15,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName:
                                              'com.fastflow.app',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            ..._mosqueMarkers,
                                            Marker(
                                              point: _currentPosition!,
                                              width: 48,
                                              height: 48,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    )
                                                  ],
                                                ),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: const Icon(
                                                  Icons.my_location,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          if (_currentPosition != null) {
                                            try {
                                              _mapController.move(
                                                  _currentPosition!, 16);
                                            } catch (_) {}
                                          }
                                        },
                                        icon: const Icon(Icons.my_location,
                                            size: 18),
                                        label: const Text('Pusatkan Peta'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _darkGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _lightGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.mosque,
                                              size: 16, color: _lightGreen),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_mosqueMarkers.length} Masjid',
                                            style: TextStyle(
                                              color: _darkGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _modernPrayerTime(String label, String time, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _darkGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _darkGreen, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _darkGreen,
          ),
        ),
      ],
    );
  }
}
