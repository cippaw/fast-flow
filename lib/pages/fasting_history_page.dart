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
  List<Map<String, dynamic>> _fastingEntries = [];

  String? get _currentUserEmail => AuthService().currentEmail;

  // Colors
  final Color _darkGreen = const Color(0xFF0B3D2E);
  final Color _lightGreen = const Color(0xFF4FB477);
  final Color _cream = const Color(0xFFF6F0E8);
  final Color _gold = const Color(0xFFD4A548);

  @override
  void initState() {
    super.initState();
    _fastingBox = Hive.box('fastingBox');
    _notesBox = Hive.box('fastingNotes');
    _loadFastingData();

    // Listen to box changes
    _fastingBox.watch().listen((_) => _loadFastingData());
    _notesBox.watch().listen((_) => _loadFastingData());
  }

  void _loadFastingData() {
    if (_currentUserEmail == null) {
      setState(() => _fastingEntries = []);
      return;
    }

    final entries = <Map<String, dynamic>>[];
    final prefix = '${_currentUserEmail}_';

    // Iterate through all keys in fastingBox
    for (var key in _fastingBox.keys) {
      final keyStr = key.toString();

      // Check if key belongs to current user
      if (keyStr.startsWith(prefix)) {
        final dateKey = keyStr.substring(prefix.length);

        // Try to parse date
        try {
          final date = DateTime.parse(dateKey);
          final data = _fastingBox.get(key);

          List<String> types = [];
          bool hasFasting = false;

          if (data is bool && data == true) {
            hasFasting = true;
            types = ['Umum'];
          } else if (data is Map) {
            final typesList = data['types'] as List?;
            if (typesList != null && typesList.isNotEmpty) {
              types = typesList.map((e) => e.toString()).toList();
              hasFasting = true;
            }
          }

          if (hasFasting) {
            // Get notes
            final note = _notesBox.get(key) as String?;

            entries.add({
              'key': key,
              'date': date,
              'dateKey': dateKey,
              'types': types,
              'note': note ?? '',
            });
          }
        } catch (e) {
          // Skip invalid date keys
          continue;
        }
      }
    }

    // Sort by date descending (newest first)
    entries.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    setState(() => _fastingEntries = entries);
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tanda Puasa?'),
        content: Text(
          'Menghapus data puasa untuk tanggal ${DateFormat('d MMMM yyyy', 'id_ID').format(entry['date'])}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fastingBox.delete(entry['key']);
      await _notesBox.delete(entry['key']);
      _loadFastingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data puasa berhasil dihapus'),
            backgroundColor: _lightGreen,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Riwayat Puasa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tandai hari puasa di kalender\nuntuk melihat riwayatnya di sini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text('Riwayat Puasa'),
        centerTitle: true,
        backgroundColor: _darkGreen,
        elevation: 0,
        actions: [
          if (_fastingEntries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFastingData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _fastingEntries.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _fastingEntries.length,
              itemBuilder: (context, index) {
                final entry = _fastingEntries[index];
                final date = entry['date'] as DateTime;
                final types = entry['types'] as List<String>;
                final note = entry['note'] as String;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_lightGreen, _darkGreen],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('d').format(date),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                DateFormat('MMM', 'id_ID').format(date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _darkGreen,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: types.map((type) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lightGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _lightGreen.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _darkGreen,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _gold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.note, size: 14, color: _gold),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deleteEntry(entry),
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
