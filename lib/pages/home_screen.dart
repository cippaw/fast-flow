import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _hijriDay, _hijriMonthEn, _hijriYear;

  @override
  void initState() {
    super.initState();
    _fetchTodayPrayerTimes();
  }

  Future<void> _fetchTodayPrayerTimes() async {
    final url = Uri.parse(
        "https://api.aladhan.com/v1/timingsByCity?city=Jakarta&country=Indonesia&method=2");

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      setState(() {
        _hijriDay = data["data"]["date"]["hijri"]["day"];
        _hijriMonthEn = data["data"]["date"]["hijri"]["month"]["en"];
        _hijriYear = data["data"]["date"]["hijri"]["year"];
      });
    } catch (e) {
      print("Error fetch prayer time: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final _todayMasehi =
        DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ================= GREETING CARD ================= ///
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C356A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Assalamu'alaikum,",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),

                    /// Username tetap — tidak diubah
                    Text(
                      widget.username,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    /// 🔥 Tambahan sesuai permintaan (Hijriah / Masehi)
                    const SizedBox(height: 6),
                    Text(
                      _hijriDay != null
                          ? "$_hijriDay $_hijriMonthEn $_hijriYear / $_todayMasehi"
                          : "- / $_todayMasehi",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// ================= MENU ================= ///
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    /// CARD MULAI PUASA (UI tidak diubah)
                    InkWell(
                      onTap: () {},
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C356A),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text("Mulai Puasa",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      ),
                    ),

                    /// HISTORY (UI tetap)
                    InkWell(
                      onTap: () {},
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C356A),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text("Riwayat Puasa",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
