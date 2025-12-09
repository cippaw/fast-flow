// lib/pages/kesan_pesan_page.dart
import 'package:flutter/material.dart';
import 'package:fast_flow/services/auth_service.dart';
import 'package:hive/hive.dart';

class KesanPesanPage extends StatefulWidget {
  const KesanPesanPage({Key? key}) : super(key: key);

  @override
  State<KesanPesanPage> createState() => _KesanPesanPageState();
}

class _KesanPesanPageState extends State<KesanPesanPage> {
  String? _userKesan;

  final List<Map<String, String>> _exampleBoxes = const [
    {
      'matkul': 'Pemrograman Aplikasi Mobile',
      'dosen': 'Bapak Bagus Muhammad Akbar, S.ST., M.Kom.',
      'kesan':
          'Kelas sangat menyenangkan namun cukup menantang ketika mengerjakan tugas projek.',
      'saran':
          'Pertahankan ciri khas mata kuliah ini dan tambahkan lebih banyak teori setelah tugas/kuis.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadKesan();
  }

  /// LOAD DATA KESAN PESAN MILIK USER
  Future<void> _loadKesan() async {
    final email = AuthService().currentEmail;

    if (email == null) {
      setState(() => _userKesan = null);
      return;
    }

    final key = email.toLowerCase().trim();

    // Pastikan box terbuka
    final box = await Hive.openBox('kesanPesan');

    final stored = box.get(key) as String?;
    setState(() {
      _userKesan = stored;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasKesan = _userKesan != null && _userKesan!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Kesan & Pesan')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: hasKesan ? _buildUserKesan() : _buildExampleKesan(),
      ),
    );
  }

  /// TAMPILKAN KESAN USER JIKA ADA
  Widget _buildUserKesan() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kesan & Pesan Anda",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _userKesan ?? '',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kembali ke Profil")),
        ],
      ),
    );
  }

  /// TAMPILKAN EXAMPLE BOX SAAT USER BELUM PUNYA KESAN
  Widget _buildExampleKesan() {
    return ListView.separated(
      itemCount: _exampleBoxes.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _exampleBoxes.length) {
          return ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kembali ke Profil"));
        }

        final item = _exampleBoxes[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['matkul'] ?? '',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(item['dosen'] ?? '',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 10),
              const Text("Kesan",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(item['kesan'] ?? '', style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              const Text("Saran",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(item['saran'] ?? '', style: const TextStyle(height: 1.4)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "— Mahasiswa",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
