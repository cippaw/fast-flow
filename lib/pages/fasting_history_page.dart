// lib/pages/fasting_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

class FastingHistoryPage extends StatefulWidget {
  const FastingHistoryPage({super.key});

  @override
  State<FastingHistoryPage> createState() => _FastingHistoryPageState();
}

class _FastingHistoryPageState extends State<FastingHistoryPage> {
  late Box _fastingBox;
  late Box _notesBox;
  List<String> _keys = [];

  @override
  void initState() {
    super.initState();
    _fastingBox = Hive.box('fastingBox');
    _notesBox = Hive.box('fastingNotes');
    _loadKeys();
    // listen to box changes to update UI in realtime
    _fastingBox.watch().listen((_) => _loadKeys());
  }

  void _loadKeys() {
    final keys = _fastingBox.keys.cast<String>().toList();
    // keep only keys with truthy value
    final filtered =
        keys.where((k) => (_fastingBox.get(k) as bool?) == true).toList();
    filtered.sort((a, b) => b.compareTo(a)); // descending (newest first)
    setState(() => _keys = filtered);
  }

  Future<void> _deleteEntry(String key) async {
    await _fastingBox.delete(key);
    await _notesBox.delete(key);
    _loadKeys();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Puasa'),
        centerTitle: true,
      ),
      body: _keys.isEmpty
          ? const Center(child: Text('Belum ada tanggal yang ditandai.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _keys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final k = _keys[idx]; // format yyyy-MM-dd
                DateTime dt;
                try {
                  dt = DateTime.parse(k);
                } catch (_) {
                  dt = DateTime.now();
                }
                final note = _notesBox.get(k) as String?;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    title: Text(
                        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: note != null && note.isNotEmpty
                        ? Text(note)
                        : const Text('Tidak ada catatan'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus tanda puasa?'),
                              content: const Text(
                                  'Data akan dihapus permanen. Lanjutkan?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Hapus')),
                              ],
                            ),
                          );
                          if (ok == true) _deleteEntry(k);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
