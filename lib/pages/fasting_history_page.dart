// lib/pages/fasting_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:fast_flow/services/auth_service.dart';

class FastingHistoryPage extends StatefulWidget {
  const FastingHistoryPage({super.key});

  @override
  State<FastingHistoryPage> createState() => _FastingHistoryPageState();
}

class _FastingHistoryPageState extends State<FastingHistoryPage> {
  late Box _fastingBox;
  late Box _notesBox;
  List<MapEntry<String, dynamic>> _entries = [];

  String? get _currentUserEmail => AuthService().currentEmail;

  @override
  void initState() {
    super.initState();
    _fastingBox = Hive.box('fastingBox');
    _notesBox = Hive.box('fastingNotes');
    _loadEntries();
    _fastingBox.watch().listen((_) => _loadEntries());
  }

  void _loadEntries() {
    if (_currentUserEmail == null) {
      setState(() => _entries = []);
      return;
    }

    final prefix = '${_currentUserEmail}_';
    final allKeys = _fastingBox.keys.cast<String>().toList();

    final userEntries = <MapEntry<String, dynamic>>[];

    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        final value = _fastingBox.get(key);
        if (value != null) {
          // Extract date dari key (format: email_yyyy-MM-dd)
          final dateStr = key.substring(prefix.length);
          userEntries.add(MapEntry(dateStr, value));
        }
      }
    }

    // Sort descending (newest first)
    userEntries.sort((a, b) => b.key.compareTo(a.key));

    setState(() => _entries = userEntries);
  }

  Future<void> _deleteEntry(String dateKey) async {
    if (_currentUserEmail == null) return;

    final fullKey = '${_currentUserEmail}_$dateKey';
    await _fastingBox.delete(fullKey);
    await _notesBox.delete(fullKey);
    _loadEntries();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data puasa berhasil dihapus')),
      );
    }
  }

  List<String> _getTypesFromValue(dynamic value) {
    if (value == null) return [];

    if (value is bool) {
      return value ? ['Umum'] : [];
    }

    if (value is Map) {
      final types = (value['types'] as List?)?.cast<String>() ?? [];
      return types;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0b5a3a);
    final lightGreen = const Color(0xFF4FB477);
    final cream = const Color(0xFFF5F5F0);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Riwayat Puasa'),
        centerTitle: true,
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat puasa',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tandai hari puasa di kalender\nuntuk melihat riwayat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final entry = _entries[idx];
                final dateKey = entry.key;
                final value = entry.value;

                DateTime dt;
                try {
                  dt = DateTime.parse(dateKey);
                } catch (_) {
                  dt = DateTime.now();
                }

                final types = _getTypesFromValue(value);
                final fullKey = '${_currentUserEmail}_$dateKey';
                final note = _notesBox.get(fullKey) as String?;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryGreen, lightGreen],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${dt.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          DateFormat('EEEE', 'id_ID').format(dt),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('d MMMM yyyy', 'id_ID').format(dt),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hapus Riwayat Puasa?'),
                                  content: const Text(
                                      'Data akan dihapus permanen. Lanjutkan?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Batal')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent),
                                        child: const Text('Hapus')),
                                  ],
                                ),
                              );
                              if (ok == true) _deleteEntry(dateKey);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Hapus'),
                                  ],
                                )),
                          ],
                        ),
                      ),
                      if (types.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: types
                                .map((type) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: lightGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: lightGreen.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          color: primaryGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      if (note != null && note.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note,
                                  color: Colors.amber[700], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  note,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
