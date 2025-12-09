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

  // Doa fields
  String _doaJudul = "Memuat...";
  String _doaArab = "";
  String _doaLatin = "";
  String _doaTerjemah = "";

  final Color _darkGreen = const Color(0xFF0B3D2E);
  final Color _cream = const Color(0xFFF6F0E8);
  final Color _card = Colors.white;

  // Timezone
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
      // ignore hive errors silently
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
              child: const Icon(Icons.location_on, color: Colors.green),
            ),
          );
        } else if (e['center'] != null && e['center']['lat'] != null) {
          markers.add(
            Marker(
              point: LatLng(e['center']['lat'], e['center']['lon']),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.green),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() => _mosqueMarkers = markers);
    } catch (_) {}
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyleHeading =
        TextStyle(color: _darkGreen, fontWeight: FontWeight.w700, fontSize: 18);

    // Convert waktu ke zona terpilih
    final today = DateTime.now();
    final displayImsak = _tzService.convertTimeFromJakarta(_imsak, today);
    final displaySubuh = _tzService.convertTimeFromJakarta(_subuh, today);
    final displayMaghrib = _tzService.convertTimeFromJakarta(_maghrib, today);

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _darkGreen,
        elevation: 0,
        title: const Text("Live Location & Jadwal"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? const Center(child: Text("Mengambil lokasi..."))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lokasi
                        Text("Lokasi", style: textStyleHeading),
                        const SizedBox(height: 8),
                        _sectionCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _darkGreen.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(8),
                                child:
                                    Icon(Icons.location_on, color: _darkGreen),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _address,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.4),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _darkGreen,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text('Live',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Lon: ${_currentPosition!.longitude.toStringAsFixed(5)}",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
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
                        Text("Zona Waktu", style: textStyleHeading),
                        const SizedBox(height: 8),
                        _sectionCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.public, color: _darkGreen),
                              const SizedBox(width: 12),
                              const Text('Pilih Zona:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _cream,
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
                                                  style: const TextStyle(
                                                      fontSize: 13))))
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
                        ),

                        // Jadwal
                        Text("Jadwal", style: textStyleHeading),
                        const SizedBox(height: 8),
                        _sectionCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _labelValue("Imsak", displayImsak),
                              _labelValue("Subuh", displaySubuh),
                              _labelValue("Maghrib", displayMaghrib),
                            ],
                          ),
                        ),

                        // Doa
                        _sectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _darkGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.menu_book,
                                        color: _darkGreen),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Doa Hari Ini",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: _darkGreen)),
                                        if (_doaJudul.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Text(_doaJudul,
                                                style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_doaArab.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _cream,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _doaArab,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              if (_doaLatin.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(_doaLatin,
                                      style:
                                          TextStyle(color: Colors.grey[800])),
                                ),
                              if (_doaTerjemah.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(_doaTerjemah,
                                      style:
                                          TextStyle(color: Colors.grey[800])),
                                ),
                            ],
                          ),
                        ),

                        // Map
                        _sectionCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 260,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
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
                                              alignment: Alignment.center,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 6)
                                                  ],
                                                ),
                                                padding:
                                                    const EdgeInsets.all(6),
                                                child: const Icon(
                                                  Icons.my_location,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (_currentPosition != null) {
                                        try {
                                          _mapController.move(
                                              _currentPosition!, 16);
                                        } catch (_) {}
                                      }
                                    },
                                    icon: const Icon(Icons.my_location),
                                    label: const Text("Center"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _darkGreen,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Masjid terdekat ditandai",
                                    style: TextStyle(
                                        color: Colors.grey[700], fontSize: 13),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
